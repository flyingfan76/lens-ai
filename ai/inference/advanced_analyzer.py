#!/usr/bin/env python3

import sys
import json
import argparse
import logging
from pathlib import Path

# Add the parent directory to sys.path to import scene_analyzer
sys.path.append(str(Path(__file__).parent))

try:
    from scene_analyzer import SceneAnalyzer
    import cv2
    import numpy as np
except ImportError as e:
    logging.error(f"Failed to import required modules: {e}")
    # Fallback response
    fallback_result = {
        'scene_type': 'general',
        'scene_confidence': 0.5,
        'lighting_condition': 'normal',
        'lighting_confidence': 0.5,
        'brightness_level': 0.5,
        'contrast_level': 0.3,
        'has_faces': False,
        'face_count': 0,
        'face_regions': [],
        'dominant_colors': [[128, 128, 128]],
        'recommended_settings': {
            'iso': 400,
            'aperture': 'f/4.0',
            'shutter_speed': '1/125',
            'white_balance': 'auto',
            'focus_mode': 'single',
            'metering_mode': 'matrix'
        },
        'error': f'Import error: {str(e)}'
    }
    print(json.dumps(fallback_result))
    sys.exit(0)

class AdvancedAnalyzer:
    """
    Enhanced scene analyzer with advanced computer vision capabilities
    for optimal camera parameter adjustment.
    """
    
    def __init__(self):
        self.scene_analyzer = SceneAnalyzer()
        self.logger = logging.getLogger(__name__)
        
    def analyze_image_advanced(self, image_path: str, mode: str = 'auto') -> dict:
        """
        Perform advanced image analysis for camera parameter optimization.
        
        Args:
            image_path: Path to the image file
            mode: Analysis mode ('auto', 'portrait', 'landscape', etc.)
            
        Returns:
            Dictionary containing comprehensive analysis results
        """
        try:
            # Load image
            image = cv2.imread(image_path)
            if image is None:
                return self._get_error_result(f"Could not load image: {image_path}")
            
            # Basic scene analysis
            basic_analysis = self.scene_analyzer.analyze_scene(image)
            
            # Advanced analysis
            advanced_metrics = self._perform_advanced_analysis(image, mode)
            
            # Combine results
            result = {
                **basic_analysis,
                **advanced_metrics,
                'analysis_mode': mode,
                'image_dimensions': image.shape[:2],
                'processing_status': 'success'
            }
            
            return result
            
        except Exception as e:
            self.logger.error(f"Advanced analysis failed: {e}")
            return self._get_error_result(str(e))
    
    def _perform_advanced_analysis(self, image: np.ndarray, mode: str) -> dict:
        """Perform additional advanced analysis."""
        try:
            # Histogram analysis
            histogram_analysis = self._analyze_histogram(image)
            
            # Exposure analysis
            exposure_analysis = self._analyze_exposure(image)
            
            # Focus quality analysis
            focus_analysis = self._analyze_focus_quality(image)
            
            # Noise analysis
            noise_analysis = self._analyze_noise(image)
            
            # Motion analysis
            motion_analysis = self._analyze_motion(image)
            
            # Color analysis
            color_analysis = self._analyze_color_distribution(image)
            
            return {
                'histogram_analysis': histogram_analysis,
                'exposure_analysis': exposure_analysis,
                'focus_analysis': focus_analysis,
                'noise_analysis': noise_analysis,
                'motion_analysis': motion_analysis,
                'color_analysis': color_analysis,
                'advanced_recommendations': self._generate_advanced_recommendations(
                    histogram_analysis, exposure_analysis, focus_analysis, mode
                )
            }
            
        except Exception as e:
            self.logger.error(f"Advanced analysis metrics failed: {e}")
            return {
                'histogram_analysis': {},
                'exposure_analysis': {},
                'focus_analysis': {},
                'error': str(e)
            }
    
    def _analyze_histogram(self, image: np.ndarray) -> dict:
        """Analyze image histogram for exposure optimization."""
        try:
            # Convert to different color spaces for comprehensive analysis
            rgb_image = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
            gray_image = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
            
            # Calculate histograms
            hist_r = cv2.calcHist([rgb_image], [0], None, [256], [0, 256])
            hist_g = cv2.calcHist([rgb_image], [1], None, [256], [0, 256])
            hist_b = cv2.calcHist([rgb_image], [2], None, [256], [0, 256])
            hist_gray = cv2.calcHist([gray_image], [0], None, [256], [0, 256])
            
            # Histogram statistics
            return {
                'red_distribution': {
                    'mean': float(np.mean(hist_r)),
                    'std': float(np.std(hist_r)),
                    'peak': int(np.argmax(hist_r))
                },
                'green_distribution': {
                    'mean': float(np.mean(hist_g)),
                    'std': float(np.std(hist_g)),
                    'peak': int(np.argmax(hist_g))
                },
                'blue_distribution': {
                    'mean': float(np.mean(hist_b)),
                    'std': float(np.std(hist_b)),
                    'peak': int(np.argmax(hist_b))
                },
                'luminance_distribution': {
                    'mean': float(np.mean(hist_gray)),
                    'std': float(np.std(hist_gray)),
                    'peak': int(np.argmax(hist_gray))
                },
                'dynamic_range': float(np.max(gray_image) - np.min(gray_image)),
                'contrast_ratio': float(np.std(gray_image) / np.mean(gray_image)) if np.mean(gray_image) > 0 else 0
            }
            
        except Exception as e:
            return {'error': str(e)}
    
    def _analyze_exposure(self, image: np.ndarray) -> dict:
        """Analyze exposure characteristics."""
        try:
            gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
            height, width = gray.shape
            total_pixels = height * width
            
            # Define exposure zones
            underexposed = np.sum(gray < 50) / total_pixels
            well_exposed = np.sum((gray >= 50) & (gray <= 200)) / total_pixels
            overexposed = np.sum(gray > 200) / total_pixels
            
            # Highlight and shadow clipping
            highlight_clipping = np.sum(gray > 240) / total_pixels
            shadow_clipping = np.sum(gray < 15) / total_pixels
            
            # Average brightness
            avg_brightness = float(np.mean(gray)) / 255.0
            
            return {
                'underexposed_ratio': float(underexposed),
                'well_exposed_ratio': float(well_exposed),
                'overexposed_ratio': float(overexposed),
                'highlight_clipping': float(highlight_clipping),
                'shadow_clipping': float(shadow_clipping),
                'average_brightness': avg_brightness,
                'exposure_quality': 'good' if well_exposed > 0.7 else 'poor'
            }
            
        except Exception as e:
            return {'error': str(e)}
    
    def _analyze_focus_quality(self, image: np.ndarray) -> dict:
        """Analyze focus quality and sharpness."""
        try:
            gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
            
            # Laplacian variance (focus measure)
            laplacian_var = cv2.Laplacian(gray, cv2.CV_64F).var()
            
            # Sobel gradients
            sobelx = cv2.Sobel(gray, cv2.CV_64F, 1, 0, ksize=3)
            sobely = cv2.Sobel(gray, cv2.CV_64F, 0, 1, ksize=3)
            sobel_magnitude = np.sqrt(sobelx**2 + sobely**2)
            
            # Edge density
            edges = cv2.Canny(gray, 50, 150)
            edge_density = np.sum(edges > 0) / (gray.shape[0] * gray.shape[1])
            
            return {
                'laplacian_variance': float(laplacian_var),
                'edge_density': float(edge_density),
                'sobel_mean': float(np.mean(sobel_magnitude)),
                'focus_score': min(1.0, float(laplacian_var) / 1000.0),  # Normalized
                'sharpness_quality': 'sharp' if laplacian_var > 100 else 'soft'
            }
            
        except Exception as e:
            return {'error': str(e)}
    
    def _analyze_noise(self, image: np.ndarray) -> dict:
        """Analyze image noise characteristics."""
        try:
            gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
            
            # Estimate noise using standard deviation of Laplacian
            laplacian = cv2.Laplacian(gray, cv2.CV_64F)
            noise_estimate = np.std(laplacian)
            
            # Signal-to-noise ratio estimate
            signal_power = np.mean(gray**2)
            noise_power = noise_estimate**2
            snr = 10 * np.log10(signal_power / noise_power) if noise_power > 0 else 50
            
            return {
                'noise_estimate': float(noise_estimate),
                'signal_to_noise_ratio': float(snr),
                'noise_level': 'low' if noise_estimate < 10 else 'medium' if noise_estimate < 20 else 'high'
            }
            
        except Exception as e:
            return {'error': str(e)}
    
    def _analyze_motion(self, image: np.ndarray) -> dict:
        """Analyze potential motion blur."""
        try:
            gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
            
            # Motion blur detection using spectral analysis
            f_transform = np.fft.fft2(gray)
            f_shift = np.fft.fftshift(f_transform)
            magnitude_spectrum = np.log(np.abs(f_shift) + 1)
            
            # Analyze frequency distribution
            center_y, center_x = np.array(magnitude_spectrum.shape) // 2
            high_freq_energy = np.sum(magnitude_spectrum[center_y-20:center_y+20, center_x-20:center_x+20])
            total_energy = np.sum(magnitude_spectrum)
            
            motion_score = 1.0 - (high_freq_energy / total_energy) if total_energy > 0 else 0
            
            return {
                'motion_blur_score': float(motion_score),
                'high_frequency_ratio': float(high_freq_energy / total_energy) if total_energy > 0 else 0,
                'motion_detected': motion_score > 0.7
            }
            
        except Exception as e:
            return {'error': str(e)}
    
    def _analyze_color_distribution(self, image: np.ndarray) -> dict:
        """Analyze color distribution and temperature."""
        try:
            rgb_image = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
            
            # Color temperature estimation (simplified)
            r_mean = np.mean(rgb_image[:, :, 0])
            g_mean = np.mean(rgb_image[:, :, 1])
            b_mean = np.mean(rgb_image[:, :, 2])
            
            # Color cast detection
            rb_ratio = r_mean / b_mean if b_mean > 0 else 1
            color_temperature_estimate = 6500 / rb_ratio if rb_ratio > 0 else 6500  # Rough estimation
            
            # Saturation analysis
            hsv_image = cv2.cvtColor(image, cv2.COLOR_BGR2HSV)
            saturation_mean = np.mean(hsv_image[:, :, 1])
            
            return {
                'red_average': float(r_mean),
                'green_average': float(g_mean),
                'blue_average': float(b_mean),
                'color_temperature_estimate': float(color_temperature_estimate),
                'saturation_level': float(saturation_mean / 255.0),
                'color_cast': 'warm' if rb_ratio > 1.1 else 'cool' if rb_ratio < 0.9 else 'neutral'
            }
            
        except Exception as e:
            return {'error': str(e)}
    
    def _generate_advanced_recommendations(self, histogram, exposure, focus, mode):
        """Generate advanced camera setting recommendations."""
        try:
            recommendations = {}
            
            # ISO recommendations based on noise analysis
            if exposure.get('underexposed_ratio', 0) > 0.3:
                recommendations['iso_adjustment'] = 'increase'
                recommendations['iso_reason'] = 'Image is underexposed'
            elif exposure.get('overexposed_ratio', 0) > 0.2:
                recommendations['iso_adjustment'] = 'decrease'
                recommendations['iso_reason'] = 'Image is overexposed'
            
            # Aperture recommendations based on focus analysis
            if focus.get('focus_score', 0) < 0.3:
                recommendations['aperture_adjustment'] = 'stop_down'
                recommendations['aperture_reason'] = 'Increase depth of field for better sharpness'
            
            # Shutter speed recommendations
            if focus.get('laplacian_variance', 0) < 50:
                recommendations['shutter_adjustment'] = 'increase'
                recommendations['shutter_reason'] = 'Prevent motion blur'
            
            return recommendations
            
        except Exception as e:
            return {'error': str(e)}
    
    def _get_error_result(self, error_msg: str) -> dict:
        """Return a standardized error result."""
        return {
            'scene_type': 'general',
            'scene_confidence': 0.5,
            'lighting_condition': 'normal',
            'lighting_confidence': 0.5,
            'brightness_level': 0.5,
            'contrast_level': 0.3,
            'has_faces': False,
            'face_count': 0,
            'face_regions': [],
            'dominant_colors': [[128, 128, 128]],
            'recommended_settings': {
                'iso': 400,
                'aperture': 'f/4.0',
                'shutter_speed': '1/125',
                'white_balance': 'auto',
                'focus_mode': 'single',
                'metering_mode': 'matrix'
            },
            'error': error_msg,
            'processing_status': 'error'
        }

def main():
    """Main function for command-line usage."""
    parser = argparse.ArgumentParser(description='Advanced Image Analysis for Camera Settings')
    parser.add_argument('image_path', nargs='?', help='Path to image file')
    parser.add_argument('--mode', default='auto', help='Analysis mode')
    parser.add_argument('--detailed', action='store_true', help='Enable detailed analysis')
    
    args = parser.parse_args()
    
    # Set up logging
    logging.basicConfig(level=logging.WARNING)
    
    try:
        analyzer = AdvancedAnalyzer()
        
        if args.image_path:
            # Analyze provided image file
            result = analyzer.analyze_image_advanced(args.image_path, args.mode)
        else:
            # Try to read image data from stdin (for integration with Node.js)
            import tempfile
            import os
            
            # Read binary data from stdin
            image_data = sys.stdin.buffer.read()
            
            if len(image_data) > 0:
                # Save to temporary file
                with tempfile.NamedTemporaryFile(suffix='.jpg', delete=False) as tmp_file:
                    tmp_file.write(image_data)
                    tmp_path = tmp_file.name
                
                try:
                    result = analyzer.analyze_image_advanced(tmp_path, args.mode)
                finally:
                    # Clean up temporary file
                    try:
                        os.unlink(tmp_path)
                    except:
                        pass
            else:
                result = analyzer._get_error_result("No image data provided")
        
        # Output JSON result
        print(json.dumps(result, ensure_ascii=False))
        
    except Exception as e:
        error_result = {
            'error': str(e),
            'scene_type': 'general',
            'scene_confidence': 0.5,
            'lighting_condition': 'normal',
            'lighting_confidence': 0.5,
            'processing_status': 'error'
        }
        print(json.dumps(error_result))
        sys.exit(1)

if __name__ == '__main__':
    main()