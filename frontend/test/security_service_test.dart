import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

// Import the security service
import 'package:medusa_app/shared/services/security_service.dart';

// Generate mocks
@GenerateMocks([FlutterSecureStorage, LocalAuthentication])
import 'security_service_test.mocks.dart';

void main() {
  late SecurityServiceImpl securityService;
  late MockFlutterSecureStorage mockStorage;
  late MockLocalAuthentication mockLocalAuth;

  setUp(() {
    mockStorage = MockFlutterSecureStorage();
    mockLocalAuth = MockLocalAuthentication();
    
    // Default mock behavior
    when(mockStorage.read(key: anyNamed('key')))
        .thenAnswer((_) async => null);
    when(mockStorage.write(key: anyNamed('key'), value: anyNamed('value')))
        .thenAnswer((_) async {});
    when(mockStorage.delete(key: anyNamed('key')))
        .thenAnswer((_) async {});
    when(mockStorage.deleteAll())
        .thenAnswer((_) async {});
    
    when(mockLocalAuth.canCheckBiometrics)
        .thenAnswer((_) async => true);
    when(mockLocalAuth.isDeviceSupported())
        .thenAnswer((_) async => true);
    when(mockLocalAuth.getAvailableBiometrics())
        .thenAnswer((_) async => [BiometricType.fingerprint]);
    
    securityService = SecurityServiceImpl(
      secureStorage: mockStorage,
      localAuth: mockLocalAuth,
    );
  });

  group('SecurityServiceImpl', () {
    group('Device Fingerprint', () {
      test('generates unique fingerprints', () async {
        final fingerprint1 = await securityService.generateDeviceFingerprint();
        final fingerprint2 = await securityService.generateDeviceFingerprint();
        
        expect(fingerprint1, isNotEmpty);
        expect(fingerprint2, isNotEmpty);
        // Due to timestamp, each generation should be different
        expect(fingerprint1, isNot(equals(fingerprint2)));
      });
      
      test('fingerprint has correct SHA-256 length', () async {
        final fingerprint = await securityService.generateDeviceFingerprint();
        
        // SHA-256 produces 64 hex characters
        expect(fingerprint.length, equals(64));
        expect(RegExp(r'^[a-f0-9]+$').hasMatch(fingerprint), isTrue);
      });
    });

    group('Nonce Generation and Validation', () {
      test('generates valid nonce format', () async {
        final nonce = await securityService.generateNonce();
        
        expect(nonce, isNotEmpty);
        expect(nonce.contains('_'), isTrue);
        
        // Should have timestamp and random parts
        final parts = nonce.split('_');
        expect(parts.length, equals(2));
        
        // First part should be numeric timestamp
        expect(int.tryParse(parts[0]), isNotNull);
      });
      
      test('generates unique nonces', () async {
        final nonces = <String>{};
        
        for (int i = 0; i < 100; i++) {
          final nonce = await securityService.generateNonce();
          expect(nonces.contains(nonce), isFalse, 
              reason: 'Nonce should be unique');
          nonces.add(nonce);
        }
      });
      
      test('validates fresh nonce', () async {
        final nonce = await securityService.generateNonce();
        
        // Create new service instance for validation
        final validator = SecurityServiceImpl(
          secureStorage: mockStorage,
          localAuth: mockLocalAuth,
        );
        
        final isValid = await validator.verifyNonce(nonce);
        expect(isValid, isTrue);
      });
      
      test('rejects empty nonce', () async {
        final isValid = await securityService.verifyNonce('');
        expect(isValid, isFalse);
      });
      
      test('rejects short nonce', () async {
        final isValid = await securityService.verifyNonce('short');
        expect(isValid, isFalse);
      });
    });

    group('Secure Key Generation', () {
      test('generates base64 encoded key', () async {
        final key = await securityService.generateSecureKey();
        
        expect(key, isNotEmpty);
        
        // Should be valid base64
        expect(() => base64Decode(key), returnsNormally);
        
        // Decoded should be 32 bytes (256 bits)
        final decoded = base64Decode(key);
        expect(decoded.length, equals(32));
      });
      
      test('generates unique keys', () async {
        final key1 = await securityService.generateSecureKey();
        final key2 = await securityService.generateSecureKey();
        
        expect(key1, isNot(equals(key2)));
      });
    });

    group('Secure Random Generation', () {
      test('generates correct length', () async {
        final lengths = [16, 32, 64, 128];
        
        for (final length in lengths) {
          final random = await securityService.generateSecureRandom(length);
          expect(random.length, equals(length));
        }
      });
      
      test('generates random data', () async {
        final random1 = await securityService.generateSecureRandom(32);
        final random2 = await securityService.generateSecureRandom(32);
        
        // Extremely unlikely to be equal
        expect(random1, isNot(equals(random2)));
      });
    });

    group('Key Derivation', () {
      test('derives consistent key from same inputs', () async {
        final password = 'testPassword123';
        final salt = base64Encode(Uint8List.fromList(List.filled(32, 0)));
        
        final key1 = await securityService.deriveKey(password, salt, iterations: 1000);
        final key2 = await securityService.deriveKey(password, salt, iterations: 1000);
        
        expect(key1, equals(key2));
      });
      
      test('derives different keys for different passwords', () async {
        final salt = base64Encode(Uint8List.fromList(List.filled(32, 0)));
        
        final key1 = await securityService.deriveKey('password1', salt, iterations: 1000);
        final key2 = await securityService.deriveKey('password2', salt, iterations: 1000);
        
        expect(key1, isNot(equals(key2)));
      });
      
      test('derives different keys for different salts', () async {
        final password = 'testPassword';
        final salt1 = base64Encode(Uint8List.fromList(List.filled(32, 0)));
        final salt2 = base64Encode(Uint8List.fromList(List.filled(32, 1)));
        
        final key1 = await securityService.deriveKey(password, salt1, iterations: 1000);
        final key2 = await securityService.deriveKey(password, salt2, iterations: 1000);
        
        expect(key1, isNot(equals(key2)));
      });
    });

    group('Secure Clear', () {
      test('zeros out data', () {
        final data = [1, 2, 3, 4, 5, 6, 7, 8];
        securityService.secureClear(data);
        
        expect(data.every((byte) => byte == 0), isTrue);
      });
    });

    group('Biometric Authentication', () {
      test('returns true when biometrics available and auth succeeds', () async {
        when(mockLocalAuth.authenticate(
          localizedReason: anyNamed('localizedReason'),
          options: anyNamed('options'),
        )).thenAnswer((_) async => true);
        
        final result = await securityService.authenticateWithBiometrics();
        expect(result, isTrue);
      });
      
      test('returns false when biometrics not available', () async {
        when(mockLocalAuth.canCheckBiometrics)
            .thenAnswer((_) async => false);
        
        final result = await securityService.authenticateWithBiometrics();
        expect(result, isFalse);
      });
      
      test('returns false when device not supported', () async {
        when(mockLocalAuth.isDeviceSupported())
            .thenAnswer((_) async => false);
        
        final result = await securityService.authenticateWithBiometrics();
        expect(result, isFalse);
      });
    });

    group('Secure Storage', () {
      test('stores data with prefix', () async {
        await securityService.storeSecureData('testKey', 'testValue');
        
        verify(mockStorage.write(
          key: 'secure_testKey',
          value: 'testValue',
        )).called(1);
      });
      
      test('retrieves data with prefix', () async {
        when(mockStorage.read(key: 'secure_testKey'))
            .thenAnswer((_) async => 'testValue');
        
        final value = await securityService.getSecureData('testKey');
        expect(value, equals('testValue'));
      });
      
      test('deletes data with prefix', () async {
        await securityService.deleteSecureData('testKey');
        
        verify(mockStorage.delete(key: 'secure_testKey')).called(1);
      });
      
      test('clears all secure data', () async {
        await securityService.clearAllSecureData();
        
        verify(mockStorage.deleteAll()).called(1);
      });
    });
  });

  group('DeviceIntegrityStatus', () {
    test('enum values are defined', () {
      expect(DeviceIntegrityStatus.values, contains(DeviceIntegrityStatus.secure));
      expect(DeviceIntegrityStatus.values, contains(DeviceIntegrityStatus.rooted));
      expect(DeviceIntegrityStatus.values, contains(DeviceIntegrityStatus.jailbroken));
      expect(DeviceIntegrityStatus.values, contains(DeviceIntegrityStatus.emulator));
      expect(DeviceIntegrityStatus.values, contains(DeviceIntegrityStatus.debugMode));
      expect(DeviceIntegrityStatus.values, contains(DeviceIntegrityStatus.unknown));
    });
  });

  group('CertificatePinningResult', () {
    test('creates valid result', () {
      final result = CertificatePinningResult(
        isValid: true,
        fingerprint: 'ABC123',
        checkedAt: DateTime.now(),
      );
      
      expect(result.isValid, isTrue);
      expect(result.fingerprint, equals('ABC123'));
      expect(result.error, isNull);
    });
    
    test('creates invalid result with error', () {
      final result = CertificatePinningResult(
        isValid: false,
        error: 'Certificate mismatch',
        checkedAt: DateTime.now(),
      );
      
      expect(result.isValid, isFalse);
      expect(result.error, equals('Certificate mismatch'));
    });
  });

  group('TLSConnectionInfo', () {
    test('toMap returns all fields', () {
      final info = TLSConnectionInfo(
        host: 'api.example.com',
        port: 443,
        protocol: 'TLSv1.3',
        cipherSuite: 'TLS_AES_256_GCM_SHA384',
        certificateSubject: 'CN=api.example.com',
        certificateIssuer: 'CN=Example CA',
        certificateValidFrom: DateTime(2025, 1, 1),
        certificateValidTo: DateTime(2026, 1, 1),
        certificateFingerprint: 'ABC123DEF456',
      );
      
      final map = info.toMap();
      
      expect(map['host'], equals('api.example.com'));
      expect(map['port'], equals(443));
      expect(map['protocol'], equals('TLSv1.3'));
      expect(map['cipherSuite'], equals('TLS_AES_256_GCM_SHA384'));
      expect(map['certificateSubject'], equals('CN=api.example.com'));
      expect(map['certificateIssuer'], equals('CN=Example CA'));
      expect(map['certificateFingerprint'], equals('ABC123DEF456'));
    });
  });

  group('SecurityException', () {
    test('toString includes message', () {
      final exception = SecurityException('Test error');
      expect(exception.toString(), contains('Test error'));
    });
    
    test('toString includes details when provided', () {
      final exception = SecurityException('Test error', details: 'More info');
      expect(exception.toString(), contains('Test error'));
      expect(exception.toString(), contains('More info'));
    });
  });
}
