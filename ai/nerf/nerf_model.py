"""
NeRF Model Implementation for Camera Companion
Neural Radiance Fields with Photography-Specific Enhancements
"""

import torch
import torch.nn as nn
import torch.nn.functional as F
import numpy as np
from typing import Tuple, Optional, Dict, List
from .nerf_config import NeRFConfig

class PositionalEncoding(nn.Module):
    """Positional encoding for NeRF inputs."""
    
    def __init__(self, num_levels: int, include_input: bool = True):
        super().__init__()
        self.num_levels = num_levels
        self.include_input = include_input
        
    def forward(self, x: torch.Tensor) -> torch.Tensor:
        """
        Apply positional encoding to input.
        
        Args:
            x: Input tensor of shape (..., D)
            
        Returns:
            Encoded tensor of shape (..., D * (2 * num_levels + include_input))
        """
        if self.num_levels == 0:
            return x
            
        encodings = []
        if self.include_input:
            encodings.append(x)
            
        for i in range(self.num_levels):
            for fn in [torch.sin, torch.cos]:
                encodings.append(fn(2.0 ** i * np.pi * x))
                
        return torch.cat(encodings, dim=-1)

class NeRFMLP(nn.Module):
    """Multi-Layer Perceptron for NeRF."""
    
    def __init__(self, config: NeRFConfig):
        super().__init__()
        self.config = config
        
        # Input dimensions
        pos_dim = 3 * (2 * config.pos_encoding_levels + 1) if config.pos_encoding_levels > 0 else 3
        dir_dim = 3 * (2 * config.dir_encoding_levels + 1) if config.dir_encoding_levels > 0 else 3
        
        # Positional encoding
        self.pos_encoder = PositionalEncoding(config.pos_encoding_levels, config.include_input)
        self.dir_encoder = PositionalEncoding(config.dir_encoding_levels, config.include_input)
        
        # Main network layers
        layers = []
        in_dim = pos_dim
        
        for i in range(config.num_layers):
            out_dim = config.hidden_dim if i < config.num_layers - 1 else config.hidden_dim + 1  # +1 for density
            
            layers.append(nn.Linear(in_dim, out_dim))
            
            if i < config.num_layers - 1:
                layers.append(nn.ReLU(inplace=True))
                
            # Skip connections
            if i in config.skip_connections:
                in_dim = config.hidden_dim + pos_dim
            else:
                in_dim = config.hidden_dim
                
        self.main_network = nn.ModuleList(layers)
        
        # View-dependent color network
        if config.use_viewdirs:
            self.color_network = nn.Sequential(
                nn.Linear(config.hidden_dim + dir_dim, config.hidden_dim // 2),
                nn.ReLU(inplace=True),
                nn.Linear(config.hidden_dim // 2, 3),
                nn.Sigmoid()
            )
        else:
            self.color_head = nn.Sequential(
                nn.Linear(config.hidden_dim, 3),
                nn.Sigmoid()
            )
            
        # Photography-specific feature heads
        if config.enable_semantic_features:
            self.semantic_head = nn.Sequential(
                nn.Linear(config.hidden_dim, config.semantic_dim),
                nn.ReLU(inplace=True)
            )
            
        if config.enable_lighting_estimation:
            self.lighting_head = nn.Sequential(
                nn.Linear(config.hidden_dim, config.lighting_dim),
                nn.Sigmoid()
            )
    
    def forward(self, positions: torch.Tensor, directions: Optional[torch.Tensor] = None) -> Dict[str, torch.Tensor]:
        """
        Forward pass through NeRF model.
        
        Args:
            positions: 3D positions, shape (..., 3)
            directions: View directions, shape (..., 3)
            
        Returns:
            Dictionary containing density, color, and optional features
        """
        # Encode positions
        pos_encoded = self.pos_encoder(positions)
        
        # Main network forward pass
        x = pos_encoded
        skip_input = pos_encoded
        
        for i, layer in enumerate(self.main_network):
            if i > 0 and (i // 2) in self.config.skip_connections:
                x = torch.cat([x, skip_input], dim=-1)
                
            x = layer(x)
            
        # Extract density and features
        density = F.relu(x[..., 0])  # Ensure non-negative density
        features = x[..., 1:]
        
        outputs = {'density': density}
        
        # Compute color
        if self.config.use_viewdirs and directions is not None:
            dir_encoded = self.dir_encoder(directions)
            color_input = torch.cat([features, dir_encoded], dim=-1)
            color = self.color_network(color_input)
        else:
            color = self.color_head(features)
            
        outputs['color'] = color
        
        # Optional feature outputs
        if self.config.enable_semantic_features:
            outputs['semantic_features'] = self.semantic_head(features)
            
        if self.config.enable_lighting_estimation:
            outputs['lighting_features'] = self.lighting_head(features)
            
        return outputs

class NeRFRenderer(nn.Module):
    """NeRF volume rendering implementation."""
    
    def __init__(self, config: NeRFConfig):
        super().__init__()
        self.config = config
        self.coarse_network = NeRFMLP(config)
        
        if config.num_fine_samples > 0:
            self.fine_network = NeRFMLP(config)
    
    def sample_rays(self, rays_o: torch.Tensor, rays_d: torch.Tensor, 
                   near: float, far: float, num_samples: int, 
                   perturb: bool = True) -> Tuple[torch.Tensor, torch.Tensor]:
        """
        Sample points along rays.
        
        Args:
            rays_o: Ray origins, shape (N, 3)
            rays_d: Ray directions, shape (N, 3)
            near: Near plane distance
            far: Far plane distance
            num_samples: Number of samples per ray
            perturb: Whether to add random perturbation
            
        Returns:
            Tuple of (sampled points, z-values)
        """
        N = rays_o.shape[0]
        
        # Create uniform samples
        t_vals = torch.linspace(0.0, 1.0, num_samples, device=rays_o.device)
        if not perturb:
            z_vals = near * (1.0 - t_vals) + far * t_vals
        else:
            # Add stratified random sampling
            mids = 0.5 * (t_vals[:-1] + t_vals[1:])
            upper = torch.cat([mids, t_vals[-1:]], dim=0)
            lower = torch.cat([t_vals[:1], mids], dim=0)
            t_rand = torch.rand(num_samples, device=rays_o.device)
            z_vals = lower + (upper - lower) * t_rand
            z_vals = near * (1.0 - z_vals) + far * z_vals
            
        z_vals = z_vals.expand(N, num_samples)
        
        # Get 3D points
        points = rays_o.unsqueeze(1) + rays_d.unsqueeze(1) * z_vals.unsqueeze(-1)
        
        return points, z_vals
    
    def volume_render(self, densities: torch.Tensor, colors: torch.Tensor, 
                     z_vals: torch.Tensor, rays_d: torch.Tensor,
                     white_background: bool = False) -> Dict[str, torch.Tensor]:
        """
        Perform volume rendering.
        
        Args:
            densities: Volume densities, shape (N, num_samples)
            colors: RGB colors, shape (N, num_samples, 3)
            z_vals: Depth values, shape (N, num_samples)
            rays_d: Ray directions, shape (N, 3)
            white_background: Whether to use white background
            
        Returns:
            Dictionary containing rendered RGB, depth, and weights
        """
        # Compute distances between adjacent samples
        dists = z_vals[..., 1:] - z_vals[..., :-1]
        dists = torch.cat([dists, torch.full_like(dists[..., :1], 1e10)], dim=-1)
        
        # Apply ray direction scaling
        dists = dists * torch.norm(rays_d, dim=-1, keepdim=True)
        
        # Compute alpha values
        alpha = 1.0 - torch.exp(-F.relu(densities) * dists)
        
        # Compute transmittance
        transmittance = torch.cumprod(1.0 - alpha + 1e-10, dim=-1)
        transmittance = torch.cat([torch.ones_like(transmittance[..., :1]), transmittance[..., :-1]], dim=-1)
        
        # Compute weights
        weights = alpha * transmittance
        
        # Render RGB
        rgb = torch.sum(weights.unsqueeze(-1) * colors, dim=-2)
        
        # Handle background
        if white_background:
            acc_weights = torch.sum(weights, dim=-1, keepdim=True)
            rgb = rgb + (1.0 - acc_weights)
            
        # Render depth
        depth = torch.sum(weights * z_vals, dim=-1)
        
        # Render additional features
        outputs = {
            'rgb': rgb,
            'depth': depth,
            'weights': weights,
            'alpha': alpha,
            'transmittance': transmittance
        }
        
        return outputs
    
    def forward(self, rays_o: torch.Tensor, rays_d: torch.Tensor, 
                near: Optional[float] = None, far: Optional[float] = None) -> Dict[str, torch.Tensor]:
        """
        Full forward pass through NeRF renderer.
        
        Args:
            rays_o: Ray origins, shape (N, 3)
            rays_d: Ray directions, shape (N, 3)
            near: Near plane distance
            far: Far plane distance
            
        Returns:
            Dictionary containing rendered outputs
        """
        near = near or self.config.near_plane
        far = far or self.config.far_plane
        
        # Coarse pass
        coarse_points, coarse_z_vals = self.sample_rays(
            rays_o, rays_d, near, far, self.config.num_coarse_samples
        )
        
        # Flatten for network evaluation
        coarse_points_flat = coarse_points.view(-1, 3)
        rays_d_expanded = rays_d.unsqueeze(1).expand(-1, self.config.num_coarse_samples, -1)
        rays_d_flat = rays_d_expanded.reshape(-1, 3)
        
        # Evaluate coarse network
        coarse_outputs = self.coarse_network(coarse_points_flat, rays_d_flat)
        
        # Reshape outputs
        coarse_densities = coarse_outputs['density'].view(rays_o.shape[0], self.config.num_coarse_samples)
        coarse_colors = coarse_outputs['color'].view(rays_o.shape[0], self.config.num_coarse_samples, 3)
        
        # Volume rendering for coarse pass
        coarse_rendered = self.volume_render(
            coarse_densities, coarse_colors, coarse_z_vals, rays_d, self.config.white_background
        )
        
        outputs = {'coarse': coarse_rendered}
        
        # Fine pass (hierarchical sampling)
        if self.config.num_fine_samples > 0 and hasattr(self, 'fine_network'):
            # Importance sampling based on coarse weights
            coarse_weights = coarse_rendered['weights'].detach()
            fine_z_vals = self.sample_hierarchical(coarse_z_vals, coarse_weights, self.config.num_fine_samples)
            
            # Combine coarse and fine samples
            all_z_vals, sort_indices = torch.sort(torch.cat([coarse_z_vals, fine_z_vals], dim=-1), dim=-1)
            
            # Get fine points
            fine_points = rays_o.unsqueeze(1) + rays_d.unsqueeze(1) * all_z_vals.unsqueeze(-1)
            fine_points_flat = fine_points.view(-1, 3)
            
            rays_d_fine_expanded = rays_d.unsqueeze(1).expand(-1, all_z_vals.shape[1], -1)
            rays_d_fine_flat = rays_d_fine_expanded.reshape(-1, 3)
            
            # Evaluate fine network
            fine_outputs = self.fine_network(fine_points_flat, rays_d_fine_flat)
            
            # Reshape fine outputs
            fine_densities = fine_outputs['density'].view(rays_o.shape[0], all_z_vals.shape[1])
            fine_colors = fine_outputs['color'].view(rays_o.shape[0], all_z_vals.shape[1], 3)
            
            # Volume rendering for fine pass
            fine_rendered = self.volume_render(
                fine_densities, fine_colors, all_z_vals, rays_d, self.config.white_background
            )
            
            outputs['fine'] = fine_rendered
            
            # Add semantic and lighting features if enabled
            if self.config.enable_semantic_features:
                outputs['semantic_features'] = fine_outputs['semantic_features'].view(
                    rays_o.shape[0], all_z_vals.shape[1], -1
                )
                
            if self.config.enable_lighting_estimation:
                outputs['lighting_features'] = fine_outputs['lighting_features'].view(
                    rays_o.shape[0], all_z_vals.shape[1], -1
                )
        
        return outputs
    
    def sample_hierarchical(self, z_vals: torch.Tensor, weights: torch.Tensor, 
                           num_samples: int) -> torch.Tensor:
        """
        Hierarchical sampling based on coarse weights.
        
        Args:
            z_vals: Coarse z-values, shape (N, num_coarse)
            weights: Coarse weights, shape (N, num_coarse)
            num_samples: Number of fine samples
            
        Returns:
            Fine z-values, shape (N, num_samples)
        """
        N = z_vals.shape[0]
        
        # Get bin centers
        z_vals_mid = 0.5 * (z_vals[..., :-1] + z_vals[..., 1:])
        
        # Get PDF
        weights_mid = weights[..., 1:-1]  # Remove first and last
        weights_mid = weights_mid + 1e-5  # Prevent NaNs
        pdf = weights_mid / torch.sum(weights_mid, dim=-1, keepdim=True)
        cdf = torch.cumsum(pdf, dim=-1)
        cdf = torch.cat([torch.zeros_like(cdf[..., :1]), cdf], dim=-1)
        
        # Sample from CDF
        u = torch.rand(N, num_samples, device=z_vals.device)
        indices = torch.searchsorted(cdf.detach(), u, right=True)
        
        # Clamp indices
        below = torch.clamp(indices - 1, 0, cdf.shape[-1] - 1)
        above = torch.clamp(indices, 0, cdf.shape[-1] - 1)
        
        # Linear interpolation
        cdf_below = torch.gather(cdf, -1, below)
        cdf_above = torch.gather(cdf, -1, above)
        z_below = torch.gather(z_vals_mid, -1, below)
        z_above = torch.gather(z_vals_mid, -1, above)
        
        # Interpolation weights
        denom = cdf_above - cdf_below
        denom = torch.where(denom < 1e-5, torch.ones_like(denom), denom)
        t = (u - cdf_below) / denom
        
        fine_z_vals = z_below + t * (z_above - z_below)
        
        return fine_z_vals