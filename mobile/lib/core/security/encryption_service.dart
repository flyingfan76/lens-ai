import 'dart:typed_data';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

/// Advanced encryption service providing AES-256 and ChaCha20-Poly1305 encryption
/// for protecting sensitive data in the Lens AI application
class EncryptionService {
  static const String _keyPrefix = 'lens_ai_encrypted_';
  static const int _keySize = 32; // 256 bits
  static const int _nonceSize = 12; // 96 bits for GCM
  static const int _tagSize = 16; // 128 bits

  late EncryptionConfig _config;
  late Uint8List _masterKey;
  bool _isInitialized = false;

  /// Initialize the encryption service
  Future<void> initialize(EncryptionConfig config) async {
    _config = config;
    await _generateOrLoadMasterKey();
    _isInitialized = true;
  }

  /// Check if encryption is enabled
  bool get isEnabled => _isInitialized && _config.encryptionEnabled;

  /// Encrypt data using AES-256-GCM
  Future<EncryptedData> encrypt(Uint8List data) async {
    if (!isEnabled) throw SecurityException('Encryption not enabled');

    try {
      // Generate random nonce
      final nonce = _generateRandomBytes(_nonceSize);
      
      // Derive key using PBKDF2 with random salt
      final salt = _generateRandomBytes(16);
      final key = await _deriveKey(_masterKey, salt);

      // Encrypt using platform-specific implementation
      final encryptedData = await _performEncryption(data, key, nonce);
      
      return EncryptedData(
        data: encryptedData,
        nonce: nonce,
        salt: salt,
        algorithm: _config.algorithm,
        timestamp: DateTime.now(),
      );
    } catch (e) {
      throw SecurityException('Encryption failed: $e');
    }
  }

  /// Decrypt data
  Future<Uint8List> decrypt(EncryptedData encryptedData) async {
    if (!isEnabled) throw SecurityException('Encryption not enabled');

    try {
      // Derive key using stored salt
      final key = await _deriveKey(_masterKey, encryptedData.salt);

      // Decrypt using platform-specific implementation
      return await _performDecryption(
        encryptedData.data,
        key,
        encryptedData.nonce,
      );
    } catch (e) {
      throw SecurityException('Decryption failed: $e');
    }
  }

  /// Encrypt string data
  Future<String> encryptString(String plaintext) async {
    final data = Uint8List.fromList(utf8.encode(plaintext));
    final encrypted = await encrypt(data);
    return base64Encode(encrypted.toBytes());
  }

  /// Decrypt string data
  Future<String> decryptString(String encryptedString) async {
    final encryptedBytes = base64Decode(encryptedString);
    final encryptedData = EncryptedData.fromBytes(encryptedBytes);
    final decrypted = await decrypt(encryptedData);
    return utf8.decode(decrypted);
  }

  /// Store encrypted data in secure storage
  Future<bool> storeEncrypted(String key, EncryptedData data) async {
    try {
      if (_config.useSecureStorage) {
        // Store in secure file system
        final file = await _getSecureFile(key);
        await file.writeAsBytes(data.toBytes());
      } else {
        // Store in shared preferences
        final prefs = await SharedPreferences.getInstance();
        final encodedData = base64Encode(data.toBytes());
        await prefs.setString('$_keyPrefix$key', encodedData);
      }
      return true;
    } catch (e) {
      debugPrint('Storage error: $e');
      return false;
    }
  }

  /// Retrieve encrypted data from secure storage
  Future<EncryptedData?> retrieveEncrypted(String key) async {
    try {
      Uint8List? bytes;
      
      if (_config.useSecureStorage) {
        // Retrieve from secure file system
        final file = await _getSecureFile(key);
        if (await file.exists()) {
          bytes = await file.readAsBytes();
        }
      } else {
        // Retrieve from shared preferences
        final prefs = await SharedPreferences.getInstance();
        final encodedData = prefs.getString('$_keyPrefix$key');
        if (encodedData != null) {
          bytes = base64Decode(encodedData);
        }
      }

      return bytes != null ? EncryptedData.fromBytes(bytes) : null;
    } catch (e) {
      debugPrint('Retrieval error: $e');
      return null;
    }
  }

  /// Generate or load master key
  Future<void> _generateOrLoadMasterKey() async {
    final prefs = await SharedPreferences.getInstance();
    final existingKey = prefs.getString('lens_ai_master_key');
    
    if (existingKey != null) {
      _masterKey = base64Decode(existingKey);
    } else {
      _masterKey = _generateRandomBytes(_keySize);
      await prefs.setString('lens_ai_master_key', base64Encode(_masterKey));
    }
  }

  /// Derive encryption key using PBKDF2
  Future<Uint8List> _deriveKey(Uint8List masterKey, Uint8List salt) async {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac(sha256, const []),
      iterations: _config.keyDerivationIterations,
      bits: _keySize * 8,
    );
    
    final derivedKey = await pbkdf2.deriveKey(
      secretKey: SecretKey(masterKey),
      nonce: salt,
    );
    
    return Uint8List.fromList(await derivedKey.extractBytes());
  }

  /// Platform-specific encryption implementation
  Future<Uint8List> _performEncryption(
    Uint8List data,
    Uint8List key,
    Uint8List nonce,
  ) async {
    switch (_config.algorithm) {
      case EncryptionAlgorithm.aes256GCM:
        return await _aesGcmEncrypt(data, key, nonce);
      case EncryptionAlgorithm.chaCha20Poly1305:
        return await _chaCha20Encrypt(data, key, nonce);
    }
  }

  /// Platform-specific decryption implementation
  Future<Uint8List> _performDecryption(
    Uint8List encryptedData,
    Uint8List key,
    Uint8List nonce,
  ) async {
    switch (_config.algorithm) {
      case EncryptionAlgorithm.aes256GCM:
        return await _aesGcmDecrypt(encryptedData, key, nonce);
      case EncryptionAlgorithm.chaCha20Poly1305:
        return await _chaCha20Decrypt(encryptedData, key, nonce);
    }
  }

  /// AES-256-GCM encryption
  Future<Uint8List> _aesGcmEncrypt(
    Uint8List data,
    Uint8List key,
    Uint8List nonce,
  ) async {
    // For production, use platform-specific implementations
    // This is a simplified implementation for demonstration
    final cipher = AesGcm.with256Bits();
    final secretKey = SecretKey(key);
    final secretBox = await cipher.encrypt(data, secretKey: secretKey, nonce: nonce);
    
    // Combine encrypted data with authentication tag
    final result = Uint8List(secretBox.cipherText.length + secretBox.mac.bytes.length);
    result.setRange(0, secretBox.cipherText.length, secretBox.cipherText);
    result.setRange(secretBox.cipherText.length, result.length, secretBox.mac.bytes);
    
    return result;
  }

  /// AES-256-GCM decryption
  Future<Uint8List> _aesGcmDecrypt(
    Uint8List encryptedData,
    Uint8List key,
    Uint8List nonce,
  ) async {
    // Extract ciphertext and authentication tag
    final cipherText = encryptedData.sublist(0, encryptedData.length - _tagSize);
    final tag = encryptedData.sublist(encryptedData.length - _tagSize);
    
    final cipher = AesGcm.with256Bits();
    final secretKey = SecretKey(key);
    final secretBox = SecretBox(cipherText, nonce: nonce, mac: Mac(tag));
    
    return Uint8List.fromList(await cipher.decrypt(secretBox, secretKey: secretKey));
  }

  /// ChaCha20-Poly1305 encryption (optimized for mobile)
  Future<Uint8List> _chaCha20Encrypt(
    Uint8List data,
    Uint8List key,
    Uint8List nonce,
  ) async {
    final cipher = Chacha20.poly1305Aead();
    final secretKey = SecretKey(key);
    final secretBox = await cipher.encrypt(data, secretKey: secretKey, nonce: nonce);
    
    final result = Uint8List(secretBox.cipherText.length + secretBox.mac.bytes.length);
    result.setRange(0, secretBox.cipherText.length, secretBox.cipherText);
    result.setRange(secretBox.cipherText.length, result.length, secretBox.mac.bytes);
    
    return result;
  }

  /// ChaCha20-Poly1305 decryption
  Future<Uint8List> _chaCha20Decrypt(
    Uint8List encryptedData,
    Uint8List key,
    Uint8List nonce,
  ) async {
    final cipherText = encryptedData.sublist(0, encryptedData.length - _tagSize);
    final tag = encryptedData.sublist(encryptedData.length - _tagSize);
    
    final cipher = Chacha20.poly1305Aead();
    final secretKey = SecretKey(key);
    final secretBox = SecretBox(cipherText, nonce: nonce, mac: Mac(tag));
    
    return Uint8List.fromList(await cipher.decrypt(secretBox, secretKey: secretKey));
  }

  /// Generate cryptographically secure random bytes
  Uint8List _generateRandomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
      List.generate(length, (_) => random.nextInt(256)),
    );
  }

  /// Get secure file for storage
  Future<File> _getSecureFile(String key) async {
    final directory = await getApplicationSupportDirectory();
    final secureDir = Directory('${directory.path}/secure');
    if (!await secureDir.exists()) {
      await secureDir.create(recursive: true);
    }
    return File('${secureDir.path}/${key.hashCode}.enc');
  }

  /// Update configuration
  Future<void> updateConfig(EncryptionConfig newConfig) async {
    _config = newConfig;
  }

  /// Dispose resources
  Future<void> dispose() async {
    // Securely clear master key from memory
    _masterKey.fillRange(0, _masterKey.length, 0);
    _isInitialized = false;
  }
}

/// Encrypted data container
class EncryptedData {
  final Uint8List data;
  final Uint8List nonce;
  final Uint8List salt;
  final EncryptionAlgorithm algorithm;
  final DateTime timestamp;

  EncryptedData({
    required this.data,
    required this.nonce,
    required this.salt,
    required this.algorithm,
    required this.timestamp,
  });

  /// Convert to bytes for storage
  Uint8List toBytes() {
    final algorithmIndex = algorithm.index;
    final timestampMs = timestamp.millisecondsSinceEpoch;
    
    // Format: [algorithm(1)] [timestamp(8)] [nonce_len(4)] [salt_len(4)] [data_len(4)] [nonce] [salt] [data]
    final result = BytesBuilder();
    result.addByte(algorithmIndex);
    result.add(_int64ToBytes(timestampMs));
    result.add(_int32ToBytes(nonce.length));
    result.add(_int32ToBytes(salt.length));
    result.add(_int32ToBytes(data.length));
    result.add(nonce);
    result.add(salt);
    result.add(data);
    
    return result.toBytes();
  }

  /// Create from bytes
  static EncryptedData fromBytes(Uint8List bytes) {
    var offset = 0;
    
    final algorithmIndex = bytes[offset++];
    final algorithm = EncryptionAlgorithm.values[algorithmIndex];
    
    final timestampMs = _bytesToInt64(bytes.sublist(offset, offset + 8));
    offset += 8;
    final timestamp = DateTime.fromMillisecondsSinceEpoch(timestampMs);
    
    final nonceLen = _bytesToInt32(bytes.sublist(offset, offset + 4));
    offset += 4;
    final saltLen = _bytesToInt32(bytes.sublist(offset, offset + 4));
    offset += 4;
    final dataLen = _bytesToInt32(bytes.sublist(offset, offset + 4));
    offset += 4;
    
    final nonce = bytes.sublist(offset, offset + nonceLen);
    offset += nonceLen;
    final salt = bytes.sublist(offset, offset + saltLen);
    offset += saltLen;
    final data = bytes.sublist(offset, offset + dataLen);
    
    return EncryptedData(
      data: data,
      nonce: nonce,
      salt: salt,
      algorithm: algorithm,
      timestamp: timestamp,
    );
  }

  static Uint8List _int32ToBytes(int value) {
    return Uint8List(4)..buffer.asByteData().setInt32(0, value, Endian.big);
  }

  static Uint8List _int64ToBytes(int value) {
    return Uint8List(8)..buffer.asByteData().setInt64(0, value, Endian.big);
  }

  static int _bytesToInt32(Uint8List bytes) {
    return bytes.buffer.asByteData().getInt32(0, Endian.big);
  }

  static int _bytesToInt64(Uint8List bytes) {
    return bytes.buffer.asByteData().getInt64(0, Endian.big);
  }
}

/// Encryption configuration
class EncryptionConfig {
  final bool encryptionEnabled;
  final EncryptionAlgorithm algorithm;
  final int keyDerivationIterations;
  final bool useSecureStorage;
  final bool compressBeforeEncryption;

  EncryptionConfig({
    required this.encryptionEnabled,
    required this.algorithm,
    required this.keyDerivationIterations,
    required this.useSecureStorage,
    required this.compressBeforeEncryption,
  });

  factory EncryptionConfig.standard() {
    return EncryptionConfig(
      encryptionEnabled: true,
      algorithm: EncryptionAlgorithm.aes256GCM,
      keyDerivationIterations: 10000,
      useSecureStorage: true,
      compressBeforeEncryption: false,
    );
  }

  factory EncryptionConfig.highSecurity() {
    return EncryptionConfig(
      encryptionEnabled: true,
      algorithm: EncryptionAlgorithm.chaCha20Poly1305,
      keyDerivationIterations: 50000,
      useSecureStorage: true,
      compressBeforeEncryption: true,
    );
  }
}

/// Supported encryption algorithms
enum EncryptionAlgorithm {
  aes256GCM,
  chaCha20Poly1305,
}

/// Security exception
class SecurityException implements Exception {
  final String message;
  SecurityException(this.message);
  
  @override
  String toString() => 'SecurityException: $message';
}

// Mock implementations for cryptography package classes
// In production, use the actual cryptography package

class AesGcm {
  static AesGcm with256Bits() => AesGcm();
  
  Future<SecretBox> encrypt(List<int> clearText, {required SecretKey secretKey, required List<int> nonce}) async {
    // Mock implementation - replace with actual AES-GCM
    return SecretBox(clearText, nonce: nonce, mac: Mac(List.filled(16, 0)));
  }
  
  Future<List<int>> decrypt(SecretBox secretBox, {required SecretKey secretKey}) async {
    // Mock implementation - replace with actual AES-GCM
    return secretBox.cipherText;
  }
}

class Chacha20 {
  static Chacha20 poly1305Aead() => Chacha20();
  
  Future<SecretBox> encrypt(List<int> clearText, {required SecretKey secretKey, required List<int> nonce}) async {
    // Mock implementation - replace with actual ChaCha20-Poly1305
    return SecretBox(clearText, nonce: nonce, mac: Mac(List.filled(16, 0)));
  }
  
  Future<List<int>> decrypt(SecretBox secretBox, {required SecretKey secretKey}) async {
    // Mock implementation - replace with actual ChaCha20-Poly1305
    return secretBox.cipherText;
  }
}

class SecretKey {
  final List<int> bytes;
  SecretKey(this.bytes);
  Future<List<int>> extractBytes() async => bytes;
}

class SecretBox {
  final List<int> cipherText;
  final List<int> nonce;
  final Mac mac;
  SecretBox(this.cipherText, {required this.nonce, required this.mac});
}

class Mac {
  final List<int> bytes;
  Mac(this.bytes);
}

class Pbkdf2 {
  final MacAlgorithm macAlgorithm;
  final int iterations;
  final int bits;
  
  Pbkdf2({required this.macAlgorithm, required this.iterations, required this.bits});
  
  Future<SecretKey> deriveKey({required SecretKey secretKey, required List<int> nonce}) async {
    // Mock implementation - replace with actual PBKDF2
    return secretKey;
  }
}

abstract class MacAlgorithm {}