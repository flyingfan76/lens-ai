"""
NeRF Training Pipeline for Camera Companion
Trains Neural Radiance Fields on photography datasets for scene understanding
"""

import torch
import torch.nn.functional as F
import torch.optim as optim
from torch.utils.data import Dataset, DataLoader
from torch.utils.tensorboard import SummaryWriter

import numpy as np
import cv2
import os
import json
from pathlib import Path
from typing import Dict, List, Tuple, Optional, Union
import logging
from tqdm import tqdm

from .nerf_model import NeRFRenderer
from .nerf_config import NeRFConfig
from .camera_nerf_analyzer import CameraNeRFAnalyzer

logger = logging.getLogger(__name__)

class PhotographyDataset(Dataset):
    """Dataset for photography scenes with camera parameters."""
    
    def __init__(self, data_dir: str, config: NeRFConfig, mode: str = 'train'):
        self.data_dir = Path(data_dir)
        self.config = config
        self.mode = mode
        
        # Load dataset metadata
        self.scene_data = self._load_scene_data()
        self.images = self._load_images()
        
        # Camera intrinsics and poses
        self.camera_intrinsics = self._load_camera_intrinsics()
        self.camera_poses = self._load_camera_poses()
        
        # Photography metadata (ISO, aperture, etc.)
        self.photo_metadata = self._load_photo_metadata()
        
    def __len__(self) -> int:
        return len(self.images)
    
    def __getitem__(self, idx: int) -> Dict[str, torch.Tensor]:
        """Get training sample."""
        # Load image
        image = self.images[idx]
        H, W = image.shape[:2]
        
        # Get camera parameters
        camera_pose = self.camera_poses[idx] if idx < len(self.camera_poses) else np.eye(4)
        camera_intrinsic = self.camera_intrinsics[idx] if idx < len(self.camera_intrinsics) else self._default_intrinsics(W, H)
        
        # Generate rays
        rays_o, rays_d = self._generate_rays(H, W, camera_intrinsic, camera_pose)
        
        # Sample rays for training
        if self.mode == 'train':
            ray_indices = torch.randint(0, rays_o.shape[0], (self.config.batch_size,))
            rays_o = rays_o[ray_indices]
            rays_d = rays_d[ray_indices]
            target_rgb = torch.from_numpy(image.reshape(-1, 3))[ray_indices]
        else:
            target_rgb = torch.from_numpy(image.reshape(-1, 3))
        
        # Additional photography-aware targets
        depth_target = self._get_depth_target(idx, H, W) if self.config.use_depth_supervision else None
        semantic_target = self._get_semantic_target(idx, H, W) if self.config.enable_semantic_features else None
        
        sample = {
            'rays_o': rays_o.float(),
            'rays_d': rays_d.float(),
            'target_rgb': target_rgb.float() / 255.0,
            'image_idx': torch.tensor(idx),
            'camera_pose': torch.from_numpy(camera_pose).float(),
            'camera_intrinsic': torch.from_numpy(camera_intrinsic).float()
        }
        
        # Add optional targets
        if depth_target is not None:
            if self.mode == 'train':
                sample['target_depth'] = depth_target[ray_indices]
            else:
                sample['target_depth'] = depth_target
                
        if semantic_target is not None:
            if self.mode == 'train':
                sample['target_semantic'] = semantic_target[ray_indices]
            else:
                sample['target_semantic'] = semantic_target
        
        # Photography metadata
        if idx < len(self.photo_metadata):
            sample['photo_metadata'] = self.photo_metadata[idx]
        
        return sample
    
    def _load_scene_data(self) -> Dict:
        """Load scene metadata."""
        metadata_file = self.data_dir / 'scene_metadata.json'
        if metadata_file.exists():
            with open(metadata_file) as f:
                return json.load(f)
        return {}
    
    def _load_images(self) -> List[np.ndarray]:
        """Load training images."""
        images = []
        image_dir = self.data_dir / 'images'
        
        for img_file in sorted(image_dir.glob('*.jpg')):
            img = cv2.imread(str(img_file))
            img = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
            images.append(img)
            
        return images
    
    def _load_camera_intrinsics(self) -> List[np.ndarray]:
        """Load camera intrinsic parameters."""
        intrinsics_file = self.data_dir / 'camera_intrinsics.json'
        if intrinsics_file.exists():
            with open(intrinsics_file) as f:
                intrinsics_data = json.load(f)
                return [np.array(K) for K in intrinsics_data['intrinsics']]
        
        # Generate default intrinsics for each image
        return [self._default_intrinsics(img.shape[1], img.shape[0]) for img in self.images]
    
    def _load_camera_poses(self) -> List[np.ndarray]:
        """Load camera poses."""
        poses_file = self.data_dir / 'camera_poses.json'
        if poses_file.exists():
            with open(poses_file) as f:
                poses_data = json.load(f)
                return [np.array(pose) for pose in poses_data['poses']]
        
        # Generate identity poses for single-view training
        return [np.eye(4) for _ in self.images]
    
    def _load_photo_metadata(self) -> List[Dict]:
        """Load photography metadata (ISO, aperture, etc.)."""
        metadata_file = self.data_dir / 'photo_metadata.json'
        if metadata_file.exists():
            with open(metadata_file) as f:
                return json.load(f)['photos']
        
        return [{'iso': 400, 'aperture': 'f/4.0', 'shutter_speed': '1/125'} for _ in self.images]
    
    def _default_intrinsics(self, W: int, H: int) -> np.ndarray:
        """Generate default camera intrinsics."""
        focal = 0.5 * W / np.tan(0.5 * np.deg2rad(50))  # 50-degree FOV
        return np.array([
            [focal, 0, W * 0.5],
            [0, focal, H * 0.5],
            [0, 0, 1]
        ])
    
    def _generate_rays(self, H: int, W: int, intrinsic: np.ndarray, 
                      pose: np.ndarray) -> Tuple[torch.Tensor, torch.Tensor]:
        """Generate camera rays."""
        i, j = np.meshgrid(np.arange(W), np.arange(H), indexing='xy')
        
        # Convert to camera coordinates
        dirs = np.stack([
            (i - intrinsic[0, 2]) / intrinsic[0, 0],
            -(j - intrinsic[1, 2]) / intrinsic[1, 1],
            -np.ones_like(i)
        ], axis=-1)
        
        # Transform by camera pose
        rays_d = np.sum(dirs[..., None, :] * pose[:3, :3], axis=-1)
        rays_o = np.broadcast_to(pose[:3, 3], rays_d.shape)
        
        # Flatten
        rays_o = torch.from_numpy(rays_o.reshape(-1, 3))
        rays_d = torch.from_numpy(rays_d.reshape(-1, 3))
        
        return rays_o, rays_d
    
    def _get_depth_target(self, idx: int, H: int, W: int) -> Optional[torch.Tensor]:
        """Get depth supervision target if available."""
        depth_file = self.data_dir / 'depths' / f'{idx:04d}.npy'
        if depth_file.exists():
            depth = np.load(depth_file)
            return torch.from_numpy(depth.reshape(-1)).float()
        return None
    
    def _get_semantic_target(self, idx: int, H: int, W: int) -> Optional[torch.Tensor]:
        """Get semantic segmentation target if available."""
        semantic_file = self.data_dir / 'semantics' / f'{idx:04d}.npy'
        if semantic_file.exists():
            semantic = np.load(semantic_file)
            return torch.from_numpy(semantic.reshape(-1)).long()
        return None

class NeRFTrainer:
    """NeRF training manager for photography scenes."""
    
    def __init__(self, config: NeRFConfig, data_dir: str):
        self.config = config
        self.data_dir = data_dir
        self.device = torch.device(config.device)
        
        # Initialize model
        self.model = NeRFRenderer(config).to(self.device)
        
        # Initialize optimizer
        self.optimizer = optim.Adam(self.model.parameters(), lr=config.learning_rate)
        self.scheduler = optim.lr_scheduler.ExponentialLR(
            self.optimizer, gamma=0.1**(1/config.learning_rate_decay)
        )
        
        # Initialize datasets
        self.train_dataset = PhotographyDataset(data_dir, config, mode='train')
        self.val_dataset = PhotographyDataset(data_dir, config, mode='val')
        
        self.train_loader = DataLoader(
            self.train_dataset, batch_size=1, shuffle=True, num_workers=config.num_workers
        )
        self.val_loader = DataLoader(
            self.val_dataset, batch_size=1, shuffle=False, num_workers=config.num_workers
        )
        
        # Logging
        self.writer = SummaryWriter(log_dir=config.log_dir)
        self.step = 0
        
        # Create output directories
        os.makedirs(config.checkpoint_dir, exist_ok=True)
        os.makedirs(config.output_dir, exist_ok=True)
    
    def train(self):
        """Main training loop."""
        logger.info(f"Starting NeRF training for {self.config.max_epochs} epochs")
        
        self.model.train()
        
        for epoch in range(self.config.max_epochs):
            epoch_losses = []
            
            pbar = tqdm(self.train_loader, desc=f'Epoch {epoch+1}/{self.config.max_epochs}')
            
            for batch in pbar:
                loss_dict = self.train_step(batch)
                epoch_losses.append(loss_dict['total_loss'])
                
                # Update progress bar
                pbar.set_postfix({'loss': f"{loss_dict['total_loss']:.4f}"})
                
                # Log metrics
                if self.step % 100 == 0:
                    self.log_metrics(loss_dict, 'train')
                
                # Validation
                if self.step % self.config.test_frequency == 0:
                    self.validate()
                
                # Save checkpoint
                if self.step % self.config.save_frequency == 0:
                    self.save_checkpoint(epoch)
                
                self.step += 1
            
            # End of epoch logging
            avg_loss = np.mean(epoch_losses)
            logger.info(f"Epoch {epoch+1} average loss: {avg_loss:.4f}")
            
            # Learning rate scheduling
            self.scheduler.step()
    
    def train_step(self, batch: Dict[str, torch.Tensor]) -> Dict[str, float]:
        """Single training step."""
        self.optimizer.zero_grad()
        
        # Move batch to device
        rays_o = batch['rays_o'].squeeze(0).to(self.device)
        rays_d = batch['rays_d'].squeeze(0).to(self.device)
        target_rgb = batch['target_rgb'].squeeze(0).to(self.device)
        
        # Forward pass
        outputs = self.model(rays_o, rays_d)
        
        # Compute losses
        loss_dict = self.compute_losses(outputs, target_rgb, batch)
        
        # Backward pass
        loss_dict['total_loss'].backward()
        self.optimizer.step()
        
        return {k: v.item() if isinstance(v, torch.Tensor) else v for k, v in loss_dict.items()}
    
    def compute_losses(self, outputs: Dict[str, torch.Tensor], 
                      target_rgb: torch.Tensor, batch: Dict[str, torch.Tensor]) -> Dict[str, torch.Tensor]:
        """Compute training losses."""
        losses = {}
        
        # RGB reconstruction loss (coarse)
        coarse_rgb = outputs['coarse']['rgb']
        coarse_loss = F.mse_loss(coarse_rgb, target_rgb)
        losses['coarse_rgb_loss'] = coarse_loss * self.config.coarse_loss_weight
        
        # RGB reconstruction loss (fine)
        if 'fine' in outputs:
            fine_rgb = outputs['fine']['rgb']
            fine_loss = F.mse_loss(fine_rgb, target_rgb)
            losses['fine_rgb_loss'] = fine_loss * self.config.fine_loss_weight
        
        # Depth supervision loss
        if 'target_depth' in batch and self.config.use_depth_supervision:
            target_depth = batch['target_depth'].squeeze(0).to(self.device)
            
            if 'fine' in outputs:
                pred_depth = outputs['fine']['depth']
            else:
                pred_depth = outputs['coarse']['depth']
            
            if self.config.depth_loss_type == 'l1':
                depth_loss = F.l1_loss(pred_depth, target_depth)
            elif self.config.depth_loss_type == 'smooth_l1':
                depth_loss = F.smooth_l1_loss(pred_depth, target_depth)
            else:
                depth_loss = F.mse_loss(pred_depth, target_depth)
            
            losses['depth_loss'] = depth_loss * self.config.depth_loss_weight
        
        # Semantic loss
        if 'target_semantic' in batch and self.config.enable_semantic_features:
            target_semantic = batch['target_semantic'].squeeze(0).to(self.device)
            
            if 'semantic_features' in outputs:
                semantic_features = outputs['semantic_features']
                # Simplified semantic loss - would need proper semantic head
                semantic_loss = F.mse_loss(semantic_features.mean(dim=-1), target_semantic.float())
                losses['semantic_loss'] = semantic_loss * 0.1
        
        # Total loss
        losses['total_loss'] = sum(losses.values())
        
        return losses
    
    def validate(self):
        """Validation step."""
        self.model.eval()
        val_losses = []
        
        with torch.no_grad():
            for batch in self.val_loader:
                rays_o = batch['rays_o'].squeeze(0).to(self.device)
                rays_d = batch['rays_d'].squeeze(0).to(self.device)
                target_rgb = batch['target_rgb'].squeeze(0).to(self.device)
                
                outputs = self.model(rays_o, rays_d)
                loss_dict = self.compute_losses(outputs, target_rgb, batch)
                val_losses.append(loss_dict['total_loss'].item())
        
        avg_val_loss = np.mean(val_losses)
        self.log_metrics({'total_loss': avg_val_loss}, 'val')
        
        logger.info(f"Validation loss at step {self.step}: {avg_val_loss:.4f}")
        
        self.model.train()
    
    def log_metrics(self, metrics: Dict[str, float], prefix: str):
        """Log training metrics."""
        for key, value in metrics.items():
            self.writer.add_scalar(f'{prefix}/{key}', value, self.step)
    
    def save_checkpoint(self, epoch: int):
        """Save model checkpoint."""
        checkpoint = {
            'epoch': epoch,
            'step': self.step,
            'model_state_dict': self.model.state_dict(),
            'optimizer_state_dict': self.optimizer.state_dict(),
            'scheduler_state_dict': self.scheduler.state_dict(),
            'config': self.config.to_dict()
        }
        
        checkpoint_path = Path(self.config.checkpoint_dir) / f'nerf_checkpoint_{self.step:06d}.pth'
        torch.save(checkpoint, checkpoint_path)
        
        # Also save as latest
        latest_path = Path(self.config.checkpoint_dir) / 'nerf_model.pth'
        torch.save(checkpoint, latest_path)
        
        logger.info(f"Saved checkpoint: {checkpoint_path}")
    
    def load_checkpoint(self, checkpoint_path: str):
        """Load model checkpoint."""
        checkpoint = torch.load(checkpoint_path, map_location=self.device)
        
        self.model.load_state_dict(checkpoint['model_state_dict'])
        self.optimizer.load_state_dict(checkpoint['optimizer_state_dict'])
        self.scheduler.load_state_dict(checkpoint['scheduler_state_dict'])
        self.step = checkpoint['step']
        
        logger.info(f"Loaded checkpoint from {checkpoint_path}")
    
    def render_scene(self, camera_pose: np.ndarray, camera_intrinsic: np.ndarray, 
                    H: int, W: int, output_path: str):
        """Render a scene from a given viewpoint."""
        self.model.eval()
        
        with torch.no_grad():
            # Generate rays
            i, j = np.meshgrid(np.arange(W), np.arange(H), indexing='xy')
            
            dirs = np.stack([
                (i - camera_intrinsic[0, 2]) / camera_intrinsic[0, 0],
                -(j - camera_intrinsic[1, 2]) / camera_intrinsic[1, 1],
                -np.ones_like(i)
            ], axis=-1)
            
            rays_d = np.sum(dirs[..., None, :] * camera_pose[:3, :3], axis=-1)
            rays_o = np.broadcast_to(camera_pose[:3, 3], rays_d.shape)
            
            rays_o = torch.from_numpy(rays_o.reshape(-1, 3)).float().to(self.device)
            rays_d = torch.from_numpy(rays_d.reshape(-1, 3)).float().to(self.device)
            
            # Render in chunks to avoid memory issues
            chunk_size = 1024
            rgb_chunks = []
            depth_chunks = []
            
            for i in range(0, rays_o.shape[0], chunk_size):
                chunk_rays_o = rays_o[i:i+chunk_size]
                chunk_rays_d = rays_d[i:i+chunk_size]
                
                outputs = self.model(chunk_rays_o, chunk_rays_d)
                
                if 'fine' in outputs:
                    rgb_chunks.append(outputs['fine']['rgb'].cpu())
                    depth_chunks.append(outputs['fine']['depth'].cpu())
                else:
                    rgb_chunks.append(outputs['coarse']['rgb'].cpu())
                    depth_chunks.append(outputs['coarse']['depth'].cpu())
            
            # Combine chunks
            rgb = torch.cat(rgb_chunks, dim=0).reshape(H, W, 3)
            depth = torch.cat(depth_chunks, dim=0).reshape(H, W)
            
            # Convert to images
            rgb_img = (rgb.numpy() * 255).astype(np.uint8)
            depth_img = (depth.numpy() / depth.max() * 255).astype(np.uint8)
            
            # Save images
            cv2.imwrite(output_path, cv2.cvtColor(rgb_img, cv2.COLOR_RGB2BGR))
            cv2.imwrite(output_path.replace('.jpg', '_depth.jpg'), depth_img)
        
        self.model.train()

def create_training_data(image_paths: List[str], output_dir: str, 
                        camera_data: Optional[Dict] = None):
    """
    Create training dataset from photography images.
    
    Args:
        image_paths: List of paths to training images
        output_dir: Directory to save processed dataset
        camera_data: Optional camera parameters and metadata
    """
    output_path = Path(output_dir)
    output_path.mkdir(parents=True, exist_ok=True)
    
    # Create directories
    (output_path / 'images').mkdir(exist_ok=True)
    (output_path / 'depths').mkdir(exist_ok=True)
    (output_path / 'semantics').mkdir(exist_ok=True)
    
    # Process images
    processed_images = []
    photo_metadata = []
    
    for i, img_path in enumerate(tqdm(image_paths, desc="Processing images")):
        # Load and resize image
        img = cv2.imread(img_path)
        img = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
        
        # Resize to manageable size
        target_size = 800
        h, w = img.shape[:2]
        if max(h, w) > target_size:
            scale = target_size / max(h, w)
            new_h, new_w = int(h * scale), int(w * scale)
            img = cv2.resize(img, (new_w, new_h))
        
        # Save processed image
        output_img_path = output_path / 'images' / f'{i:04d}.jpg'
        cv2.imwrite(str(output_img_path), cv2.cvtColor(img, cv2.COLOR_RGB2BGR))
        
        processed_images.append(img)
        
        # Extract metadata (placeholder - would use EXIF data in real implementation)
        metadata = {
            'iso': 400,
            'aperture': 'f/4.0',
            'shutter_speed': '1/125',
            'focal_length': '50mm',
            'white_balance': 'auto'
        }
        photo_metadata.append(metadata)
    
    # Save metadata
    scene_metadata = {
        'num_images': len(processed_images),
        'scene_type': 'photography',
        'created_by': 'camera_companion'
    }
    
    with open(output_path / 'scene_metadata.json', 'w') as f:
        json.dump(scene_metadata, f, indent=2)
    
    with open(output_path / 'photo_metadata.json', 'w') as f:
        json.dump({'photos': photo_metadata}, f, indent=2)
    
    # Generate default camera poses (identity for single-view)
    poses = [np.eye(4).tolist() for _ in processed_images]
    with open(output_path / 'camera_poses.json', 'w') as f:
        json.dump({'poses': poses}, f, indent=2)
    
    # Generate default intrinsics
    intrinsics = []
    for img in processed_images:
        h, w = img.shape[:2]
        focal = 0.5 * w / np.tan(0.5 * np.deg2rad(50))
        K = [
            [focal, 0, w * 0.5],
            [0, focal, h * 0.5],
            [0, 0, 1]
        ]
        intrinsics.append(K)
    
    with open(output_path / 'camera_intrinsics.json', 'w') as f:
        json.dump({'intrinsics': intrinsics}, f, indent=2)
    
    logger.info(f"Created training dataset with {len(processed_images)} images in {output_dir}")

if __name__ == '__main__':
    # Example training script
    config = NeRFConfig()
    trainer = NeRFTrainer(config, 'data/photography_scenes')
    trainer.train()