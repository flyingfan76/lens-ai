class ApiConfig {
  static const String baseUrl = 'http://localhost:3000/api';
  static const int timeoutDuration = 30000; // 30 seconds
  
  // AI Service endpoints
  static const String aiSuggestionsEndpoint = '/ai-suggestions';
  static const String presetsEndpoint = '/presets';
  static const String cameraEndpoint = '/camera';
  
  // Request headers
  static const Map<String, String> defaultHeaders = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };
}