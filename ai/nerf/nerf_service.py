"""
NeRF Service for Camera Companion Backend Integration
Provides NeRF-based 3D scene analysis as a service
"""

import asyncio
import logging
import json
import tempfile
import os
from pathlib import Path
from typing import Dict, List, Optional, Union
import numpy as np
import cv2
import torch

from fastapi import FastAPI, HTTPException, UploadFile, File, BackgroundTasks
from pydantic import BaseModel
import uvicorn

from .camera_nerf_analyzer import CameraNeRFAnalyzer
from .nerf_config import NeRFConfig, CameraOptimizationConfig, REAL_TIME_CONFIG
from .nerf_trainer import NeRFTrainer, create_training_data

logger = logging.getLogger(__name__)

# Pydantic models for API
class NeRFAnalysisRequest(BaseModel):
    image_path: Optional[str] = None
    camera_poses: Optional[List[List[float]]] = None
    camera_intrinsics: Optional[List[List[float]]] = None
    analysis_mode: str = "real_time"  # "real_time", "quality", "fast"
    optimize_camera_params: bool = True

class NeRFAnalysisResponse(BaseModel):
    scene_analysis: Dict
    camera_optimization: Dict
    depth_analysis: Dict
    lighting_analysis: Dict
    composition_analysis: Dict
    processing_time: float
    analysis_type: str
    status: str

class TrainingRequest(BaseModel):
    dataset_name: str
    image_paths: List[str]
    config_preset: str = "default"  # "fast", "balanced", "quality"
    enable_depth_supervision: bool = False
    enable_semantic_features: bool = True

class NeRFService:
    """FastAPI service for NeRF-based scene analysis."""
    
    def __init__(self, config: Optional[NeRFConfig] = None):
        self.config = config or REAL_TIME_CONFIG
        self.camera_config = CameraOptimizationConfig()
        
        # Initialize NeRF analyzer
        self.analyzer = CameraNeRFAnalyzer(self.config, self.camera_config)
        
        # Training manager
        self.trainer = None
        self.training_jobs = {}  # Track background training jobs
        
        # FastAPI app
        self.app = FastAPI(
            title="NeRF Scene Analysis Service",
            description="3D scene understanding using Neural Radiance Fields",
            version="1.0.0"
        )
        
        # Setup routes
        self._setup_routes()
        
        logger.info("NeRF Service initialized")
    
    def _setup_routes(self):
        """Setup FastAPI routes."""
        
        @self.app.get("/health")
        async def health_check():
            """Health check endpoint."""
            return {
                "status": "healthy",
                "service": "nerf_analysis",
                "device": str(self.config.device),
                "model_loaded": hasattr(self.analyzer.nerf_renderer, 'coarse_network')
            }
        
        @self.app.post("/analyze", response_model=NeRFAnalysisResponse)
        async def analyze_scene(request: NeRFAnalysisRequest):
            """Analyze scene using NeRF."""
            try:
                import time
                start_time = time.time()
                
                # Adjust config based on analysis mode
                if request.analysis_mode == "fast":
                    analysis_config = NeRFConfig(quality_preset="fast")
                elif request.analysis_mode == "quality":
                    analysis_config = NeRFConfig(quality_preset="quality")
                else:
                    analysis_config = self.config
                
                # Load image
                if not request.image_path or not os.path.exists(request.image_path):
                    raise HTTPException(status_code=400, detail="Invalid image path")
                
                # Convert camera parameters
                camera_poses = None
                camera_intrinsics = None
                
                if request.camera_poses:
                    camera_poses = [np.array(pose).reshape(4, 4) for pose in request.camera_poses]
                
                if request.camera_intrinsics:
                    camera_intrinsics = np.array(request.camera_intrinsics)
                
                # Perform analysis
                result = self.analyzer.analyze_scene_3d(
                    request.image_path,
                    camera_poses,
                    camera_intrinsics
                )
                
                processing_time = time.time() - start_time
                
                return NeRFAnalysisResponse(
                    scene_analysis=result.get('nerf_analysis', {}),
                    camera_optimization=result.get('camera_optimization', {}),
                    depth_analysis=result.get('depth_analysis', {}),
                    lighting_analysis=result.get('lighting_analysis', {}),
                    composition_analysis=result.get('composition_analysis', {}),
                    processing_time=processing_time,
                    analysis_type=result.get('analysis_type', '3d_nerf'),
                    status="success"
                )
                
            except Exception as e:
                logger.error(f"NeRF analysis failed: {e}")
                raise HTTPException(status_code=500, detail=str(e))
        
        @self.app.post("/analyze/upload")
        async def analyze_uploaded_image(file: UploadFile = File(...)):
            """Analyze uploaded image using NeRF."""
            try:
                # Save uploaded file temporarily
                with tempfile.NamedTemporaryFile(suffix='.jpg', delete=False) as tmp_file:
                    content = await file.read()
                    tmp_file.write(content)
                    tmp_path = tmp_file.name
                
                try:
                    # Create analysis request
                    request = NeRFAnalysisRequest(
                        image_path=tmp_path,
                        analysis_mode="real_time"
                    )
                    
                    # Perform analysis
                    result = await analyze_scene(request)
                    return result
                    
                finally:
                    # Cleanup temporary file
                    try:
                        os.unlink(tmp_path)
                    except:
                        pass
                        
            except Exception as e:
                logger.error(f"Upload analysis failed: {e}")
                raise HTTPException(status_code=500, detail=str(e))
        
        @self.app.post("/train/start")
        async def start_training(request: TrainingRequest, background_tasks: BackgroundTasks):
            """Start NeRF training on provided dataset."""
            try:
                job_id = f"training_{len(self.training_jobs)}"
                
                # Validate image paths
                valid_paths = [p for p in request.image_paths if os.path.exists(p)]
                if len(valid_paths) == 0:
                    raise HTTPException(status_code=400, detail="No valid image paths provided")
                
                # Create training config
                if request.config_preset == "fast":
                    config = NeRFConfig(quality_preset="fast")
                elif request.config_preset == "quality":
                    config = NeRFConfig(quality_preset="quality")
                else:
                    config = NeRFConfig()
                
                config.use_depth_supervision = request.enable_depth_supervision
                config.enable_semantic_features = request.enable_semantic_features
                
                # Setup training data
                data_dir = f"data/training/{request.dataset_name}"
                create_training_data(valid_paths, data_dir)
                
                # Start background training
                self.training_jobs[job_id] = {
                    'status': 'starting',
                    'dataset_name': request.dataset_name,
                    'num_images': len(valid_paths),
                    'config': config.to_dict()
                }
                
                background_tasks.add_task(
                    self._run_training,
                    job_id,
                    config,
                    data_dir
                )
                
                return {
                    'job_id': job_id,
                    'status': 'started',
                    'dataset_name': request.dataset_name,
                    'num_images': len(valid_paths)
                }
                
            except Exception as e:
                logger.error(f"Training start failed: {e}")
                raise HTTPException(status_code=500, detail=str(e))
        
        @self.app.get("/train/status/{job_id}")
        async def get_training_status(job_id: str):
            """Get training job status."""
            if job_id not in self.training_jobs:
                raise HTTPException(status_code=404, detail="Training job not found")
            
            return self.training_jobs[job_id]
        
        @self.app.get("/models/list")
        async def list_models():
            """List available trained models."""
            models_dir = Path("models/nerf")
            models = []
            
            if models_dir.exists():
                for model_file in models_dir.glob("*.pth"):
                    try:
                        checkpoint = torch.load(model_file, map_location='cpu')
                        models.append({
                            'name': model_file.stem,
                            'path': str(model_file),
                            'epoch': checkpoint.get('epoch', 0),
                            'step': checkpoint.get('step', 0),
                            'config': checkpoint.get('config', {})
                        })
                    except:
                        continue
            
            return {'models': models}
        
        @self.app.post("/models/load/{model_name}")
        async def load_model(model_name: str):
            """Load a specific trained model."""
            try:
                model_path = Path("models/nerf") / f"{model_name}.pth"
                
                if not model_path.exists():
                    raise HTTPException(status_code=404, detail="Model not found")
                
                # Load the model
                checkpoint = torch.load(model_path, map_location=self.config.device)
                self.analyzer.nerf_renderer.load_state_dict(checkpoint['model_state_dict'])
                
                return {
                    'status': 'success',
                    'model_name': model_name,
                    'epoch': checkpoint.get('epoch', 0),
                    'step': checkpoint.get('step', 0)
                }
                
            except Exception as e:
                logger.error(f"Model loading failed: {e}")
                raise HTTPException(status_code=500, detail=str(e))
        
        @self.app.post("/render")
        async def render_scene(
            camera_pose: List[List[float]],
            camera_intrinsics: List[List[float]],
            width: int = 800,
            height: int = 600
        ):
            """Render scene from specified viewpoint."""
            try:
                pose = np.array(camera_pose).reshape(4, 4)
                intrinsics = np.array(camera_intrinsics)
                
                # Create temporary output path
                with tempfile.NamedTemporaryFile(suffix='.jpg', delete=False) as tmp_file:
                    output_path = tmp_file.name
                
                # Initialize trainer for rendering (if not already done)
                if self.trainer is None:
                    self.trainer = NeRFTrainer(self.config, "data/temp")
                    # Load current model state
                    self.trainer.model = self.analyzer.nerf_renderer
                
                # Render scene
                self.trainer.render_scene(pose, intrinsics, height, width, output_path)
                
                # Read rendered image
                with open(output_path, 'rb') as f:
                    image_data = f.read()
                
                # Cleanup
                try:
                    os.unlink(output_path)
                except:
                    pass
                
                return {
                    'status': 'success',
                    'image_size': len(image_data),
                    'width': width,
                    'height': height
                }
                
            except Exception as e:
                logger.error(f"Scene rendering failed: {e}")
                raise HTTPException(status_code=500, detail=str(e))
    
    async def _run_training(self, job_id: str, config: NeRFConfig, data_dir: str):
        """Run training in background."""
        try:
            self.training_jobs[job_id]['status'] = 'training'
            
            # Initialize trainer
            trainer = NeRFTrainer(config, data_dir)
            
            # Run training
            trainer.train()
            
            self.training_jobs[job_id]['status'] = 'completed'
            self.training_jobs[job_id]['model_path'] = str(Path(config.checkpoint_dir) / 'nerf_model.pth')
            
        except Exception as e:
            logger.error(f"Training job {job_id} failed: {e}")
            self.training_jobs[job_id]['status'] = 'failed'
            self.training_jobs[job_id]['error'] = str(e)
    
    def run(self, host: str = "0.0.0.0", port: int = 8001):
        """Run the NeRF service."""
        uvicorn.run(self.app, host=host, port=port)

# Integration with existing backend
class NeRFBackendIntegration:
    """Integration layer for NeRF service with existing Camera Companion backend."""
    
    def __init__(self, nerf_service_url: str = "http://localhost:8001"):
        self.nerf_service_url = nerf_service_url
        self.logger = logging.getLogger(__name__)
    
    async def analyze_image_with_nerf(self, image_path: str, 
                                    camera_data: Optional[Dict] = None) -> Dict:
        """
        Analyze image using NeRF service and integrate with existing analysis.
        
        This method would be called from the existing auto_adjustment_service.js
        """
        try:
            import aiohttp
            
            async with aiohttp.ClientSession() as session:
                # Prepare request
                request_data = {
                    "image_path": image_path,
                    "analysis_mode": "real_time",
                    "optimize_camera_params": True
                }
                
                if camera_data:
                    if 'poses' in camera_data:
                        request_data['camera_poses'] = camera_data['poses']
                    if 'intrinsics' in camera_data:
                        request_data['camera_intrinsics'] = camera_data['intrinsics']
                
                # Make request to NeRF service
                async with session.post(
                    f"{self.nerf_service_url}/analyze",
                    json=request_data
                ) as response:
                    if response.status == 200:
                        result = await response.json()
                        return self._format_for_backend(result)
                    else:
                        error_text = await response.text()
                        self.logger.error(f"NeRF service error: {error_text}")
                        return {'error': f'NeRF service error: {error_text}'}
                        
        except Exception as e:
            self.logger.error(f"NeRF integration error: {e}")
            return {'error': str(e)}
    
    def _format_for_backend(self, nerf_result: Dict) -> Dict:
        """Format NeRF analysis result for existing backend compatibility."""
        try:
            # Extract key information for camera parameter optimization
            camera_opt = nerf_result.get('camera_optimization', {})
            depth_analysis = nerf_result.get('depth_analysis', {})
            lighting_analysis = nerf_result.get('lighting_analysis', {})
            
            # Format in the expected structure for auto_adjustment_service.js
            formatted_result = {
                'nerf_analysis': {
                    'depth_map_available': 'depth_map' in nerf_result.get('scene_analysis', {}),
                    'scene_bounds': depth_analysis.get('depth_distribution', {}),
                    'focal_regions': nerf_result.get('scene_analysis', {}).get('focal_regions', []),
                    'lighting_3d': lighting_analysis.get('lighting_distribution', {}),
                    'processing_time': nerf_result.get('processing_time', 0)
                },
                
                'enhanced_recommendations': {
                    **camera_opt.get('exposure', {}),
                    **camera_opt.get('focus', {}),
                    **camera_opt.get('depth_of_field', {}),
                    **camera_opt.get('composition', {})
                },
                
                'advanced_metrics': {
                    'depth_complexity': depth_analysis.get('depth_complexity', 0),
                    'scene_3d_score': self._calculate_3d_score(nerf_result),
                    'composition_3d_score': nerf_result.get('composition_analysis', {}).get('composition_score', 0.5)
                }
            }
            
            return formatted_result
            
        except Exception as e:
            self.logger.error(f"Result formatting error: {e}")
            return {'error': 'Failed to format NeRF results'}
    
    def _calculate_3d_score(self, nerf_result: Dict) -> float:
        """Calculate overall 3D scene understanding quality score."""
        try:
            scores = []
            
            # Depth analysis quality
            depth_analysis = nerf_result.get('depth_analysis', {})
            if 'depth_complexity' in depth_analysis:
                scores.append(min(1.0, depth_analysis['depth_complexity'] / 10.0))
            
            # Focal regions quality
            focal_regions = nerf_result.get('scene_analysis', {}).get('focal_regions', [])
            if focal_regions:
                scores.append(focal_regions[0].get('focus_score', 0.5))
            
            # Composition quality
            composition_score = nerf_result.get('composition_analysis', {}).get('composition_score', 0.5)
            scores.append(composition_score)
            
            return np.mean(scores) if scores else 0.5
            
        except Exception:
            return 0.5

# CLI interface for NeRF service
def main():
    """Main CLI interface for NeRF service."""
    import argparse
    
    parser = argparse.ArgumentParser(description='NeRF Service for Camera Companion')
    parser.add_argument('--mode', choices=['serve', 'train', 'analyze'], default='serve',
                       help='Operation mode')
    parser.add_argument('--config', type=str, help='Config file path')
    parser.add_argument('--data-dir', type=str, help='Training data directory')
    parser.add_argument('--image', type=str, help='Image path for analysis')
    parser.add_argument('--host', default='0.0.0.0', help='Service host')
    parser.add_argument('--port', type=int, default=8001, help='Service port')
    
    args = parser.parse_args()
    
    # Load config
    if args.config:
        config = NeRFConfig.load(args.config)
    else:
        config = REAL_TIME_CONFIG
    
    if args.mode == 'serve':
        # Start service
        service = NeRFService(config)
        service.run(args.host, args.port)
        
    elif args.mode == 'train':
        if not args.data_dir:
            print("Data directory required for training")
            return
        
        trainer = NeRFTrainer(config, args.data_dir)
        trainer.train()
        
    elif args.mode == 'analyze':
        if not args.image:
            print("Image path required for analysis")
            return
        
        analyzer = CameraNeRFAnalyzer(config, CameraOptimizationConfig())
        result = analyzer.analyze_scene_3d(args.image)
        print(json.dumps(result, indent=2, default=str))

if __name__ == '__main__':
    main()