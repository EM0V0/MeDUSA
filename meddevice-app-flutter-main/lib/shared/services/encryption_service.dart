import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';

/// Encryption service abstract class
abstract class EncryptionService {
  /// Generate random AES key
  Future<String> generateAESKey();
  
  /// Encrypt JSON data
  Future<Map<String, String>> encryptJson(Map<String, dynamic> data, String base64Key);
  
  /// Decrypt JSON data
  Future<Map<String, dynamic>> decryptJson(Map<String, String> encryptedData, String base64Key);
  
  /// Generate random string
  String generateRandomString(int length);
  
  /// Hash password
  String hashPassword(String password, String salt);
  
  /// Verify password
  bool verifyPassword(String password, String salt, String hashedPassword);
  
  /// Generate salt
  String generateSalt();
}

/// Encryption service implementation
class EncryptionServiceImpl implements EncryptionService {
  final AesGcm _aesGcm = AesGcm.with256bits();
  
  @override
  Future<String> generateAESKey() async {
    final secretKey = await _aesGcm.newSecretKey();
    final keyBytes = await secretKey.extractBytes();
    return base64Encode(keyBytes);
  }

  @override
  Future<Map<String, String>> encryptJson(Map<String, dynamic> data, String base64Key) async {
    try {
      // Convert data to JSON string
      final jsonString = jsonEncode(data);
      final plaintext = utf8.encode(jsonString);
      
      // Create SecretKey from base64 key
      final keyBytes = base64Decode(base64Key);
      final secretKey = await _aesGcm.newSecretKeyFromBytes(keyBytes);
      
      // Generate random nonce (initialization vector)
      final nonce = _aesGcm.newNonce();
      
      // Encrypt data
      final secretBox = await _aesGcm.encrypt(
        plaintext,
        secretKey: secretKey,
        nonce: nonce,
      );
      
      // Return encryption result
      return {
        'iv': base64Encode(nonce),
        'ciphertext': base64Encode(secretBox.cipherText),
        'tag': base64Encode(secretBox.mac.bytes),
      };
    } catch (e) {
      throw EncryptionException('Failed to encrypt JSON: $e');
    }
  }

  @override
  Future<Map<String, dynamic>> decryptJson(Map<String, String> encryptedData, String base64Key) async {
    try {
      // Validate required fields
      final iv = encryptedData['iv'];
      final ciphertext = encryptedData['ciphertext'];
      final tag = encryptedData['tag'];
      
      if (iv == null || ciphertext == null || tag == null) {
        throw const EncryptionException('Missing required encryption fields');
      }
      
      // Decode data
      final nonceBytes = base64Decode(iv);
      final ciphertextBytes = base64Decode(ciphertext);
      final tagBytes = base64Decode(tag);
      final keyBytes = base64Decode(base64Key);
      
      // Create SecretKey and SecretBox
      final secretKey = await _aesGcm.newSecretKeyFromBytes(keyBytes);
      final nonce = List<int>.from(nonceBytes);
      final mac = Mac(tagBytes);
      final secretBox = SecretBox(ciphertextBytes, nonce: nonce, mac: mac);
      
      // Decrypt data
      final decryptedBytes = await _aesGcm.decrypt(
        secretBox,
        secretKey: secretKey,
      );
      
      // Convert back to JSON
      final jsonString = utf8.decode(decryptedBytes);
      return jsonDecode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      throw EncryptionException('Failed to decrypt JSON: $e');
    }
  }

  @override
  String generateRandomString(int length) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random.secure();
    return String.fromCharCodes(
      Iterable.generate(length, (_) => chars.codeUnitAt(random.nextInt(chars.length))),
    );
  }

  @override
  String hashPassword(String password, String salt) {
    final bytes = utf8.encode(password + salt);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  @override
  bool verifyPassword(String password, String salt, String hashedPassword) {
    final hash = hashPassword(password, salt);
    return hash == hashedPassword;
  }

  @override
  String generateSalt() {
    return generateRandomString(32);
  }
}

/// Encryption exception class
class EncryptionException implements Exception {
  final String message;
  
  const EncryptionException(this.message);
  
  @override
  String toString() => 'EncryptionException: $message';
}

/// Encryption utility class
class EncryptionUtils {
  /// Generate secure random bytes
  static Uint8List generateRandomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(List.generate(length, (_) => random.nextInt(256)));
  }
  
  /// Convert byte array to hexadecimal string
  static String bytesToHex(List<int> bytes) {
    return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }
  
  /// Convert hexadecimal string to byte array
  static List<int> hexToBytes(String hex) {
    final result = <int>[];
    for (int i = 0; i < hex.length; i += 2) {
      result.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return result;
  }
  
  /// Secure string comparison (prevent timing attacks)
  static bool secureStringCompare(String a, String b) {
    if (a.length != b.length) {
      return false;
    }
    
    int result = 0;
    for (int i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    
    return result == 0;
  }
  
  /// Validate Base64 string format
  static bool isValidBase64(String value) {
    try {
      base64Decode(value);
      return true;
    } catch (e) {
      return false;
    }
  }
  
  /// Clear sensitive string memory
  static void clearSensitiveString(StringBuffer buffer) {
    // Clear buffer contents
    buffer.clear();
  }
}

/// Encrypted data model
class EncryptedPayload {
  final String iv;
  final String ciphertext;
  final String tag;
  
  const EncryptedPayload({
    required this.iv,
    required this.ciphertext,
    required this.tag,
  });
  
  Map<String, String> toMap() {
    return {
      'iv': iv,
      'ciphertext': ciphertext,
      'tag': tag,
    };
  }
  
  factory EncryptedPayload.fromMap(Map<String, String> map) {
    return EncryptedPayload(
      iv: map['iv'] ?? '',
      ciphertext: map['ciphertext'] ?? '',
      tag: map['tag'] ?? '',
    );
  }
  
  String toJson() => jsonEncode(toMap());
  
  factory EncryptedPayload.fromJson(String source) {
    final map = jsonDecode(source) as Map<String, dynamic>;
    return EncryptedPayload.fromMap(Map<String, String>.from(map));
  }
  
  @override
  String toString() => 'EncryptedPayload(iv: ${iv.substring(0, 8)}..., ciphertext: ${ciphertext.length} chars, tag: ${tag.substring(0, 8)}...)';
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    
    return other is EncryptedPayload &&
        other.iv == iv &&
        other.ciphertext == ciphertext &&
        other.tag == tag;
  }
  
  @override
  int get hashCode => iv.hashCode ^ ciphertext.hashCode ^ tag.hashCode;
} 