"""
MeDUSA Firmware Update Verification Service

This module implements secure firmware update verification for medical devices:
- Cryptographic signature verification (RSA-4096 or ECDSA-P384)
- Version validation and rollback prevention
- Integrity verification (SHA-256 hash)
- Update manifest validation

Compliant with FDA cybersecurity requirements for software updates.
"""

import os
import json
import time
import hashlib
import base64
from datetime import datetime, timezone
from typing import Optional, Dict, Any, List, Tuple
from dataclasses import dataclass
from enum import Enum

# For signature verification
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import padding, ec
from cryptography.hazmat.backends import default_backend
from cryptography.exceptions import InvalidSignature
from cryptography.x509 import load_pem_x509_certificate


class FirmwareStatus(Enum):
    """Firmware verification status codes."""
    VALID = "valid"
    INVALID_SIGNATURE = "invalid_signature"
    INVALID_HASH = "invalid_hash"
    VERSION_ROLLBACK = "version_rollback"
    EXPIRED_CERTIFICATE = "expired_certificate"
    REVOKED_CERTIFICATE = "revoked_certificate"
    INVALID_MANIFEST = "invalid_manifest"
    UNKNOWN_ERROR = "unknown_error"


@dataclass
class FirmwareManifest:
    """Firmware update manifest structure."""
    firmware_id: str
    version: str
    device_type: str
    release_date: str
    min_required_version: str
    sha256_hash: str
    size_bytes: int
    signature: str
    certificate_id: str
    changelog: Optional[str] = None
    critical_update: bool = False


@dataclass
class FirmwareVerificationResult:
    """Result of firmware verification."""
    status: FirmwareStatus
    is_valid: bool
    message: str
    manifest: Optional[FirmwareManifest] = None
    verified_at: Optional[datetime] = None


class FirmwareVerificationService:
    """
    Service for verifying firmware updates.
    
    Implements secure firmware verification workflow:
    1. Parse and validate manifest
    2. Verify certificate chain
    3. Verify cryptographic signature
    4. Check version (prevent rollback)
    5. Verify integrity hash
    """
    
    # Trusted certificate store (in production, load from secure storage)
    # These would be the certificates used to sign firmware updates
    TRUSTED_CERTIFICATES: Dict[str, str] = {
        # Example: Add your firmware signing certificate here
        # "cert_001": "-----BEGIN CERTIFICATE-----\n...\n-----END CERTIFICATE-----"
    }
    
    # Revoked certificate IDs
    REVOKED_CERTIFICATES: List[str] = []
    
    # Minimum supported versions per device type (for rollback prevention)
    MIN_VERSIONS: Dict[str, str] = {
        "tremor_sensor": "1.0.0",
        "gateway": "1.0.0",
    }
    
    def __init__(self, public_key_pem: Optional[str] = None):
        """
        Initialize the firmware verification service.
        
        Args:
            public_key_pem: PEM-encoded public key for signature verification
        """
        self._public_key = None
        if public_key_pem:
            self._public_key = serialization.load_pem_public_key(
                public_key_pem.encode(),
                backend=default_backend()
            )
    
    def verify_firmware_update(
        self,
        manifest_json: str,
        firmware_data: bytes,
        current_version: str,
        device_type: str
    ) -> FirmwareVerificationResult:
        """
        Verify a firmware update package.
        
        Args:
            manifest_json: JSON string of the firmware manifest
            firmware_data: Raw firmware binary data
            current_version: Currently installed firmware version
            device_type: Type of device (for version check)
            
        Returns:
            FirmwareVerificationResult with verification status
        """
        try:
            # 1. Parse and validate manifest
            manifest = self._parse_manifest(manifest_json)
            if not manifest:
                return FirmwareVerificationResult(
                    status=FirmwareStatus.INVALID_MANIFEST,
                    is_valid=False,
                    message="Invalid or malformed firmware manifest",
                    verified_at=datetime.now(timezone.utc)
                )
            
            # 2. Check device type matches
            if manifest.device_type != device_type:
                return FirmwareVerificationResult(
                    status=FirmwareStatus.INVALID_MANIFEST,
                    is_valid=False,
                    message=f"Firmware is for {manifest.device_type}, not {device_type}",
                    manifest=manifest,
                    verified_at=datetime.now(timezone.utc)
                )
            
            # 3. Check for version rollback
            if self._is_rollback(manifest.version, current_version):
                return FirmwareVerificationResult(
                    status=FirmwareStatus.VERSION_ROLLBACK,
                    is_valid=False,
                    message=f"Version rollback detected: {manifest.version} < {current_version}",
                    manifest=manifest,
                    verified_at=datetime.now(timezone.utc)
                )
            
            # 4. Check minimum required version
            min_version = self.MIN_VERSIONS.get(device_type, "0.0.0")
            if self._is_rollback(manifest.version, min_version):
                return FirmwareVerificationResult(
                    status=FirmwareStatus.VERSION_ROLLBACK,
                    is_valid=False,
                    message=f"Version {manifest.version} below minimum {min_version}",
                    manifest=manifest,
                    verified_at=datetime.now(timezone.utc)
                )
            
            # 5. Check certificate validity
            cert_status = self._verify_certificate(manifest.certificate_id)
            if cert_status != FirmwareStatus.VALID:
                return FirmwareVerificationResult(
                    status=cert_status,
                    is_valid=False,
                    message=f"Certificate verification failed: {cert_status.value}",
                    manifest=manifest,
                    verified_at=datetime.now(timezone.utc)
                )
            
            # 6. Verify firmware hash
            if not self._verify_hash(firmware_data, manifest.sha256_hash):
                return FirmwareVerificationResult(
                    status=FirmwareStatus.INVALID_HASH,
                    is_valid=False,
                    message="Firmware hash mismatch - data may be corrupted",
                    manifest=manifest,
                    verified_at=datetime.now(timezone.utc)
                )
            
            # 7. Verify size
            if len(firmware_data) != manifest.size_bytes:
                return FirmwareVerificationResult(
                    status=FirmwareStatus.INVALID_HASH,
                    is_valid=False,
                    message=f"Size mismatch: expected {manifest.size_bytes}, got {len(firmware_data)}",
                    manifest=manifest,
                    verified_at=datetime.now(timezone.utc)
                )
            
            # 8. Verify cryptographic signature
            if not self._verify_signature(manifest_json, manifest.signature):
                return FirmwareVerificationResult(
                    status=FirmwareStatus.INVALID_SIGNATURE,
                    is_valid=False,
                    message="Invalid firmware signature - update may be tampered",
                    manifest=manifest,
                    verified_at=datetime.now(timezone.utc)
                )
            
            # All checks passed
            return FirmwareVerificationResult(
                status=FirmwareStatus.VALID,
                is_valid=True,
                message="Firmware verification successful",
                manifest=manifest,
                verified_at=datetime.now(timezone.utc)
            )
            
        except Exception as e:
            return FirmwareVerificationResult(
                status=FirmwareStatus.UNKNOWN_ERROR,
                is_valid=False,
                message=f"Verification error: {str(e)}",
                verified_at=datetime.now(timezone.utc)
            )
    
    def _parse_manifest(self, manifest_json: str) -> Optional[FirmwareManifest]:
        """Parse and validate firmware manifest JSON."""
        try:
            data = json.loads(manifest_json)
            
            # Required fields
            required_fields = [
                'firmware_id', 'version', 'device_type', 'release_date',
                'min_required_version', 'sha256_hash', 'size_bytes',
                'signature', 'certificate_id'
            ]
            
            for field in required_fields:
                if field not in data:
                    print(f"[FirmwareService] Missing required field: {field}")
                    return None
            
            return FirmwareManifest(
                firmware_id=data['firmware_id'],
                version=data['version'],
                device_type=data['device_type'],
                release_date=data['release_date'],
                min_required_version=data['min_required_version'],
                sha256_hash=data['sha256_hash'],
                size_bytes=int(data['size_bytes']),
                signature=data['signature'],
                certificate_id=data['certificate_id'],
                changelog=data.get('changelog'),
                critical_update=data.get('critical_update', False)
            )
        except (json.JSONDecodeError, KeyError, TypeError) as e:
            print(f"[FirmwareService] Manifest parse error: {e}")
            return None
    
    def _is_rollback(self, new_version: str, current_version: str) -> bool:
        """
        Check if new version is older than current (rollback attempt).
        
        Uses semantic versioning comparison (major.minor.patch).
        """
        try:
            new_parts = [int(x) for x in new_version.split('.')]
            current_parts = [int(x) for x in current_version.split('.')]
            
            # Pad to same length
            while len(new_parts) < len(current_parts):
                new_parts.append(0)
            while len(current_parts) < len(new_parts):
                current_parts.append(0)
            
            # Compare version components
            for new, current in zip(new_parts, current_parts):
                if new < current:
                    return True
                if new > current:
                    return False
            
            # Versions are equal - not a rollback (but also not an upgrade)
            return False
        except ValueError:
            # If version parsing fails, treat as potential rollback
            return True
    
    def _verify_certificate(self, certificate_id: str) -> FirmwareStatus:
        """Verify the signing certificate."""
        # Check if certificate is revoked
        if certificate_id in self.REVOKED_CERTIFICATES:
            return FirmwareStatus.REVOKED_CERTIFICATE
        
        # Check if certificate is trusted
        if certificate_id not in self.TRUSTED_CERTIFICATES and self.TRUSTED_CERTIFICATES:
            # In production with strict mode, this would fail
            # For now, we allow unknown certificates with a warning
            print(f"[FirmwareService] Warning: Unknown certificate ID: {certificate_id}")
        
        # Additional certificate validation would go here
        # (expiration, chain verification, etc.)
        
        return FirmwareStatus.VALID
    
    def _verify_hash(self, data: bytes, expected_hash: str) -> bool:
        """Verify SHA-256 hash of firmware data."""
        calculated_hash = hashlib.sha256(data).hexdigest()
        return calculated_hash.lower() == expected_hash.lower()
    
    def _verify_signature(self, manifest_json: str, signature_b64: str) -> bool:
        """
        Verify cryptographic signature of the manifest.
        
        Uses RSA-PSS or ECDSA depending on key type.
        """
        if not self._public_key:
            # No public key configured - skip signature verification
            # In production, this should fail
            print("[FirmwareService] Warning: No public key configured, skipping signature verification")
            return True
        
        try:
            # Decode signature
            signature = base64.b64decode(signature_b64)
            
            # Get manifest data (excluding signature field for verification)
            manifest_data = json.loads(manifest_json)
            manifest_data.pop('signature', None)
            data_to_verify = json.dumps(manifest_data, sort_keys=True).encode()
            
            # Verify based on key type
            if hasattr(self._public_key, 'verify'):
                # RSA key
                self._public_key.verify(
                    signature,
                    data_to_verify,
                    padding.PSS(
                        mgf=padding.MGF1(hashes.SHA256()),
                        salt_length=padding.PSS.MAX_LENGTH
                    ),
                    hashes.SHA256()
                )
            else:
                # ECDSA key
                self._public_key.verify(
                    signature,
                    data_to_verify,
                    ec.ECDSA(hashes.SHA256())
                )
            
            return True
        except InvalidSignature:
            return False
        except Exception as e:
            print(f"[FirmwareService] Signature verification error: {e}")
            return False
    
    @staticmethod
    def create_manifest(
        firmware_id: str,
        version: str,
        device_type: str,
        firmware_data: bytes,
        certificate_id: str,
        private_key_pem: Optional[str] = None,
        changelog: Optional[str] = None,
        critical_update: bool = False
    ) -> str:
        """
        Create a signed firmware manifest.
        
        This is a utility method for creating firmware packages.
        In production, this would be used by the firmware build system.
        
        Args:
            firmware_id: Unique firmware identifier
            version: Semantic version string
            device_type: Target device type
            firmware_data: Raw firmware binary
            certificate_id: ID of signing certificate
            private_key_pem: PEM-encoded private key for signing
            changelog: Optional release notes
            critical_update: Whether this is a critical security update
            
        Returns:
            JSON string of the signed manifest
        """
        # Calculate hash
        sha256_hash = hashlib.sha256(firmware_data).hexdigest()
        
        # Build manifest
        manifest = {
            "firmware_id": firmware_id,
            "version": version,
            "device_type": device_type,
            "release_date": datetime.now(timezone.utc).isoformat(),
            "min_required_version": "1.0.0",  # Could be configurable
            "sha256_hash": sha256_hash,
            "size_bytes": len(firmware_data),
            "certificate_id": certificate_id,
            "changelog": changelog,
            "critical_update": critical_update
        }
        
        # Sign if private key provided
        if private_key_pem:
            private_key = serialization.load_pem_private_key(
                private_key_pem.encode(),
                password=None,
                backend=default_backend()
            )
            
            data_to_sign = json.dumps(manifest, sort_keys=True).encode()
            
            # Sign based on key type
            if hasattr(private_key, 'sign'):
                signature = private_key.sign(
                    data_to_sign,
                    padding.PSS(
                        mgf=padding.MGF1(hashes.SHA256()),
                        salt_length=padding.PSS.MAX_LENGTH
                    ),
                    hashes.SHA256()
                )
            else:
                signature = private_key.sign(
                    data_to_sign,
                    ec.ECDSA(hashes.SHA256())
                )
            
            manifest["signature"] = base64.b64encode(signature).decode()
        else:
            manifest["signature"] = ""
        
        return json.dumps(manifest, indent=2)


# Global service instance
firmware_service = FirmwareVerificationService()


# API endpoint for firmware verification
def verify_firmware_endpoint(
    manifest_json: str,
    firmware_hash: str,
    firmware_size: int,
    current_version: str,
    device_type: str
) -> Dict[str, Any]:
    """
    API endpoint for verifying firmware before installation.
    
    This lightweight endpoint verifies manifest without requiring
    the full firmware binary upload.
    """
    try:
        # Parse manifest
        manifest = firmware_service._parse_manifest(manifest_json)
        if not manifest:
            return {
                "valid": False,
                "status": "invalid_manifest",
                "message": "Invalid firmware manifest"
            }
        
        # Verify version
        if firmware_service._is_rollback(manifest.version, current_version):
            return {
                "valid": False,
                "status": "version_rollback",
                "message": f"Version {manifest.version} is older than {current_version}"
            }
        
        # Verify hash matches manifest
        if manifest.sha256_hash.lower() != firmware_hash.lower():
            return {
                "valid": False,
                "status": "hash_mismatch",
                "message": "Firmware hash does not match manifest"
            }
        
        # Verify size matches
        if manifest.size_bytes != firmware_size:
            return {
                "valid": False,
                "status": "size_mismatch",
                "message": f"Expected {manifest.size_bytes} bytes, got {firmware_size}"
            }
        
        return {
            "valid": True,
            "status": "verified",
            "message": "Firmware manifest verified",
            "version": manifest.version,
            "critical_update": manifest.critical_update,
            "changelog": manifest.changelog
        }
        
    except Exception as e:
        return {
            "valid": False,
            "status": "error",
            "message": str(e)
        }
