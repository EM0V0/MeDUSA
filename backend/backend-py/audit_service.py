"""
MeDUSA Audit Logging Service

This module provides comprehensive audit logging for security events,
compliant with FDA cybersecurity requirements and ISO 14971 risk management.

Key Features:
- Security event logging (authentication, authorization, data access)
- Structured JSON log format for CloudWatch analysis
- PII protection (sensitive data masking)
- Tamper-evident timestamps
- Event categorization for compliance reporting
"""

import os
import json
import time
import hashlib
from datetime import datetime, timezone
from typing import Optional, Dict, Any, List
from enum import Enum


class AuditEventType(Enum):
    """
    Categorized audit event types aligned with FDA cybersecurity requirements.
    """
    # Authentication Events
    AUTH_LOGIN_SUCCESS = "AUTH_LOGIN_SUCCESS"
    AUTH_LOGIN_FAILURE = "AUTH_LOGIN_FAILURE"
    AUTH_LOGOUT = "AUTH_LOGOUT"
    AUTH_TOKEN_REFRESH = "AUTH_TOKEN_REFRESH"
    AUTH_MFA_CHALLENGE = "AUTH_MFA_CHALLENGE"
    AUTH_MFA_SUCCESS = "AUTH_MFA_SUCCESS"
    AUTH_MFA_FAILURE = "AUTH_MFA_FAILURE"
    MFA_SETUP_INITIATED = "MFA_SETUP_INITIATED"
    MFA_ENABLED = "MFA_ENABLED"
    MFA_DISABLED = "MFA_DISABLED"
    MFA_CHALLENGE = "MFA_CHALLENGE"
    MFA_SUCCESS = "MFA_SUCCESS"
    MFA_FAILURE = "MFA_FAILURE"
    AUTH_PASSWORD_CHANGE = "AUTH_PASSWORD_CHANGE"
    AUTH_PASSWORD_RESET = "AUTH_PASSWORD_RESET"
    
    # Authorization Events
    AUTHZ_ACCESS_GRANTED = "AUTHZ_ACCESS_GRANTED"
    AUTHZ_ACCESS_DENIED = "AUTHZ_ACCESS_DENIED"
    AUTHZ_ROLE_ESCALATION_ATTEMPT = "AUTHZ_ROLE_ESCALATION_ATTEMPT"
    
    # Data Access Events
    DATA_READ = "DATA_READ"
    DATA_CREATE = "DATA_CREATE"
    DATA_UPDATE = "DATA_UPDATE"
    DATA_DELETE = "DATA_DELETE"
    DATA_EXPORT = "DATA_EXPORT"
    
    # Patient Data Events
    PATIENT_DATA_ACCESS = "PATIENT_DATA_ACCESS"
    PATIENT_PROFILE_UPDATE = "PATIENT_PROFILE_UPDATE"
    PATIENT_ASSIGNMENT = "PATIENT_ASSIGNMENT"
    
    # Device Events
    DEVICE_REGISTER = "DEVICE_REGISTER"
    DEVICE_BIND = "DEVICE_BIND"
    DEVICE_UNBIND = "DEVICE_UNBIND"
    DEVICE_DATA_RECEIVED = "DEVICE_DATA_RECEIVED"
    
    # Session Events
    SESSION_CREATE = "SESSION_CREATE"
    SESSION_END = "SESSION_END"
    
    # Security Events
    SECURITY_RATE_LIMIT_EXCEEDED = "SECURITY_RATE_LIMIT_EXCEEDED"
    SECURITY_INVALID_TOKEN = "SECURITY_INVALID_TOKEN"
    SECURITY_SUSPICIOUS_ACTIVITY = "SECURITY_SUSPICIOUS_ACTIVITY"
    
    # System Events
    SYSTEM_ERROR = "SYSTEM_ERROR"
    SYSTEM_CONFIG_CHANGE = "SYSTEM_CONFIG_CHANGE"


class AuditSeverity(Enum):
    """
    Severity levels for audit events.
    """
    DEBUG = "DEBUG"
    INFO = "INFO"
    WARNING = "WARNING"
    ERROR = "ERROR"
    CRITICAL = "CRITICAL"


class AuditService:
    """
    Centralized audit logging service for MeDUSA platform.
    
    Provides structured, compliant audit logging with:
    - Consistent JSON format for CloudWatch Logs Insights
    - PII protection through data masking
    - Event correlation via request IDs
    - Tamper-evident timestamps with hash chains
    """
    
    # Fields that should be masked for PII protection
    SENSITIVE_FIELDS = {
        'password', 'new_password', 'current_password', 'token',
        'access_token', 'refresh_token', 'mfa_secret', 'verification_code',
        'ssn', 'social_security', 'credit_card', 'bank_account'
    }
    
    # Fields to partially mask (show first/last chars)
    PARTIAL_MASK_FIELDS = {
        'email': (3, 4),  # Show first 3 and last 4 chars
        'phone': (0, 4),  # Show last 4 digits
    }
    
    def __init__(self, service_name: str = "medusa-api"):
        """
        Initialize the audit service.
        
        Args:
            service_name: Name of the service for log identification
        """
        self.service_name = service_name
        self.environment = os.environ.get("ENVIRONMENT", "production")
        self._last_hash = None
    
    def _mask_sensitive_data(self, data: Dict[str, Any]) -> Dict[str, Any]:
        """
        Mask sensitive data fields to protect PII.
        
        Args:
            data: Dictionary containing potentially sensitive data
            
        Returns:
            Dictionary with sensitive fields masked
        """
        if not data:
            return data
            
        masked = {}
        for key, value in data.items():
            key_lower = key.lower()
            
            # Full masking for highly sensitive fields
            if key_lower in self.SENSITIVE_FIELDS:
                masked[key] = "***REDACTED***"
            # Partial masking for identifiable fields
            elif key_lower in self.PARTIAL_MASK_FIELDS and isinstance(value, str):
                start_show, end_show = self.PARTIAL_MASK_FIELDS[key_lower]
                if len(value) > start_show + end_show:
                    masked[key] = value[:start_show] + "***" + value[-end_show:]
                else:
                    masked[key] = "***"
            # Recursive masking for nested dictionaries
            elif isinstance(value, dict):
                masked[key] = self._mask_sensitive_data(value)
            else:
                masked[key] = value
                
        return masked
    
    def _generate_event_hash(self, event_data: Dict[str, Any]) -> str:
        """
        Generate a hash for event integrity verification.
        Creates a chain with previous hash for tamper evidence.
        
        Args:
            event_data: The event data to hash
            
        Returns:
            SHA-256 hash string
        """
        hash_input = json.dumps(event_data, sort_keys=True, default=str)
        if self._last_hash:
            hash_input = self._last_hash + hash_input
        
        event_hash = hashlib.sha256(hash_input.encode()).hexdigest()[:16]
        self._last_hash = event_hash
        return event_hash
    
    def _get_severity_for_event(self, event_type: AuditEventType) -> AuditSeverity:
        """
        Determine appropriate severity level for event type.
        
        Args:
            event_type: The type of audit event
            
        Returns:
            Appropriate severity level
        """
        # Critical severity events
        critical_events = {
            AuditEventType.AUTHZ_ROLE_ESCALATION_ATTEMPT,
            AuditEventType.SECURITY_SUSPICIOUS_ACTIVITY,
        }
        
        # Error severity events
        error_events = {
            AuditEventType.AUTH_LOGIN_FAILURE,
            AuditEventType.AUTH_MFA_FAILURE,
            AuditEventType.AUTHZ_ACCESS_DENIED,
            AuditEventType.SECURITY_INVALID_TOKEN,
            AuditEventType.SYSTEM_ERROR,
        }
        
        # Warning severity events
        warning_events = {
            AuditEventType.SECURITY_RATE_LIMIT_EXCEEDED,
            AuditEventType.DATA_DELETE,
            AuditEventType.DEVICE_UNBIND,
        }
        
        if event_type in critical_events:
            return AuditSeverity.CRITICAL
        elif event_type in error_events:
            return AuditSeverity.ERROR
        elif event_type in warning_events:
            return AuditSeverity.WARNING
        else:
            return AuditSeverity.INFO
    
    def log_event(
        self,
        event_type: AuditEventType,
        user_id: Optional[str] = None,
        user_role: Optional[str] = None,
        resource_type: Optional[str] = None,
        resource_id: Optional[str] = None,
        action: Optional[str] = None,
        outcome: str = "success",
        details: Optional[Dict[str, Any]] = None,
        request_id: Optional[str] = None,
        ip_address: Optional[str] = None,
        user_agent: Optional[str] = None,
        severity: Optional[AuditSeverity] = None
    ) -> Dict[str, Any]:
        """
        Log an audit event with structured data.
        
        Args:
            event_type: Type of audit event
            user_id: ID of the user performing the action
            user_role: Role of the user (admin/doctor/patient)
            resource_type: Type of resource being accessed (patient/device/session)
            resource_id: ID of the specific resource
            action: Specific action being performed
            outcome: Outcome of the action (success/failure/denied)
            details: Additional event-specific details
            request_id: Correlation ID for request tracking
            ip_address: Client IP address
            user_agent: Client user agent string
            severity: Override automatic severity determination
            
        Returns:
            The complete audit log entry
        """
        # Generate timestamp with microsecond precision
        timestamp = datetime.now(timezone.utc)
        
        # Determine severity
        if severity is None:
            severity = self._get_severity_for_event(event_type)
        
        # Build the audit entry
        audit_entry = {
            # Event identification
            "log_type": "AUDIT",
            "service": self.service_name,
            "environment": self.environment,
            "timestamp": timestamp.isoformat(),
            "timestamp_unix": int(timestamp.timestamp() * 1000),  # Milliseconds
            
            # Event classification
            "event_type": event_type.value,
            "severity": severity.value,
            "outcome": outcome,
            
            # Actor information
            "actor": {
                "user_id": user_id,
                "role": user_role,
                "ip_address": ip_address,
                "user_agent": user_agent,
            },
            
            # Resource information
            "resource": {
                "type": resource_type,
                "id": resource_id,
            },
            
            # Action details
            "action": action,
            "details": self._mask_sensitive_data(details) if details else None,
            
            # Correlation and integrity
            "request_id": request_id,
        }
        
        # Add event hash for integrity verification
        audit_entry["event_hash"] = self._generate_event_hash(audit_entry)
        
        # Output the log (CloudWatch will capture stdout)
        log_line = json.dumps(audit_entry, default=str)
        print(f"[AUDIT] {log_line}")
        
        return audit_entry
    
    # Convenience methods for common events
    
    def log_login_success(
        self,
        user_id: str,
        user_role: str,
        ip_address: Optional[str] = None,
        user_agent: Optional[str] = None,
        request_id: Optional[str] = None
    ):
        """Log successful login event."""
        return self.log_event(
            event_type=AuditEventType.AUTH_LOGIN_SUCCESS,
            user_id=user_id,
            user_role=user_role,
            action="login",
            outcome="success",
            ip_address=ip_address,
            user_agent=user_agent,
            request_id=request_id
        )
    
    def log_login_failure(
        self,
        email: str,
        reason: str,
        ip_address: Optional[str] = None,
        user_agent: Optional[str] = None,
        request_id: Optional[str] = None
    ):
        """Log failed login attempt."""
        return self.log_event(
            event_type=AuditEventType.AUTH_LOGIN_FAILURE,
            action="login",
            outcome="failure",
            details={"email": email, "reason": reason},
            ip_address=ip_address,
            user_agent=user_agent,
            request_id=request_id
        )
    
    def log_access_denied(
        self,
        user_id: str,
        user_role: str,
        resource_type: str,
        resource_id: str,
        required_role: str,
        request_id: Optional[str] = None
    ):
        """Log access denied event."""
        return self.log_event(
            event_type=AuditEventType.AUTHZ_ACCESS_DENIED,
            user_id=user_id,
            user_role=user_role,
            resource_type=resource_type,
            resource_id=resource_id,
            action="access",
            outcome="denied",
            details={"required_role": required_role},
            request_id=request_id
        )
    
    def log_patient_data_access(
        self,
        user_id: str,
        user_role: str,
        patient_id: str,
        data_type: str,
        action: str = "read",
        request_id: Optional[str] = None
    ):
        """Log patient data access event."""
        return self.log_event(
            event_type=AuditEventType.PATIENT_DATA_ACCESS,
            user_id=user_id,
            user_role=user_role,
            resource_type="patient",
            resource_id=patient_id,
            action=action,
            outcome="success",
            details={"data_type": data_type},
            request_id=request_id
        )
    
    def log_device_event(
        self,
        event_type: AuditEventType,
        user_id: str,
        user_role: str,
        device_id: str,
        patient_id: Optional[str] = None,
        action: str = None,
        details: Optional[Dict[str, Any]] = None,
        request_id: Optional[str] = None
    ):
        """Log device-related event."""
        return self.log_event(
            event_type=event_type,
            user_id=user_id,
            user_role=user_role,
            resource_type="device",
            resource_id=device_id,
            action=action,
            outcome="success",
            details={"patient_id": patient_id, **(details or {})},
            request_id=request_id
        )
    
    def log_session_event(
        self,
        event_type: AuditEventType,
        user_id: str,
        user_role: str,
        session_id: str,
        device_id: str,
        patient_id: str,
        action: str = None,
        request_id: Optional[str] = None
    ):
        """Log measurement session event."""
        return self.log_event(
            event_type=event_type,
            user_id=user_id,
            user_role=user_role,
            resource_type="session",
            resource_id=session_id,
            action=action,
            outcome="success",
            details={"device_id": device_id, "patient_id": patient_id},
            request_id=request_id
        )
    
    def log_security_event(
        self,
        event_type: AuditEventType,
        description: str,
        user_id: Optional[str] = None,
        ip_address: Optional[str] = None,
        details: Optional[Dict[str, Any]] = None,
        request_id: Optional[str] = None
    ):
        """Log security-related event."""
        return self.log_event(
            event_type=event_type,
            user_id=user_id,
            action=description,
            outcome="detected",
            ip_address=ip_address,
            details=details,
            request_id=request_id
        )


# Global audit service instance
audit_service = AuditService()


# Convenience functions for direct import
def log_audit(
    event_type: AuditEventType,
    **kwargs
) -> Dict[str, Any]:
    """
    Convenience function for logging audit events.
    
    Usage:
        from audit_service import log_audit, AuditEventType
        
        log_audit(
            AuditEventType.AUTH_LOGIN_SUCCESS,
            user_id="usr_123",
            user_role="patient"
        )
    """
    return audit_service.log_event(event_type, **kwargs)
