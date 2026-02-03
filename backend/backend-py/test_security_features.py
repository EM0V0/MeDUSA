"""
MeDUSA Security Features Test Suite

This module contains comprehensive tests for all security features:
- Replay protection (nonce validation)
- Firmware update verification
- Audit logging
- Password validation
- Request signing

Run with: python -m pytest test_security_features.py -v
"""

import os
import sys
import json
import time
import hashlib
import base64
import unittest
from datetime import datetime, timezone
from unittest.mock import patch, MagicMock

# Set up test environment
os.environ['USE_MEMORY'] = 'true'
os.environ['JWT_SECRET'] = 'test-secret-key-for-testing'
os.environ['HMAC_SECRET'] = 'test-hmac-secret-key'

# Import modules to test
from replay_protection import (
    NonceService,
    RequestSignatureService,
    nonce_service,
    signature_service,
    NONCE_TTL_SECONDS
)
from firmware_service import (
    FirmwareVerificationService,
    FirmwareStatus,
    FirmwareManifest,
    firmware_service
)
from password_validator import PasswordValidator
from audit_service import AuditService, AuditEventType, AuditSeverity


class TestNonceService(unittest.TestCase):
    """Test cases for replay protection nonce service."""
    
    def setUp(self):
        """Set up test fixtures."""
        self.nonce_service = NonceService()
    
    def test_generate_nonce_format(self):
        """Test that generated nonce has correct format."""
        nonce = self.nonce_service.generate_nonce()
        
        # Nonce should have 3 parts: timestamp.randomHex.signature (using dots)
        parts = nonce.split('.')
        self.assertEqual(len(parts), 3, "Nonce should have 3 parts")
        
        # First part should be numeric timestamp
        timestamp = parts[0]
        self.assertTrue(timestamp.isdigit(), "First part should be numeric timestamp")
        
        # Timestamp should be recent (within last minute)
        ts = int(timestamp)
        now = int(time.time() * 1000)
        self.assertLess(abs(now - ts), 60000, "Timestamp should be recent")
    
    def test_generate_nonce_uniqueness(self):
        """Test that generated nonces are unique."""
        nonces = set()
        for _ in range(100):
            nonce = self.nonce_service.generate_nonce()
            self.assertNotIn(nonce, nonces, "Nonce should be unique")
            nonces.add(nonce)
    
    def test_validate_nonce_success(self):
        """Test successful nonce validation."""
        # Generate and validate nonce with a fresh service
        validator = NonceService()
        nonce = validator.generate_nonce()
        
        # Create another service to test validation (first use)
        # The nonce should be valid because HMAC_SECRET is the same
        validator2 = NonceService()
        is_valid, error = validator2.validate_nonce(nonce)
        
        self.assertTrue(is_valid, f"Valid nonce should pass: {error}")
    
    def test_validate_nonce_replay_attack(self):
        """Test that reused nonce is rejected (replay attack prevention)."""
        # Use same service instance for both validations to test replay detection
        service = NonceService()
        nonce = service.generate_nonce()
        
        # First use should succeed
        is_valid1, error1 = service.validate_nonce(nonce)
        self.assertTrue(is_valid1, f"First use should succeed: {error1}")
        
        # Second use should fail (replay attack)
        is_valid2, error2 = service.validate_nonce(nonce)
        self.assertFalse(is_valid2, "Reused nonce should be rejected")
        self.assertIn("already used", error2.lower())
    
    def test_validate_nonce_expired(self):
        """Test that expired nonce is rejected."""
        # Create nonce with old timestamp
        old_timestamp = int((time.time() - NONCE_TTL_SECONDS - 60) * 1000)
        random_hex = os.urandom(16).hex()
        
        # Create signature
        import hmac
        data = f"{old_timestamp}.{random_hex}"
        signature = hmac.new(
            os.environ['HMAC_SECRET'].encode(),
            data.encode(),
            hashlib.sha256
        ).hexdigest()[:16]
        
        expired_nonce = f"{data}.{signature}"
        
        is_valid, error = self.nonce_service.validate_nonce(expired_nonce)
        self.assertFalse(is_valid, "Expired nonce should be rejected")
        self.assertIn("expired", error.lower())
    
    def test_validate_nonce_tampered(self):
        """Test that tampered nonce is rejected."""
        nonce = self.nonce_service.generate_nonce()
        
        # Tamper with the nonce - replace random part but keep 3 parts
        parts = nonce.split('.')
        self.assertEqual(len(parts), 3, "Nonce should have 3 parts")
        
        # Tamper with the random part (hex string)
        parts[1] = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'  # Different hex content
        tampered_nonce = '.'.join(parts)
        
        is_valid, error = self.nonce_service.validate_nonce(tampered_nonce)
        self.assertFalse(is_valid, "Tampered nonce should be rejected")
        # Should fail signature validation
        self.assertTrue(
            "signature" in error.lower() or "invalid" in error.lower(),
            f"Error should mention signature or invalid: {error}"
        )
    
    def test_validate_nonce_empty(self):
        """Test that empty nonce is rejected."""
        is_valid, error = self.nonce_service.validate_nonce("")
        self.assertFalse(is_valid, "Empty nonce should be rejected")
    
    def test_validate_nonce_invalid_format(self):
        """Test that malformed nonce is rejected."""
        is_valid, error = self.nonce_service.validate_nonce("invalid_nonce")
        self.assertFalse(is_valid, "Malformed nonce should be rejected")


class TestRequestSignatureService(unittest.TestCase):
    """Test cases for request signature verification."""
    
    def test_sign_and_verify_get_request(self):
        """Test signing and verifying a GET request."""
        method = "GET"
        path = "/api/v1/patients"
        timestamp = datetime.now(timezone.utc).isoformat()
        
        # Sign the request
        signature = RequestSignatureService.sign_request(method, path, timestamp)
        
        # Verify the signature
        is_valid, error = RequestSignatureService.verify_signature(
            method, path, timestamp, signature
        )
        
        self.assertTrue(is_valid, f"Valid signature should pass: {error}")
    
    def test_sign_and_verify_post_request(self):
        """Test signing and verifying a POST request with body."""
        method = "POST"
        path = "/api/v1/auth/login"
        timestamp = datetime.now(timezone.utc).isoformat()
        body = '{"email": "test@example.com", "password": "secret"}'
        
        # Sign the request
        signature = RequestSignatureService.sign_request(method, path, timestamp, body)
        
        # Verify the signature
        is_valid, error = RequestSignatureService.verify_signature(
            method, path, timestamp, signature, body
        )
        
        self.assertTrue(is_valid, f"Valid signature should pass: {error}")
    
    def test_verify_tampered_body(self):
        """Test that tampered request body is detected."""
        method = "POST"
        path = "/api/v1/patients"
        timestamp = datetime.now(timezone.utc).isoformat()
        original_body = '{"name": "John Doe"}'
        
        # Sign with original body
        signature = RequestSignatureService.sign_request(
            method, path, timestamp, original_body
        )
        
        # Verify with tampered body
        tampered_body = '{"name": "Jane Doe"}'
        is_valid, error = RequestSignatureService.verify_signature(
            method, path, timestamp, signature, tampered_body
        )
        
        self.assertFalse(is_valid, "Tampered body should be rejected")
    
    def test_verify_expired_timestamp(self):
        """Test that expired timestamp is rejected."""
        method = "GET"
        path = "/api/v1/health"
        
        # Use timestamp older than TTL
        old_time = datetime.now(timezone.utc)
        old_time = old_time.replace(
            minute=old_time.minute - 10  # 10 minutes ago
        )
        timestamp = old_time.isoformat()
        
        signature = RequestSignatureService.sign_request(method, path, timestamp)
        
        is_valid, error = RequestSignatureService.verify_signature(
            method, path, timestamp, signature
        )
        
        self.assertFalse(is_valid, "Expired timestamp should be rejected")


class TestFirmwareVerificationService(unittest.TestCase):
    """Test cases for firmware update verification."""
    
    def setUp(self):
        """Set up test fixtures."""
        self.service = FirmwareVerificationService()
        
        # Create test firmware data
        self.firmware_data = b"This is test firmware binary data" * 100
        self.firmware_hash = hashlib.sha256(self.firmware_data).hexdigest()
    
    def test_parse_valid_manifest(self):
        """Test parsing a valid firmware manifest."""
        manifest_data = {
            "firmware_id": "fw_001",
            "version": "1.2.0",
            "device_type": "tremor_sensor",
            "release_date": "2026-02-03T12:00:00Z",
            "min_required_version": "1.0.0",
            "sha256_hash": self.firmware_hash,
            "size_bytes": len(self.firmware_data),
            "signature": "test_signature",
            "certificate_id": "cert_001"
        }
        
        manifest = self.service._parse_manifest(json.dumps(manifest_data))
        
        self.assertIsNotNone(manifest, "Valid manifest should parse successfully")
        self.assertEqual(manifest.version, "1.2.0")
        self.assertEqual(manifest.device_type, "tremor_sensor")
    
    def test_parse_invalid_manifest(self):
        """Test parsing an invalid firmware manifest."""
        # Missing required fields
        invalid_data = {
            "firmware_id": "fw_001",
            "version": "1.2.0"
            # Missing other required fields
        }
        
        manifest = self.service._parse_manifest(json.dumps(invalid_data))
        self.assertIsNone(manifest, "Invalid manifest should return None")
    
    def test_version_rollback_detection(self):
        """Test version rollback detection."""
        # Newer version should not be rollback
        self.assertFalse(
            self.service._is_rollback("2.0.0", "1.0.0"),
            "2.0.0 is newer than 1.0.0"
        )
        
        # Older version should be rollback
        self.assertTrue(
            self.service._is_rollback("1.0.0", "2.0.0"),
            "1.0.0 is older than 2.0.0"
        )
        
        # Same version is not rollback
        self.assertFalse(
            self.service._is_rollback("1.0.0", "1.0.0"),
            "Same version is not rollback"
        )
        
        # Minor version rollback
        self.assertTrue(
            self.service._is_rollback("1.0.0", "1.1.0"),
            "1.0.0 is older than 1.1.0"
        )
        
        # Patch version rollback
        self.assertTrue(
            self.service._is_rollback("1.0.0", "1.0.1"),
            "1.0.0 is older than 1.0.1"
        )
    
    def test_hash_verification(self):
        """Test firmware hash verification."""
        # Correct hash should pass
        self.assertTrue(
            self.service._verify_hash(self.firmware_data, self.firmware_hash),
            "Correct hash should verify"
        )
        
        # Wrong hash should fail
        self.assertFalse(
            self.service._verify_hash(self.firmware_data, "wrong_hash"),
            "Wrong hash should fail"
        )
        
        # Modified data should fail
        modified_data = self.firmware_data + b"modified"
        self.assertFalse(
            self.service._verify_hash(modified_data, self.firmware_hash),
            "Modified data should fail hash check"
        )
    
    def test_full_verification_valid(self):
        """Test full firmware verification with valid data."""
        manifest_data = {
            "firmware_id": "fw_test",
            "version": "1.2.0",
            "device_type": "tremor_sensor",
            "release_date": "2026-02-03T12:00:00Z",
            "min_required_version": "1.0.0",
            "sha256_hash": self.firmware_hash,
            "size_bytes": len(self.firmware_data),
            "signature": "",  # Empty for test (no public key configured)
            "certificate_id": "cert_001"
        }
        
        result = self.service.verify_firmware_update(
            manifest_json=json.dumps(manifest_data),
            firmware_data=self.firmware_data,
            current_version="1.0.0",
            device_type="tremor_sensor"
        )
        
        self.assertTrue(result.is_valid, f"Valid firmware should pass: {result.message}")
        self.assertEqual(result.status, FirmwareStatus.VALID)
    
    def test_full_verification_rollback(self):
        """Test firmware verification rejects rollback."""
        manifest_data = {
            "firmware_id": "fw_test",
            "version": "1.0.0",  # Same as current
            "device_type": "tremor_sensor",
            "release_date": "2026-02-03T12:00:00Z",
            "min_required_version": "1.0.0",
            "sha256_hash": self.firmware_hash,
            "size_bytes": len(self.firmware_data),
            "signature": "",
            "certificate_id": "cert_001"
        }
        
        result = self.service.verify_firmware_update(
            manifest_json=json.dumps(manifest_data),
            firmware_data=self.firmware_data,
            current_version="1.5.0",  # Current is newer
            device_type="tremor_sensor"
        )
        
        self.assertFalse(result.is_valid, "Rollback should be rejected")
        self.assertEqual(result.status, FirmwareStatus.VERSION_ROLLBACK)


class TestPasswordValidator(unittest.TestCase):
    """Test cases for password validation."""
    
    def test_valid_password(self):
        """Test that valid password passes all checks."""
        valid_passwords = [
            "SecurePass123!",
            "MyP@ssword99",
            "Test#1234Ab",
            "Complex_P4ss!"
        ]
        
        for password in valid_passwords:
            is_valid, error = PasswordValidator.validate(password)
            self.assertTrue(is_valid, f"'{password}' should be valid: {error}")
    
    def test_password_too_short(self):
        """Test that short password is rejected."""
        is_valid, error = PasswordValidator.validate("Ab1!")
        self.assertFalse(is_valid, "Short password should be rejected")
        self.assertIn("8", error, "Error should mention minimum length")
    
    def test_password_missing_uppercase(self):
        """Test that password without uppercase is rejected."""
        is_valid, error = PasswordValidator.validate("lowercase123!")
        self.assertFalse(is_valid, "Password without uppercase should be rejected")
        self.assertIn("uppercase", error.lower())
    
    def test_password_missing_lowercase(self):
        """Test that password without lowercase is rejected."""
        is_valid, error = PasswordValidator.validate("UPPERCASE123!")
        self.assertFalse(is_valid, "Password without lowercase should be rejected")
        self.assertIn("lowercase", error.lower())
    
    def test_password_missing_digit(self):
        """Test that password without digit is rejected."""
        is_valid, error = PasswordValidator.validate("NoDigits!@#")
        self.assertFalse(is_valid, "Password without digit should be rejected")
        self.assertIn("number", error.lower())
    
    def test_password_missing_special(self):
        """Test that password without special character is rejected."""
        is_valid, error = PasswordValidator.validate("NoSpecial123")
        self.assertFalse(is_valid, "Password without special char should be rejected")
        self.assertIn("special", error.lower())
    
    def test_empty_password(self):
        """Test that empty password is rejected."""
        is_valid, error = PasswordValidator.validate("")
        self.assertFalse(is_valid, "Empty password should be rejected")


class TestAuditService(unittest.TestCase):
    """Test cases for audit logging service."""
    
    def setUp(self):
        """Set up test fixtures."""
        self.audit_service = AuditService(service_name="test-service")
    
    def test_log_event_structure(self):
        """Test that logged events have correct structure."""
        event = self.audit_service.log_event(
            event_type=AuditEventType.AUTH_LOGIN_SUCCESS,
            user_id="usr_123",
            user_role="patient"
        )
        
        # Check required fields
        self.assertIn("log_type", event)
        self.assertEqual(event["log_type"], "AUDIT")
        self.assertIn("timestamp", event)
        self.assertIn("event_type", event)
        self.assertIn("event_hash", event)
    
    def test_pii_masking_password(self):
        """Test that passwords are fully masked."""
        masked = self.audit_service._mask_sensitive_data({
            "email": "test@example.com",
            "password": "supersecret123"
        })
        
        self.assertEqual(masked["password"], "***REDACTED***")
    
    def test_pii_masking_email(self):
        """Test that emails are partially masked."""
        masked = self.audit_service._mask_sensitive_data({
            "email": "longuser@example.com"
        })
        
        # Should show first 3 and last 4 characters
        self.assertIn("***", masked["email"])
        self.assertTrue(masked["email"].startswith("lon"))
        self.assertTrue(masked["email"].endswith(".com"))
    
    def test_severity_determination(self):
        """Test automatic severity determination."""
        # Critical event
        severity = self.audit_service._get_severity_for_event(
            AuditEventType.AUTHZ_ROLE_ESCALATION_ATTEMPT
        )
        self.assertEqual(severity, AuditSeverity.CRITICAL)
        
        # Error event
        severity = self.audit_service._get_severity_for_event(
            AuditEventType.AUTH_LOGIN_FAILURE
        )
        self.assertEqual(severity, AuditSeverity.ERROR)
        
        # Info event
        severity = self.audit_service._get_severity_for_event(
            AuditEventType.AUTH_LOGIN_SUCCESS
        )
        self.assertEqual(severity, AuditSeverity.INFO)
    
    def test_event_hash_chain(self):
        """Test that event hashes form a chain."""
        service = AuditService()
        
        event1 = service.log_event(
            event_type=AuditEventType.DATA_READ,
            user_id="usr_001"
        )
        
        event2 = service.log_event(
            event_type=AuditEventType.DATA_READ,
            user_id="usr_002"
        )
        
        # Hashes should be different (due to chaining)
        self.assertNotEqual(
            event1["event_hash"],
            event2["event_hash"]
        )


class TestSecurityIntegration(unittest.TestCase):
    """Integration tests for security features."""
    
    def test_nonce_to_signature_workflow(self):
        """Test complete request security workflow."""
        # 1. Get a nonce
        nonce = nonce_service.generate_nonce()
        
        # 2. Create a signed request
        method = "POST"
        path = "/api/v1/sensitive/action"
        timestamp = datetime.now(timezone.utc).isoformat()
        body = json.dumps({"action": "delete", "target": "data_001"})
        
        signature = signature_service.sign_request(method, path, timestamp, body)
        
        # 3. Validate nonce
        nonce_valid, nonce_error = nonce_service.validate_nonce(nonce)
        self.assertTrue(nonce_valid, f"Nonce validation failed: {nonce_error}")
        
        # 4. Verify signature
        sig_valid, sig_error = signature_service.verify_signature(
            method, path, timestamp, signature, body
        )
        self.assertTrue(sig_valid, f"Signature validation failed: {sig_error}")
        
        # 5. Attempt replay (should fail)
        replay_valid, replay_error = nonce_service.validate_nonce(nonce)
        self.assertFalse(replay_valid, "Replay should be rejected")


if __name__ == '__main__':
    # Run tests
    unittest.main(verbosity=2)
