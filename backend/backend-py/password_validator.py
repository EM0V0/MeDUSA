"""
Password validation utility for backend
Implements the same validation rules as the Flutter frontend
"""
import re

class PasswordValidator:
    """
    Password strength validator
    Validates passwords according to security requirements
    """
    
    # Configuration (matching Flutter app_constants.dart)
    MIN_LENGTH = 8
    REQUIRE_UPPERCASE = True
    REQUIRE_LOWERCASE = True
    REQUIRE_DIGIT = True
    REQUIRE_SPECIAL_CHAR = True
    SPECIAL_CHARS = '!@#$%^&*()_+-=[]{}|;:,.<>?'
    
    @classmethod
    def validate(cls, password: str) -> tuple[bool, str]:
        """
        Validate password strength
        
        Args:
            password: Password string to validate
            
        Returns:
            Tuple of (is_valid, error_message)
            If valid, error_message is empty string
        """
        if not password:
            return False, "Password is required"
        
        # Check minimum length
        if len(password) < cls.MIN_LENGTH:
            return False, f"Password must be at least {cls.MIN_LENGTH} characters"
        
        # Check uppercase requirement
        if cls.REQUIRE_UPPERCASE and not re.search(r'[A-Z]', password):
            return False, "Password must contain at least one uppercase letter"
        
        # Check lowercase requirement
        if cls.REQUIRE_LOWERCASE and not re.search(r'[a-z]', password):
            return False, "Password must contain at least one lowercase letter"
        
        # Check digit requirement
        if cls.REQUIRE_DIGIT and not re.search(r'[0-9]', password):
            return False, "Password must contain at least one number"
        
        # Check special character requirement
        if cls.REQUIRE_SPECIAL_CHAR:
            special_pattern = f"[{re.escape(cls.SPECIAL_CHARS)}]"
            if not re.search(special_pattern, password):
                return False, f"Password must contain at least one special character ({cls.SPECIAL_CHARS[:10]}...)"
        
        return True, ""
    
    @classmethod
    def is_valid(cls, password: str) -> bool:
        """
        Check if password is valid (simplified version)
        
        Args:
            password: Password string to validate
            
        Returns:
            True if password meets all requirements, False otherwise
        """
        is_valid, _ = cls.validate(password)
        return is_valid
    
    @classmethod
    def get_validation_error(cls, password: str) -> str:
        """
        Get validation error message
        
        Args:
            password: Password string to validate
            
        Returns:
            Error message string, or empty string if valid
        """
        _, error_msg = cls.validate(password)
        return error_msg

