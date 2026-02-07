"""
MeDUSA Request Replay Protection Service

This module implements replay attack prevention using:
- Cryptographic nonces with timestamp validation
- Server-side nonce tracking with DynamoDB TTL
- Request signature verification

Compliant with FDA cybersecurity requirements for secure communications.
"""

import os
import time
import uuid
import hmac
import hashlib
import base64
from datetime import datetime, timezone
from typing import Optional, Dict, Any, Tuple
from functools import wraps
from fastapi import Request, HTTPException

# DynamoDB client for nonce storage
import boto3
from botocore.exceptions import ClientError

# Configuration
NONCE_TTL_SECONDS = int(os.environ.get("NONCE_TTL_SECONDS", "300"))  # 5 minutes
NONCE_TABLE = os.environ.get("DDB_TABLE_NONCES", "medusa-nonces-prod")
# Security: HMAC_SECRET must be set - falls back to JWT_SECRET but never to hardcoded value
HMAC_SECRET = os.environ.get("HMAC_SECRET") or os.environ.get("JWT_SECRET")
if not HMAC_SECRET:
    raise ValueError("HMAC_SECRET or JWT_SECRET environment variable must be set")
USE_MEMORY = os.environ.get("USE_MEMORY", "false").lower() == "true"


class NonceService:
    """
    Service for managing request nonces to prevent replay attacks.
    
    Features:
    - Generates cryptographically secure nonces
    - Validates nonce format, timestamp, and uniqueness
    - Stores used nonces with TTL for automatic cleanup
    - Supports both DynamoDB and in-memory storage
    """
    
    def __init__(self):
        """Initialize the nonce service."""
        self._memory_store: Dict[str, int] = {}  # nonce -> timestamp
        self._dynamodb = None
        
        if not USE_MEMORY:
            try:
                self._dynamodb = boto3.resource('dynamodb')
                self._table = self._dynamodb.Table(NONCE_TABLE)
                print(f"[NonceService] Initialized with DynamoDB table: {NONCE_TABLE}")
            except Exception as e:
                print(f"[NonceService] DynamoDB init failed, using memory: {e}")
                self._dynamodb = None
    
    def generate_nonce(self) -> str:
        """
        Generate a cryptographically secure nonce.
        
        Format: timestamp.randomBytes.signature (using dots to avoid base64 conflicts)
        
        Returns:
            Secure nonce string
        """
        timestamp = int(time.time() * 1000)  # Milliseconds
        # Use hex encoding instead of base64 to avoid special characters
        random_hex = os.urandom(16).hex()
        
        # Create signature for tamper protection
        data = f"{timestamp}.{random_hex}"
        signature = hmac.new(
            HMAC_SECRET.encode(),
            data.encode(),
            hashlib.sha256
        ).hexdigest()[:16]
        
        nonce = f"{data}.{signature}"
        return nonce
    
    def validate_nonce(self, nonce: str) -> Tuple[bool, str]:
        """
        Validate a nonce for replay protection.
        
        Checks:
        1. Format is correct (timestamp.randomHex.signature)
        2. Signature is valid (tamper protection)
        3. Timestamp is within validity window
        4. Nonce has not been used before
        
        Args:
            nonce: The nonce string to validate
            
        Returns:
            Tuple of (is_valid, error_message)
        """
        if not nonce:
            return False, "Nonce is required"
        
        # Parse nonce components (using dots as separator)
        parts = nonce.split('.')
        if len(parts) != 3:
            return False, "Invalid nonce format"
        
        try:
            timestamp_str, random_part, signature = parts
            timestamp = int(timestamp_str)
        except (ValueError, IndexError):
            return False, "Invalid nonce format"
        
        # Verify signature (tamper protection)
        expected_data = f"{timestamp_str}.{random_part}"
        expected_signature = hmac.new(
            HMAC_SECRET.encode(),
            expected_data.encode(),
            hashlib.sha256
        ).hexdigest()[:16]
        
        if not hmac.compare_digest(signature, expected_signature):
            return False, "Invalid nonce signature"
        
        # Check timestamp validity (within TTL window)
        current_time = int(time.time() * 1000)
        age_seconds = (current_time - timestamp) / 1000
        
        if age_seconds < 0:
            return False, "Nonce timestamp is in the future"
        
        if age_seconds > NONCE_TTL_SECONDS:
            return False, f"Nonce expired (age: {age_seconds:.1f}s, max: {NONCE_TTL_SECONDS}s)"
        
        # Check if nonce has been used (replay attack detection)
        if self._is_nonce_used(nonce):
            return False, "Nonce already used (potential replay attack)"
        
        # Mark nonce as used
        self._mark_nonce_used(nonce, timestamp)
        
        return True, ""
    
    def _is_nonce_used(self, nonce: str) -> bool:
        """Check if a nonce has been used before."""
        if self._dynamodb:
            try:
                response = self._table.get_item(Key={'nonce': nonce})
                return 'Item' in response
            except ClientError as e:
                print(f"[NonceService] DynamoDB read error: {e}")
                # Fall back to memory check
                return nonce in self._memory_store
        else:
            return nonce in self._memory_store
    
    def _mark_nonce_used(self, nonce: str, timestamp: int):
        """Mark a nonce as used to prevent replay."""
        ttl = int(time.time()) + NONCE_TTL_SECONDS + 60  # Add buffer
        
        if self._dynamodb:
            try:
                self._table.put_item(
                    Item={
                        'nonce': nonce,
                        'timestamp': timestamp,
                        'ttl': ttl,  # DynamoDB TTL for automatic cleanup
                        'createdAt': datetime.now(timezone.utc).isoformat()
                    }
                )
            except ClientError as e:
                print(f"[NonceService] DynamoDB write error: {e}")
                # Fall back to memory
                self._memory_store[nonce] = timestamp
        else:
            self._memory_store[nonce] = timestamp
        
        # Clean up old entries from memory store
        self._cleanup_memory_store()
    
    def _cleanup_memory_store(self):
        """Remove expired entries from memory store."""
        if len(self._memory_store) < 1000:
            return
        
        current_time = int(time.time() * 1000)
        cutoff = current_time - (NONCE_TTL_SECONDS * 1000)
        
        expired = [k for k, v in self._memory_store.items() if v < cutoff]
        for key in expired:
            del self._memory_store[key]
        
        print(f"[NonceService] Cleaned up {len(expired)} expired nonces")


class RequestSignatureService:
    """
    Service for request signature verification.
    
    Implements HMAC-based request signing for:
    - Request integrity verification
    - Tamper detection
    - Non-repudiation
    """
    
    @staticmethod
    def sign_request(
        method: str,
        path: str,
        timestamp: str,
        body: Optional[str] = None
    ) -> str:
        """
        Generate a signature for a request.
        
        Args:
            method: HTTP method (GET, POST, etc.)
            path: Request path
            timestamp: ISO 8601 timestamp
            body: Request body (optional)
            
        Returns:
            HMAC-SHA256 signature
        """
        # Build canonical string
        body_hash = ""
        if body:
            body_hash = hashlib.sha256(body.encode()).hexdigest()
        
        canonical = f"{method.upper()}\n{path}\n{timestamp}\n{body_hash}"
        
        # Generate signature
        signature = hmac.new(
            HMAC_SECRET.encode(),
            canonical.encode(),
            hashlib.sha256
        ).hexdigest()
        
        return signature
    
    @staticmethod
    def verify_signature(
        method: str,
        path: str,
        timestamp: str,
        signature: str,
        body: Optional[str] = None
    ) -> Tuple[bool, str]:
        """
        Verify a request signature.
        
        Args:
            method: HTTP method
            path: Request path
            timestamp: ISO 8601 timestamp
            signature: Provided signature
            body: Request body (optional)
            
        Returns:
            Tuple of (is_valid, error_message)
        """
        # Check timestamp freshness
        try:
            request_time = datetime.fromisoformat(timestamp.replace('Z', '+00:00'))
            current_time = datetime.now(timezone.utc)
            age_seconds = (current_time - request_time).total_seconds()
            
            if abs(age_seconds) > NONCE_TTL_SECONDS:
                return False, f"Request timestamp expired (age: {age_seconds:.1f}s)"
        except ValueError:
            return False, "Invalid timestamp format"
        
        # Verify signature
        expected_signature = RequestSignatureService.sign_request(
            method, path, timestamp, body
        )
        
        if not hmac.compare_digest(signature, expected_signature):
            return False, "Invalid request signature"
        
        return True, ""


# Global service instances
nonce_service = NonceService()
signature_service = RequestSignatureService()


def require_nonce(func):
    """
    Decorator to require and validate nonce for replay protection.
    
    Usage:
        @require_nonce
        async def sensitive_endpoint(request: Request):
            ...
    
    The client must include X-Request-Nonce header.
    """
    @wraps(func)
    async def wrapper(*args, **kwargs):
        # Check if replay protection feature is enabled (security education mode)
        from security_config import security_config
        if not security_config.is_feature_enabled("replay_protection"):
            security_config.log_security_check("replay_protection", False,
                f"⚠️ BYPASSED - Replay protection disabled, nonce not checked for {func.__name__}")
            return await func(*args, **kwargs)

        # Find request object
        request = None
        for arg in args:
            if isinstance(arg, Request):
                request = arg
                break
        if not request and 'request' in kwargs:
            request = kwargs['request']
        
        if not request:
            raise HTTPException(
                status_code=500,
                detail={"code": "INTERNAL_ERROR", "message": "Request object not found"}
            )
        
        # Get nonce from header
        nonce = request.headers.get("X-Request-Nonce")
        
        if not nonce:
            raise HTTPException(
                status_code=400,
                detail={
                    "code": "NONCE_REQUIRED",
                    "message": "X-Request-Nonce header is required for this endpoint"
                }
            )
        
        # Validate nonce
        is_valid, error_msg = nonce_service.validate_nonce(nonce)
        
        if not is_valid:
            raise HTTPException(
                status_code=400,
                detail={
                    "code": "INVALID_NONCE",
                    "message": error_msg
                }
            )
        
        return await func(*args, **kwargs)
    
    return wrapper


def require_signed_request(func):
    """
    Decorator to require and verify request signature.
    
    Usage:
        @require_signed_request
        async def critical_endpoint(request: Request):
            ...
    
    Required headers:
    - X-Request-Timestamp: ISO 8601 timestamp
    - X-Request-Signature: HMAC-SHA256 signature
    """
    @wraps(func)
    async def wrapper(*args, **kwargs):
        # Find request object
        request = None
        for arg in args:
            if isinstance(arg, Request):
                request = arg
                break
        if not request and 'request' in kwargs:
            request = kwargs['request']
        
        if not request:
            raise HTTPException(
                status_code=500,
                detail={"code": "INTERNAL_ERROR", "message": "Request object not found"}
            )
        
        # Get signature headers
        timestamp = request.headers.get("X-Request-Timestamp")
        signature = request.headers.get("X-Request-Signature")
        
        if not timestamp or not signature:
            raise HTTPException(
                status_code=400,
                detail={
                    "code": "SIGNATURE_REQUIRED",
                    "message": "X-Request-Timestamp and X-Request-Signature headers are required"
                }
            )
        
        # Get request body for signature verification
        body = None
        if request.method in ["POST", "PUT", "PATCH"]:
            body = await request.body()
            body = body.decode() if body else None
        
        # Verify signature
        is_valid, error_msg = signature_service.verify_signature(
            request.method,
            request.url.path,
            timestamp,
            signature,
            body
        )
        
        if not is_valid:
            raise HTTPException(
                status_code=400,
                detail={
                    "code": "INVALID_SIGNATURE",
                    "message": error_msg
                }
            )
        
        return await func(*args, **kwargs)
    
    return wrapper


# API endpoint to get a fresh nonce (for clients)
def get_nonce_endpoint():
    """
    Generate a fresh nonce for the client.
    
    Returns:
        Dict with nonce and expiration info
    """
    nonce = nonce_service.generate_nonce()
    return {
        "nonce": nonce,
        "expiresIn": NONCE_TTL_SECONDS,
        "algorithm": "HMAC-SHA256"
    }
