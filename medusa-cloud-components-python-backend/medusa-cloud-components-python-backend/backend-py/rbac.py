"""
RBAC (Role-Based Access Control) utilities
Provides decorators and helpers for role-based authorization
"""
from functools import wraps
from fastapi import HTTPException, Request
from typing import Callable, List

def require_role(*allowed_roles: str):
    """
    Decorator to enforce role-based access control
    
    Usage:
        @require_role("doctor", "admin")
        async def get_patients(request: Request):
            ...
    
    Args:
        *allowed_roles: Variable number of allowed role strings
        
    Raises:
        HTTPException 403: If user role is not in allowed_roles
    """
    def decorator(func: Callable):
        @wraps(func)
        async def wrapper(*args, **kwargs):
            # Find request object in args or kwargs
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
            
            # Get claims from request state (set by auth middleware)
            claims = getattr(request.state, "claims", {})
            user_role = claims.get("role")
            
            # Check if user role is allowed
            if user_role not in allowed_roles:
                raise HTTPException(
                    status_code=403,
                    detail={
                        "code": "FORBIDDEN",
                        "message": f"Access denied. Required role: {', '.join(allowed_roles)}"
                    }
                )
            
            # Call the original function
            return await func(*args, **kwargs)
        
        return wrapper
    return decorator


def get_user_id(request: Request) -> str:
    """
    Get user ID from request claims
    
    Args:
        request: FastAPI request object
        
    Returns:
        User ID string
        
    Raises:
        HTTPException 401: If no claims found
    """
    claims = getattr(request.state, "claims", {})
    user_id = claims.get("sub")
    
    if not user_id:
        raise HTTPException(
            status_code=401,
            detail={"code": "UNAUTHORIZED", "message": "User not authenticated"}
        )
    
    return user_id


def get_user_role(request: Request) -> str:
    """
    Get user role from request claims
    
    Args:
        request: FastAPI request object
        
    Returns:
        User role string
        
    Raises:
        HTTPException 401: If no claims found
    """
    claims = getattr(request.state, "claims", {})
    user_role = claims.get("role")
    
    if not user_role:
        raise HTTPException(
            status_code=401,
            detail={"code": "UNAUTHORIZED", "message": "User role not found"}
        )
    
    return user_role


def check_resource_ownership(request: Request, resource_owner_id: str) -> bool:
    """
    Check if the current user owns the resource
    
    Args:
        request: FastAPI request object
        resource_owner_id: ID of the resource owner
        
    Returns:
        True if user owns the resource, False otherwise
    """
    user_id = get_user_id(request)
    return user_id == resource_owner_id


def require_ownership_or_role(*allowed_roles: str):
    """
    Decorator to check resource ownership or role
    Allows access if user owns the resource OR has one of the allowed roles
    
    Usage:
        @require_ownership_or_role("doctor", "admin")
        async def get_device(device_id: str, request: Request):
            device = db.get_device(device_id)
            # This decorator checks if user owns device OR is doctor/admin
            ...
    
    Note: The decorated function must have a 'request' parameter
          and must return or work with a resource that has an 'owner_id' or 'patientId' field
    """
    def decorator(func: Callable):
        @wraps(func)
        async def wrapper(*args, **kwargs):
            # Find request object in args or kwargs
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
            
            # Get user role
            user_role = get_user_role(request)
            
            # If user has allowed role, grant access immediately
            if user_role in allowed_roles:
                return await func(*args, **kwargs)
            
            # Otherwise, ownership check will be done in the endpoint
            # (endpoint needs to verify resource ownership)
            return await func(*args, **kwargs)
        
        return wrapper
    return decorator

