import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'encryption_service.dart';
import 'privacy_protection.dart';
import 'authentication_service.dart';
import 'security_monitor.dart';

/// Central security management system for Lens AI
/// Provides comprehensive security features including encryption, privacy protection,
/// authentication, and security monitoring
class SecurityManager {
  static final SecurityManager _instance = SecurityManager._internal();
  factory SecurityManager() => _instance;
  SecurityManager._internal();

  late EncryptionService _encryptionService;
  late PrivacyProtection _privacyProtection;
  late AuthenticationService _authService;
  late SecurityMonitor _securityMonitor;

  bool _isInitialized = false;
  SecurityConfig _config = SecurityConfig.standard();

  /// Initialize the security system
  Future<void> initialize({SecurityConfig? config}) async {
    if (_isInitialized) return;

    _config = config ?? SecurityConfig.standard();
    
    _encryptionService = EncryptionService();
    await _encryptionService.initialize(_config.encryptionConfig);

    _privacyProtection = PrivacyProtection();
    await _privacyProtection.initialize(_config.privacyConfig);

    _authService = AuthenticationService();
    await _authService.initialize(_config.authConfig);

    _securityMonitor = SecurityMonitor();
    await _securityMonitor.initialize(_config.monitoringConfig);

    _isInitialized = true;
  }

  /// Get encryption service
  EncryptionService get encryption => _encryptionService;

  /// Get privacy protection service
  PrivacyProtection get privacy => _privacyProtection;

  /// Get authentication service
  AuthenticationService get authentication => _authService;

  /// Get security monitoring service
  SecurityMonitor get monitor => _securityMonitor;

  /// Encrypt and store sensitive data
  Future<bool> storeSecureData(String key, Uint8List data) async {
    try {
      final encryptedData = await _encryptionService.encrypt(data);
      return await _encryptionService.storeEncrypted(key, encryptedData);
    } catch (e) {
      await _securityMonitor.reportSecurityEvent(
        SecurityEventType.encryptionError,
        {'error': e.toString(), 'key': key},
      );
      return false;
    }
  }

  /// Retrieve and decrypt sensitive data
  Future<Uint8List?> retrieveSecureData(String key) async {
    try {
      final encryptedData = await _encryptionService.retrieveEncrypted(key);
      if (encryptedData == null) return null;
      return await _encryptionService.decrypt(encryptedData);
    } catch (e) {
      await _securityMonitor.reportSecurityEvent(
        SecurityEventType.decryptionError,
        {'error': e.toString(), 'key': key},
      );
      return null;
    }
  }

  /// Secure photo with privacy protection
  Future<SecurePhoto> securePhoto(Uint8List photoData, PhotoMetadata metadata) async {
    // Apply privacy protection
    final protectedPhoto = await _privacyProtection.protectPhoto(photoData, metadata);
    
    // Encrypt the photo
    final encryptedPhoto = await _encryptionService.encrypt(protectedPhoto.photoData);
    final encryptedMetadata = await _encryptionService.encryptString(
      jsonEncode(protectedPhoto.metadata.toMap()),
    );

    return SecurePhoto(
      encryptedPhoto: encryptedPhoto,
      encryptedMetadata: encryptedMetadata,
      protectionLevel: protectedPhoto.protectionLevel,
      timestamp: DateTime.now(),
    );
  }

  /// Retrieve secure photo
  Future<ProtectedPhoto?> retrieveSecurePhoto(SecurePhoto securePhoto) async {
    try {
      final photoData = await _encryptionService.decrypt(securePhoto.encryptedPhoto);
      final metadataJson = await _encryptionService.decryptString(securePhoto.encryptedMetadata);
      final metadata = PhotoMetadata.fromMap(jsonDecode(metadataJson));

      return ProtectedPhoto(
        photoData: photoData,
        metadata: metadata,
        protectionLevel: securePhoto.protectionLevel,
      );
    } catch (e) {
      await _securityMonitor.reportSecurityEvent(
        SecurityEventType.photoRetrievalError,
        {'error': e.toString()},
      );
      return null;
    }
  }

  /// Check if app is locked
  bool get isAppLocked => _authService.isLocked;

  /// Lock the app
  Future<void> lockApp() async {
    await _authService.lockApp();
    await _securityMonitor.reportSecurityEvent(
      SecurityEventType.appLocked,
      {'timestamp': DateTime.now().toIso8601String()},
    );
  }

  /// Attempt to unlock the app
  Future<bool> unlockApp() async {
    final result = await _authService.authenticate();
    await _securityMonitor.reportSecurityEvent(
      SecurityEventType.unlockAttempt,
      {'success': result, 'timestamp': DateTime.now().toIso8601String()},
    );
    return result;
  }

  /// Get security status
  SecurityStatus getSecurityStatus() {
    return SecurityStatus(
      encryptionEnabled: _encryptionService.isEnabled,
      privacyProtectionActive: _privacyProtection.isActive,
      authenticationRequired: _authService.isAuthRequired,
      monitoringActive: _securityMonitor.isActive,
      threatLevel: _securityMonitor.currentThreatLevel,
      lastSecurityCheck: DateTime.now(),
    );
  }

  /// Configure security settings
  Future<void> updateSecurityConfig(SecurityConfig newConfig) async {
    _config = newConfig;
    
    await _encryptionService.updateConfig(newConfig.encryptionConfig);
    await _privacyProtection.updateConfig(newConfig.privacyConfig);
    await _authService.updateConfig(newConfig.authConfig);
    await _securityMonitor.updateConfig(newConfig.monitoringConfig);
  }

  /// Dispose resources
  Future<void> dispose() async {
    await _encryptionService.dispose();
    await _privacyProtection.dispose();
    await _authService.dispose();
    await _securityMonitor.dispose();
    _isInitialized = false;
  }
}

/// Security configuration class
class SecurityConfig {
  final EncryptionConfig encryptionConfig;
  final PrivacyConfig privacyConfig;
  final AuthConfig authConfig;
  final MonitoringConfig monitoringConfig;

  SecurityConfig({
    required this.encryptionConfig,
    required this.privacyConfig,
    required this.authConfig,
    required this.monitoringConfig,
  });

  factory SecurityConfig.standard() {
    return SecurityConfig(
      encryptionConfig: EncryptionConfig.standard(),
      privacyConfig: PrivacyConfig.standard(),
      authConfig: AuthConfig.standard(),
      monitoringConfig: MonitoringConfig.standard(),
    );
  }

  factory SecurityConfig.highSecurity() {
    return SecurityConfig(
      encryptionConfig: EncryptionConfig.highSecurity(),
      privacyConfig: PrivacyConfig.maximum(),
      authConfig: AuthConfig.strict(),
      monitoringConfig: MonitoringConfig.comprehensive(),
    );
  }
}

/// Security status information
class SecurityStatus {
  final bool encryptionEnabled;
  final bool privacyProtectionActive;
  final bool authenticationRequired;
  final bool monitoringActive;
  final ThreatLevel threatLevel;
  final DateTime lastSecurityCheck;

  SecurityStatus({
    required this.encryptionEnabled,
    required this.privacyProtectionActive,
    required this.authenticationRequired,
    required this.monitoringActive,
    required this.threatLevel,
    required this.lastSecurityCheck,
  });
}

/// Secure photo container
class SecurePhoto {
  final Uint8List encryptedPhoto;
  final String encryptedMetadata;
  final PrivacyProtectionLevel protectionLevel;
  final DateTime timestamp;

  SecurePhoto({
    required this.encryptedPhoto,
    required this.encryptedMetadata,
    required this.protectionLevel,
    required this.timestamp,
  });
}

/// Security event types for monitoring
enum SecurityEventType {
  encryptionError,
  decryptionError,
  photoRetrievalError,
  appLocked,
  unlockAttempt,
  authenticationFailure,
  privacyViolation,
  integrityCheckFailed,
  suspiciousActivity,
  configurationChange,
}

/// Threat levels
enum ThreatLevel {
  none,
  low,
  medium,
  high,
  critical,
}