"""
Test suite for MeDUSA Audit Logging Service

Run with: python -m pytest test_audit_service.py -v
Or simply: python test_audit_service.py
"""

import json
import unittest
from audit_service import (
    AuditService, 
    AuditEventType, 
    AuditSeverity,
    audit_service,
    log_audit
)


class TestAuditService(unittest.TestCase):
    """Test cases for AuditService"""
    
    def setUp(self):
        """Set up test fixtures"""
        self.service = AuditService(service_name="test-medusa-api")
    
    def test_log_event_basic(self):
        """Test basic event logging"""
        entry = self.service.log_event(
            event_type=AuditEventType.AUTH_LOGIN_SUCCESS,
            user_id="usr_test123",
            user_role="patient"
        )
        
        self.assertEqual(entry["log_type"], "AUDIT")
        self.assertEqual(entry["event_type"], "AUTH_LOGIN_SUCCESS")
        self.assertEqual(entry["actor"]["user_id"], "usr_test123")
        self.assertEqual(entry["actor"]["role"], "patient")
        self.assertIn("timestamp", entry)
        self.assertIn("event_hash", entry)
    
    def test_pii_masking_password(self):
        """Test that passwords are fully masked"""
        data = {
            "email": "test@example.com",
            "password": "secretpassword123",
            "name": "John Doe"
        }
        
        masked = self.service._mask_sensitive_data(data)
        
        self.assertEqual(masked["password"], "***REDACTED***")
        self.assertEqual(masked["name"], "John Doe")
    
    def test_pii_masking_email(self):
        """Test that emails are partially masked"""
        data = {
            "email": "testuser@example.com",
        }
        
        masked = self.service._mask_sensitive_data(data)
        
        # Should show first 3 and last 4 characters
        self.assertIn("***", masked["email"])
        self.assertTrue(masked["email"].startswith("tes"))
        self.assertTrue(masked["email"].endswith(".com"))
    
    def test_pii_masking_sensitive_tokens(self):
        """Test that tokens and secrets are masked"""
        data = {
            "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
            "refresh_token": "some_refresh_token",
            "mfa_secret": "JBSWY3DPEHPK3PXP"
        }
        
        masked = self.service._mask_sensitive_data(data)
        
        self.assertEqual(masked["access_token"], "***REDACTED***")
        self.assertEqual(masked["refresh_token"], "***REDACTED***")
        self.assertEqual(masked["mfa_secret"], "***REDACTED***")
    
    def test_severity_determination(self):
        """Test automatic severity level determination"""
        # Critical events
        self.assertEqual(
            self.service._get_severity_for_event(AuditEventType.AUTHZ_ROLE_ESCALATION_ATTEMPT),
            AuditSeverity.CRITICAL
        )
        
        # Error events
        self.assertEqual(
            self.service._get_severity_for_event(AuditEventType.AUTH_LOGIN_FAILURE),
            AuditSeverity.ERROR
        )
        
        # Warning events
        self.assertEqual(
            self.service._get_severity_for_event(AuditEventType.SECURITY_RATE_LIMIT_EXCEEDED),
            AuditSeverity.WARNING
        )
        
        # Info events (default)
        self.assertEqual(
            self.service._get_severity_for_event(AuditEventType.AUTH_LOGIN_SUCCESS),
            AuditSeverity.INFO
        )
    
    def test_event_hash_generation(self):
        """Test event hash generation for integrity"""
        entry1 = self.service.log_event(
            event_type=AuditEventType.DATA_READ,
            user_id="usr_1"
        )
        
        entry2 = self.service.log_event(
            event_type=AuditEventType.DATA_READ,
            user_id="usr_2"
        )
        
        # Each entry should have a unique hash
        self.assertNotEqual(entry1["event_hash"], entry2["event_hash"])
        self.assertEqual(len(entry1["event_hash"]), 16)  # SHA-256 truncated
    
    def test_login_success_convenience_method(self):
        """Test login success convenience method"""
        entry = self.service.log_login_success(
            user_id="usr_doctor123",
            user_role="doctor",
            ip_address="192.168.1.100"
        )
        
        self.assertEqual(entry["event_type"], "AUTH_LOGIN_SUCCESS")
        self.assertEqual(entry["actor"]["user_id"], "usr_doctor123")
        self.assertEqual(entry["actor"]["role"], "doctor")
        self.assertEqual(entry["actor"]["ip_address"], "192.168.1.100")
        self.assertEqual(entry["outcome"], "success")
    
    def test_login_failure_convenience_method(self):
        """Test login failure convenience method"""
        entry = self.service.log_login_failure(
            email="hacker@evil.com",
            reason="invalid_credentials",
            ip_address="10.0.0.1"
        )
        
        self.assertEqual(entry["event_type"], "AUTH_LOGIN_FAILURE")
        self.assertEqual(entry["severity"], "ERROR")
        self.assertEqual(entry["outcome"], "failure")
        # Email should be partially masked in details
        self.assertIn("***", entry["details"]["email"])
    
    def test_access_denied_logging(self):
        """Test access denied event logging"""
        entry = self.service.log_access_denied(
            user_id="usr_patient1",
            user_role="patient",
            resource_type="admin_panel",
            resource_id="admin_dashboard",
            required_role="admin"
        )
        
        self.assertEqual(entry["event_type"], "AUTHZ_ACCESS_DENIED")
        self.assertEqual(entry["outcome"], "denied")
        self.assertEqual(entry["resource"]["type"], "admin_panel")
    
    def test_patient_data_access_logging(self):
        """Test patient data access logging"""
        entry = self.service.log_patient_data_access(
            user_id="usr_doctor1",
            user_role="doctor",
            patient_id="PAT-001",
            data_type="tremor_analysis"
        )
        
        self.assertEqual(entry["event_type"], "PATIENT_DATA_ACCESS")
        self.assertEqual(entry["resource"]["id"], "PAT-001")
        self.assertEqual(entry["details"]["data_type"], "tremor_analysis")
    
    def test_global_audit_service_instance(self):
        """Test global audit service singleton"""
        self.assertIsInstance(audit_service, AuditService)
    
    def test_log_audit_convenience_function(self):
        """Test log_audit convenience function"""
        entry = log_audit(
            AuditEventType.DEVICE_REGISTER,
            user_id="usr_admin1",
            user_role="admin",
            resource_type="device",
            resource_id="DEV-001"
        )
        
        self.assertEqual(entry["event_type"], "DEVICE_REGISTER")
        self.assertEqual(entry["resource"]["id"], "DEV-001")
    
    def test_nested_data_masking(self):
        """Test masking of nested sensitive data"""
        data = {
            "user": {
                "email": "nested@test.com",
                "password": "nestedsecret"
            },
            "metadata": {
                "token": "should_be_masked"
            }
        }
        
        masked = self.service._mask_sensitive_data(data)
        
        self.assertEqual(masked["user"]["password"], "***REDACTED***")
        self.assertEqual(masked["metadata"]["token"], "***REDACTED***")
    
    def test_empty_data_handling(self):
        """Test handling of empty/None data"""
        self.assertIsNone(self.service._mask_sensitive_data(None))
        self.assertEqual(self.service._mask_sensitive_data({}), {})
    
    def test_all_event_types_have_severity(self):
        """Ensure all event types can get a severity"""
        for event_type in AuditEventType:
            severity = self.service._get_severity_for_event(event_type)
            self.assertIsInstance(severity, AuditSeverity)


class TestAuditEventTypes(unittest.TestCase):
    """Test AuditEventType enum coverage"""
    
    def test_authentication_events_exist(self):
        """Verify authentication event types exist"""
        auth_events = [
            AuditEventType.AUTH_LOGIN_SUCCESS,
            AuditEventType.AUTH_LOGIN_FAILURE,
            AuditEventType.AUTH_LOGOUT,
            AuditEventType.AUTH_TOKEN_REFRESH,
            AuditEventType.AUTH_PASSWORD_CHANGE,
        ]
        for event in auth_events:
            self.assertIn(event, AuditEventType)
    
    def test_authorization_events_exist(self):
        """Verify authorization event types exist"""
        authz_events = [
            AuditEventType.AUTHZ_ACCESS_GRANTED,
            AuditEventType.AUTHZ_ACCESS_DENIED,
            AuditEventType.AUTHZ_ROLE_ESCALATION_ATTEMPT,
        ]
        for event in authz_events:
            self.assertIn(event, AuditEventType)
    
    def test_data_events_exist(self):
        """Verify data event types exist"""
        data_events = [
            AuditEventType.DATA_READ,
            AuditEventType.DATA_CREATE,
            AuditEventType.DATA_UPDATE,
            AuditEventType.DATA_DELETE,
        ]
        for event in data_events:
            self.assertIn(event, AuditEventType)


if __name__ == "__main__":
    print("=" * 60)
    print("MeDUSA Audit Service Test Suite")
    print("=" * 60)
    
    # Run tests
    unittest.main(verbosity=2)
