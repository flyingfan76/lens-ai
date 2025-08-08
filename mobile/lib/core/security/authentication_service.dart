/// Authentication service for secure app access
class AuthenticationService {
  late AuthConfig _config;
  bool _isInitialized = false;
  bool _isLocked = false;

  Future<void> initialize(AuthConfig config) async {
    _config = config;
    _isInitialized = true;
    _isLocked = config.requireAuthOnStartup;
  }

  bool get isAuthRequired => _config.requireAuthentication;
  bool get isInitialized => _isInitialized;
  bool get isLocked => _isLocked;

  Future<bool> authenticate() async {
    // Mock implementation - replace with actual biometric authentication
    await Future.delayed(Duration(milliseconds: 500));
    _isLocked = false;
    return true;
  }

  Future<void> lockApp() async {
    _isLocked = true;
  }

  Future<void> updateConfig(AuthConfig newConfig) async {
    _config = newConfig;
  }

  Future<void> dispose() async {
    _isInitialized = false;
  }
}

class AuthConfig {
  final bool requireAuthentication;
  final bool requireAuthOnStartup;
  final bool useBiometric;

  AuthConfig({
    required this.requireAuthentication,
    required this.requireAuthOnStartup,
    required this.useBiometric,
  });

  factory AuthConfig.standard() {
    return AuthConfig(
      requireAuthentication: false,
      requireAuthOnStartup: false,
      useBiometric: true,
    );
  }

  factory AuthConfig.strict() {
    return AuthConfig(
      requireAuthentication: true,
      requireAuthOnStartup: true,
      useBiometric: true,
    );
  }
}