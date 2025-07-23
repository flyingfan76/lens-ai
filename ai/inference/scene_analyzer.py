import cv2
import numpy as np
import tensorflow as tf
from typing import Dict, List, Tuple, Optional
import logging

logger = logging.getLogger(__name__)

class SceneAnalyzer:
    """
    AI-powered scene analysis for optimal camera settings recommendation.
    Analyzes image content to determine scene type, lighting conditions, and subjects.
    """
    
    def __init__(self, model_path: Optional[str] = None):
        self.model_path = model_path or "models/scene_classifier.tflite"
        self.interpreter = None
        self.input_details = None
        self.output_details = None
        self.scene_classes = [
            'portrait', 'landscape', 'macro', 'street', 'architecture',
            'nature', 'sports', 'low_light', 'backlight', 'sunset'
        ]
        self.lighting_classes = ['bright', 'normal', 'dim', 'very_dark']
        
        self._load_model()
    
    def _load_model(self):
        """Load TensorFlow Lite model for inference."""
        try:
            self.interpreter = tf.lite.Interpreter(model_path=self.model_path)
            self.interpreter.allocate_tensors()
            
            self.input_details = self.interpreter.get_input_details()
            self.output_details = self.interpreter.get_output_details()
            
            logger.info(f"Scene analyzer model loaded: {self.model_path}")
        except Exception as e:
            logger.error(f"Failed to load scene analyzer model: {e}")
            # Use fallback rule-based analysis
            self.interpreter = None
    
    def analyze_scene(self, image: np.ndarray) -> Dict:
        """
        Analyze image to determine scene type and characteristics.
        
        Args:
            image: Input image as numpy array (BGR format from OpenCV)
            
        Returns:
            Dictionary containing scene analysis results
        """
        try:
            # Convert BGR to RGB
            rgb_image = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
            
            # Get basic image statistics
            brightness = self._analyze_brightness(rgb_image)
            contrast = self._analyze_contrast(rgb_image)
            dominant_colors = self._analyze_colors(rgb_image)
            
            # AI-based scene classification if model is available
            if self.interpreter:
                scene_prediction = self._predict_scene(rgb_image)
                lighting_prediction = self._predict_lighting(rgb_image)
            else:
                # Fallback to rule-based analysis
                scene_prediction = self._rule_based_scene_analysis(rgb_image)
                lighting_prediction = self._categorize_lighting(brightness)
            
            # Detect faces for portrait mode
            faces = self._detect_faces(rgb_image)
            
            return {
                'scene_type': scene_prediction['class'],
                'scene_confidence': scene_prediction['confidence'],
                'lighting_condition': lighting_prediction['class'],
                'lighting_confidence': lighting_prediction['confidence'],
                'brightness_level': brightness,
                'contrast_level': contrast,
                'has_faces': len(faces) > 0,
                'face_count': len(faces),
                'face_regions': faces,
                'dominant_colors': dominant_colors,
                'recommended_settings': self._generate_recommendations(
                    scene_prediction['class'], 
                    lighting_prediction['class'],
                    len(faces) > 0
                )
            }
            
        except Exception as e:
            logger.error(f"Scene analysis failed: {e}")
            return self._get_default_analysis()
    
    def _analyze_brightness(self, image: np.ndarray) -> float:
        """Calculate average brightness of the image."""
        gray = cv2.cvtColor(image, cv2.COLOR_RGB2GRAY)
        return np.mean(gray) / 255.0
    
    def _analyze_contrast(self, image: np.ndarray) -> float:
        """Calculate contrast level of the image."""
        gray = cv2.cvtColor(image, cv2.COLOR_RGB2GRAY)
        return np.std(gray) / 255.0
    
    def _analyze_colors(self, image: np.ndarray) -> List[Tuple[int, int, int]]:
        """Extract dominant colors from the image."""
        # Reshape image to be a list of pixels
        pixels = image.reshape(-1, 3)
        
        # Use k-means clustering to find dominant colors
        # For simplicity, just return the mean color for now
        mean_color = np.mean(pixels, axis=0).astype(int)
        return [tuple(mean_color)]
    
    def _predict_scene(self, image: np.ndarray) -> Dict:
        """Use AI model to predict scene type."""
        try:
            # Preprocess image for model input
            input_size = self.input_details[0]['shape'][1:3]  # Get height, width
            resized = cv2.resize(image, input_size)
            normalized = resized.astype(np.float32) / 255.0
            input_data = np.expand_dims(normalized, axis=0)
            
            # Run inference
            self.interpreter.set_tensor(self.input_details[0]['index'], input_data)
            self.interpreter.invoke()
            
            # Get output
            output_data = self.interpreter.get_tensor(self.output_details[0]['index'])
            predictions = output_data[0]
            
            # Get top prediction
            max_idx = np.argmax(predictions)
            confidence = float(predictions[max_idx])
            
            return {
                'class': self.scene_classes[max_idx],
                'confidence': confidence
            }
            
        except Exception as e:
            logger.error(f"Scene prediction failed: {e}")
            return {'class': 'general', 'confidence': 0.5}
    
    def _predict_lighting(self, image: np.ndarray) -> Dict:
        """Predict lighting conditions."""
        brightness = self._analyze_brightness(image)
        return self._categorize_lighting(brightness)
    
    def _categorize_lighting(self, brightness: float) -> Dict:
        """Categorize lighting based on brightness level."""
        if brightness > 0.7:
            return {'class': 'bright', 'confidence': 0.9}
        elif brightness > 0.4:
            return {'class': 'normal', 'confidence': 0.8}
        elif brightness > 0.2:
            return {'class': 'dim', 'confidence': 0.8}
        else:
            return {'class': 'very_dark', 'confidence': 0.9}
    
    def _rule_based_scene_analysis(self, image: np.ndarray) -> Dict:
        """Fallback rule-based scene analysis when AI model is not available."""
        height, width = image.shape[:2]
        
        # Simple heuristics based on image characteristics
        brightness = self._analyze_brightness(image)
        contrast = self._analyze_contrast(image)
        
        # Check for faces
        faces = self._detect_faces(image)
        if len(faces) > 0:
            return {'class': 'portrait', 'confidence': 0.7}
        
        # Check for low light
        if brightness < 0.3:
            return {'class': 'low_light', 'confidence': 0.8}
        
        # Check for high contrast (possible architecture/street)
        if contrast > 0.4:
            return {'class': 'architecture', 'confidence': 0.6}
        
        # Default to landscape
        return {'class': 'landscape', 'confidence': 0.5}
    
    def _detect_faces(self, image: np.ndarray) -> List[Tuple[int, int, int, int]]:
        """Detect faces in the image using OpenCV."""
        try:
            # Load face cascade classifier
            face_cascade = cv2.CascadeClassifier(
                cv2.data.haarcascades + 'haarcascade_frontalface_default.xml'
            )
            
            gray = cv2.cvtColor(image, cv2.COLOR_RGB2GRAY)
            faces = face_cascade.detectMultiScale(gray, 1.1, 4)
            
            return [tuple(face) for face in faces]
            
        except Exception as e:
            logger.error(f"Face detection failed: {e}")
            return []
    
    def _generate_recommendations(self, scene_type: str, lighting: str, has_faces: bool) -> Dict:
        """Generate camera setting recommendations based on analysis."""
        recommendations = {
            'iso': 400,
            'aperture': 'f/4.0',
            'shutter_speed': '1/125',
            'white_balance': 'auto',
            'focus_mode': 'single',
            'metering_mode': 'matrix'
        }
        
        # Adjust based on scene type
        if scene_type == 'portrait':
            recommendations.update({
                'aperture': 'f/2.8',
                'iso': 200,
                'focus_mode': 'single',
                'metering_mode': 'spot'
            })
        elif scene_type == 'landscape':
            recommendations.update({
                'aperture': 'f/8.0',
                'iso': 100,
                'focus_mode': 'hyperfocal'
            })
        elif scene_type == 'macro':
            recommendations.update({
                'aperture': 'f/5.6',
                'shutter_speed': '1/250',
                'focus_mode': 'manual'
            })
        elif scene_type == 'sports':
            recommendations.update({
                'shutter_speed': '1/500',
                'iso': 800,
                'focus_mode': 'continuous'
            })
        
        # Adjust based on lighting
        if lighting == 'very_dark' or lighting == 'dim':
            current_iso = int(recommendations['iso'])
            recommendations['iso'] = min(current_iso * 2, 1600)
            
        elif lighting == 'bright':
            recommendations['iso'] = 100
            
        return recommendations
    
    def _get_default_analysis(self) -> Dict:
        """Return default analysis when processing fails."""
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
            'dominant_colors': [(128, 128, 128)],
            'recommended_settings': {
                'iso': 400,
                'aperture': 'f/4.0',
                'shutter_speed': '1/125',
                'white_balance': 'auto',
                'focus_mode': 'single',
                'metering_mode': 'matrix'
            }
        }