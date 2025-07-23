"""
NeRF Configuration and Hyperparameters for Camera Companion
Neural Radiance Fields for 3D Scene Understanding and Camera Parameter Optimization
"""

import os
from dataclasses import dataclass
from typing import Tuple, Optional, Dict, Any
import torch

@dataclass
class NeRFConfig:
    """Configuration class for NeRF model and training."""
    
    # Model Architecture
    num_layers: int = 8
    hidden_dim: int = 256
    skip_connections: Tuple[int, ...] = (4,)
    use_viewdirs: bool = True
    viewdir_dim: int = 4
    
    # Positional Encoding
    pos_encoding_levels: int = 10
    dir_encoding_levels: int = 4
    include_input: bool = True
    
    # Ray Sampling
    num_coarse_samples: int = 64
    num_fine_samples: int = 128
    near_plane: float = 0.1
    far_plane: float = 10.0
    use_viewdirs_fine: bool = True
    
    # Training Parameters
    learning_rate: float = 5e-4
    learning_rate_decay: int = 250000
    batch_size: int = 1024  # Number of rays per batch
    max_epochs: int = 200000
    
    # Loss Configuration
    coarse_loss_weight: float = 1.0
    fine_loss_weight: float = 1.0
    rgb_loss_weight: float = 1.0
    depth_loss_weight: float = 0.1
    
    # Regularization
    use_depth_supervision: bool = True
    depth_loss_type: str = "l1"  # "l1", "l2", "smooth_l1"
    white_background: bool = False
    
    # Camera Parameter Optimization
    optimize_camera_params: bool = True
    camera_lr: float = 1e-3
    optimize_poses: bool = True
    optimize_intrinsics: bool = False
    
    # Scene Analysis Features
    enable_semantic_features: bool = True
    semantic_dim: int = 16
    enable_lighting_estimation: bool = True
    lighting_dim: int = 8
    
    # Hardware Configuration
    device: str = "cuda" if torch.cuda.is_available() else "cpu"
    num_workers: int = 4
    mixed_precision: bool = True
    
    # I/O Configuration
    checkpoint_dir: str = "checkpoints"
    log_dir: str = "logs"
    output_dir: str = "outputs"
    save_frequency: int = 10000
    test_frequency: int = 5000
    
    # Camera Companion Specific Features
    camera_optimization_mode: str = "adaptive"  # "adaptive", "fixed", "guided"
    scene_understanding_depth: int = 3  # Levels of scene decomposition
    enable_real_time_optimization: bool = True
    real_time_batch_size: int = 256
    
    # Quality vs Speed Trade-offs
    quality_preset: str = "balanced"  # "fast", "balanced", "quality"
    
    def __post_init__(self):
        """Adjust parameters based on quality preset."""
        if self.quality_preset == "fast":
            self.num_coarse_samples = 32
            self.num_fine_samples = 64
            self.batch_size = 512
            self.real_time_batch_size = 128
        elif self.quality_preset == "quality":
            self.num_coarse_samples = 128
            self.num_fine_samples = 256
            self.batch_size = 2048
            self.real_time_batch_size = 512
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert config to dictionary."""
        return {k: v for k, v in self.__dict__.items()}
    
    @classmethod
    def from_dict(cls, config_dict: Dict[str, Any]) -> 'NeRFConfig':
        """Create config from dictionary."""
        return cls(**config_dict)
    
    def save(self, filepath: str):
        """Save configuration to file."""
        import json
        os.makedirs(os.path.dirname(filepath), exist_ok=True)
        with open(filepath, 'w') as f:
            json.dump(self.to_dict(), f, indent=2)
    
    @classmethod
    def load(cls, filepath: str) -> 'NeRFConfig':
        """Load configuration from file."""
        import json
        with open(filepath, 'r') as f:
            config_dict = json.load(f)
        return cls.from_dict(config_dict)

@dataclass
class CameraOptimizationConfig:
    """Specific configuration for camera parameter optimization using NeRF."""
    
    # Optimization Targets
    optimize_exposure: bool = True
    optimize_focus: bool = True
    optimize_composition: bool = True
    optimize_depth_of_field: bool = True
    
    # Scene Understanding
    analyze_depth_layers: bool = True
    analyze_subject_isolation: bool = True
    analyze_lighting_distribution: bool = True
    analyze_color_harmony: bool = True
    
    # Real-time Constraints
    max_inference_time_ms: float = 100.0
    max_optimization_iterations: int = 10
    convergence_threshold: float = 1e-4
    
    # Photography-specific Parameters
    focus_plane_estimation: bool = True
    bokeh_quality_assessment: bool = True
    lighting_quality_assessment: bool = True
    composition_rule_checking: bool = True
    
    # Advanced Features
    multi_exposure_fusion: bool = False
    hdr_tone_mapping: bool = False
    noise_reduction_analysis: bool = True
    motion_blur_detection: bool = True

# Default configurations for different use cases
DEFAULT_CONFIG = NeRFConfig()

FAST_CONFIG = NeRFConfig(
    quality_preset="fast",
    num_layers=6,
    hidden_dim=128,
    max_epochs=50000,
    batch_size=512
)

QUALITY_CONFIG = NeRFConfig(
    quality_preset="quality",
    num_layers=10,
    hidden_dim=512,
    max_epochs=500000,
    batch_size=2048
)

REAL_TIME_CONFIG = NeRFConfig(
    quality_preset="fast",
    num_layers=4,
    hidden_dim=64,
    num_coarse_samples=16,
    num_fine_samples=32,
    batch_size=256,
    enable_real_time_optimization=True
)