"""
NeRF Module for Camera Companion
Advanced AI with NeRF-based 3D Scene Analysis
"""

from .nerf_config import (
    NeRFConfig,
    CameraOptimizationConfig,
    DEFAULT_CONFIG,
    FAST_CONFIG,
    QUALITY_CONFIG,
    REAL_TIME_CONFIG
)

from .nerf_model import (
    NeRFRenderer,
    NeRFMLP,
    PositionalEncoding
)

from .camera_nerf_analyzer import (
    CameraNeRFAnalyzer,
    CameraParameterOptimizer,
    DepthEstimator,
    LightingAnalyzer,
    CompositionAnalyzer
)

from .nerf_trainer import (
    NeRFTrainer,
    PhotographyDataset,
    create_training_data
)

from .nerf_service import (
    NeRFService,
    NeRFBackendIntegration
)

__version__ = "1.0.0"
__author__ = "Camera Companion Team"

__all__ = [
    # Configuration
    'NeRFConfig',
    'CameraOptimizationConfig',
    'DEFAULT_CONFIG',
    'FAST_CONFIG', 
    'QUALITY_CONFIG',
    'REAL_TIME_CONFIG',
    
    # Core Models
    'NeRFRenderer',
    'NeRFMLP',
    'PositionalEncoding',
    
    # Analysis Components
    'CameraNeRFAnalyzer',
    'CameraParameterOptimizer',
    'DepthEstimator',
    'LightingAnalyzer',
    'CompositionAnalyzer',
    
    # Training
    'NeRFTrainer',
    'PhotographyDataset',
    'create_training_data',
    
    # Service Integration
    'NeRFService',
    'NeRFBackendIntegration'
]