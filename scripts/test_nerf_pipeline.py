#!/usr/bin/env python3
"""
Test script for NeRF-based analysis pipeline
Tests the integration between NeRF service and camera companion backend
"""

import sys
import os
import json
import time
import requests
import tempfile
import logging
from pathlib import Path
from PIL import Image
import numpy as np

# Add AI directory to Python path
sys.path.append(str(Path(__file__).parent.parent / 'ai'))

try:
    from nerf.nerf_service import NeRFService
    from nerf.nerf_config import REAL_TIME_CONFIG
    from nerf.camera_nerf_analyzer import CameraNeRFAnalyzer, CameraOptimizationConfig
except ImportError as e:
    print(f"Failed to import NeRF modules: {e}")
    print("Make sure the AI dependencies are installed")
    sys.exit(1)

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class NeRFPipelineTest:
    def __init__(self):
        self.service_url = "http://localhost:8001"
        self.test_results = {}
        
    def create_test_image(self, width=800, height=600):
        """Create a simple test image for analysis."""
        # Create a synthetic scene with depth variation
        image = np.zeros((height, width, 3), dtype=np.uint8)
        
        # Add background (sky-like gradient)
        for y in range(height):
            intensity = int(200 - (y / height) * 50)
            image[y, :] = [intensity, intensity + 20, intensity + 40]
        
        # Add some "objects" at different depths
        # Foreground object (bright)
        cv2_available = True
        try:
            import cv2
        except ImportError:
            cv2_available = False
            logger.warning("OpenCV not available, creating simple test image")
        
        if cv2_available:
            # Draw circles to simulate subjects at different depths
            cv2.circle(image, (width//3, height//2), 60, (255, 200, 150), -1)  # Close subject
            cv2.circle(image, (2*width//3, height//3), 40, (200, 255, 200), -1)  # Mid-distance
            cv2.circle(image, (width//2, 3*height//4), 25, (150, 150, 255), -1)  # Far subject
        else:
            # Simple rectangles without OpenCV
            image[height//2-30:height//2+30, width//3-30:width//3+30] = [255, 200, 150]
            image[height//3-20:height//3+20, 2*width//3-20:2*width//3+20] = [200, 255, 200]
            image[3*height//4-15:3*height//4+15, width//2-15:width//2+15] = [150, 150, 255]
        
        return image
    
    def test_service_startup(self):
        """Test if NeRF service starts up correctly."""
        logger.info("Testing NeRF service startup...")
        
        try:
            # Check if service is already running
            response = requests.get(f"{self.service_url}/health", timeout=5)
            if response.status_code == 200:
                logger.info("NeRF service is already running")
                self.test_results['service_startup'] = True
                return True
        except requests.RequestException:
            logger.info("NeRF service not running, attempting to start...")
        
        # Try to start service programmatically
        try:
            service = NeRFService(REAL_TIME_CONFIG)
            # This would normally run the service, but we'll just test initialization
            logger.info("NeRF service initialized successfully")
            self.test_results['service_startup'] = True
            return True
        except Exception as e:
            logger.error(f"Failed to initialize NeRF service: {e}")
            self.test_results['service_startup'] = False
            return False
    
    def test_health_endpoint(self):
        """Test the health check endpoint."""
        logger.info("Testing health endpoint...")
        
        try:
            response = requests.get(f"{self.service_url}/health", timeout=10)
            if response.status_code == 200:
                health_data = response.json()
                logger.info(f"Health check passed: {health_data}")
                self.test_results['health_endpoint'] = True
                return True
            else:
                logger.error(f"Health check failed with status: {response.status_code}")
                self.test_results['health_endpoint'] = False
                return False
        except requests.RequestException as e:
            logger.error(f"Health check request failed: {e}")
            self.test_results['health_endpoint'] = False
            return False
    
    def test_image_analysis(self):
        """Test image analysis functionality."""
        logger.info("Testing image analysis...")
        
        # Create test image
        test_image = self.create_test_image()
        
        # Save to temporary file
        with tempfile.NamedTemporaryFile(suffix='.jpg', delete=False) as tmp_file:
            temp_path = tmp_file.name
            Image.fromarray(test_image).save(temp_path)
        
        try:
            # Test direct analysis
            analyzer = CameraNeRFAnalyzer(REAL_TIME_CONFIG, CameraOptimizationConfig())
            
            start_time = time.time()
            result = analyzer.analyze_scene_3d(temp_path)
            analysis_time = time.time() - start_time
            
            logger.info(f"Analysis completed in {analysis_time:.2f} seconds")
            logger.info(f"Analysis result keys: {list(result.keys())}")
            
            # Check if essential fields are present
            required_fields = ['analysis_type', 'processing_status']
            missing_fields = [field for field in required_fields if field not in result]
            
            if missing_fields:
                logger.error(f"Missing required fields: {missing_fields}")
                self.test_results['image_analysis'] = False
                return False
            
            if result.get('processing_status') == 'success':
                logger.info("Image analysis successful")
                self.test_results['image_analysis'] = True
                self.test_results['analysis_time'] = analysis_time
                return True
            else:
                logger.error(f"Analysis failed: {result.get('error', 'Unknown error')}")
                self.test_results['image_analysis'] = False
                return False
                
        except Exception as e:
            logger.error(f"Image analysis test failed: {e}")
            self.test_results['image_analysis'] = False
            return False
        finally:
            # Clean up temporary file
            try:
                os.unlink(temp_path)
            except:
                pass
    
    def test_api_endpoint(self):
        """Test the REST API endpoint."""
        logger.info("Testing API endpoint...")
        
        # Create test image
        test_image = self.create_test_image()
        
        # Save to temporary file
        with tempfile.NamedTemporaryFile(suffix='.jpg', delete=False) as tmp_file:
            temp_path = tmp_file.name
            Image.fromarray(test_image).save(temp_path)
        
        try:
            # Test file upload endpoint
            with open(temp_path, 'rb') as f:
                files = {'file': ('test_image.jpg', f, 'image/jpeg')}
                response = requests.post(
                    f"{self.service_url}/analyze/upload",
                    files=files,
                    timeout=30
                )
            
            if response.status_code == 200:
                result = response.json()
                logger.info("API endpoint test successful")
                logger.info(f"API response keys: {list(result.keys())}")
                self.test_results['api_endpoint'] = True
                return True
            else:
                logger.error(f"API endpoint failed with status: {response.status_code}")
                logger.error(f"Response: {response.text}")
                self.test_results['api_endpoint'] = False
                return False
                
        except requests.RequestException as e:
            logger.error(f"API endpoint request failed: {e}")
            self.test_results['api_endpoint'] = False
            return False
        finally:
            # Clean up temporary file
            try:
                os.unlink(temp_path)
            except:
                pass
    
    def test_integration_compatibility(self):
        """Test compatibility with backend integration."""
        logger.info("Testing backend integration compatibility...")
        
        try:
            # Import integration service
            sys.path.append(str(Path(__file__).parent.parent / 'backend' / 'src' / 'services'))
            
            # Test would normally import NeRFIntegrationService
            # For now, just test the configuration
            config_path = Path(__file__).parent.parent / 'config' / 'nerf_config.json'
            
            if config_path.exists():
                with open(config_path) as f:
                    config = json.load(f)
                
                # Check essential configuration fields
                required_sections = ['service', 'nerf', 'integration']
                missing_sections = [section for section in required_sections if section not in config]
                
                if missing_sections:
                    logger.error(f"Missing configuration sections: {missing_sections}")
                    self.test_results['integration_compatibility'] = False
                    return False
                
                logger.info("Configuration validation passed")
                self.test_results['integration_compatibility'] = True
                return True
            else:
                logger.error("Configuration file not found")
                self.test_results['integration_compatibility'] = False
                return False
                
        except Exception as e:
            logger.error(f"Integration compatibility test failed: {e}")
            self.test_results['integration_compatibility'] = False
            return False
    
    def test_performance(self):
        """Test performance characteristics."""
        logger.info("Testing performance...")
        
        # Create test image
        test_image = self.create_test_image()
        
        try:
            analyzer = CameraNeRFAnalyzer(REAL_TIME_CONFIG, CameraOptimizationConfig())
            
            # Run multiple analyses to get average performance
            times = []
            for i in range(3):
                with tempfile.NamedTemporaryFile(suffix='.jpg', delete=False) as tmp_file:
                    temp_path = tmp_file.name
                    Image.fromarray(test_image).save(temp_path)
                
                try:
                    start_time = time.time()
                    result = analyzer.analyze_scene_3d(temp_path)
                    analysis_time = time.time() - start_time
                    times.append(analysis_time)
                    
                    logger.info(f"Analysis {i+1}: {analysis_time:.2f}s")
                finally:
                    os.unlink(temp_path)
            
            avg_time = sum(times) / len(times)
            max_time = max(times)
            min_time = min(times)
            
            logger.info(f"Performance results - Avg: {avg_time:.2f}s, Min: {min_time:.2f}s, Max: {max_time:.2f}s")
            
            # Check if performance meets requirements (should be under 10 seconds for real-time config)
            if avg_time < 10.0:
                logger.info("Performance test passed")
                self.test_results['performance'] = True
                self.test_results['avg_analysis_time'] = avg_time
                return True
            else:
                logger.warning(f"Performance test failed - average time {avg_time:.2f}s exceeds 10s threshold")
                self.test_results['performance'] = False
                self.test_results['avg_analysis_time'] = avg_time
                return False
                
        except Exception as e:
            logger.error(f"Performance test failed: {e}")
            self.test_results['performance'] = False
            return False
    
    def run_all_tests(self):
        """Run all tests and generate report."""
        logger.info("Starting NeRF pipeline test suite...")
        
        tests = [
            ('Service Startup', self.test_service_startup),
            ('Image Analysis', self.test_image_analysis),
            ('Integration Compatibility', self.test_integration_compatibility),
            ('Performance', self.test_performance),
            # API and health tests require running service
            # ('Health Endpoint', self.test_health_endpoint),
            # ('API Endpoint', self.test_api_endpoint),
        ]
        
        results = {}
        for test_name, test_func in tests:
            logger.info(f"\n{'='*50}")
            logger.info(f"Running test: {test_name}")
            logger.info('='*50)
            
            try:
                success = test_func()
                results[test_name] = 'PASSED' if success else 'FAILED'
            except Exception as e:
                logger.error(f"Test {test_name} threw exception: {e}")
                results[test_name] = 'ERROR'
        
        # Generate report
        self.generate_report(results)
        return results
    
    def generate_report(self, results):
        """Generate a test report."""
        logger.info(f"\n{'='*60}")
        logger.info("NeRF PIPELINE TEST REPORT")
        logger.info('='*60)
        
        passed = sum(1 for status in results.values() if status == 'PASSED')
        failed = sum(1 for status in results.values() if status == 'FAILED')
        errors = sum(1 for status in results.values() if status == 'ERROR')
        total = len(results)
        
        logger.info(f"Total Tests: {total}")
        logger.info(f"Passed: {passed}")
        logger.info(f"Failed: {failed}")
        logger.info(f"Errors: {errors}")
        logger.info(f"Success Rate: {(passed/total)*100:.1f}%")
        
        logger.info("\nDetailed Results:")
        for test_name, status in results.items():
            status_symbol = "✓" if status == "PASSED" else "✗" if status == "FAILED" else "!"
            logger.info(f"  {status_symbol} {test_name}: {status}")
        
        # Additional metrics
        if 'avg_analysis_time' in self.test_results:
            logger.info(f"\nPerformance Metrics:")
            logger.info(f"  Average Analysis Time: {self.test_results['avg_analysis_time']:.2f}s")
        
        logger.info(f"\nTest completed at: {time.strftime('%Y-%m-%d %H:%M:%S')}")
        logger.info('='*60)

def main():
    """Main test function."""
    print("NeRF Pipeline Test Suite")
    print("This script tests the NeRF-based analysis pipeline integration")
    print()
    
    # Check Python version
    if sys.version_info < (3, 7):
        print("ERROR: Python 3.7 or higher is required")
        sys.exit(1)
    
    # Run tests
    tester = NeRFPipelineTest()
    results = tester.run_all_tests()
    
    # Exit with appropriate code
    failed_tests = sum(1 for status in results.values() if status in ['FAILED', 'ERROR'])
    sys.exit(failed_tests)

if __name__ == '__main__':
    main()