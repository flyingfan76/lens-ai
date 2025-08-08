# AI Models Directory

This directory contains TensorFlow Lite models for local AI processing.

## Models

### scene_analysis.tflite
- **Purpose**: Analyzes camera scenes for AI suggestions
- **Input**: Image features (brightness, contrast, color temperature, etc.)
- **Output**: Confidence scores for different photography suggestions
- **Size**: ~2MB (placeholder - actual model would be generated from training)

## Model Integration

The models are loaded by `AIService` for offline AI processing:

```dart
_interpreter = await Interpreter.fromAsset('assets/models/scene_analysis.tflite');
```

## Development Notes

- Currently using mock/placeholder models for development
- Production models would be trained on photography datasets
- Models optimized for mobile inference with TensorFlow Lite
- No network dependency - all AI processing happens locally

## Future Models

- Face detection model for portrait suggestions
- Object detection for composition advice
- Style transfer for creative effects
- Low-light enhancement recommendations