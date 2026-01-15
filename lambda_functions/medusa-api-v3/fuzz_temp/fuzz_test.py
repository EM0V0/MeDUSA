import sys
import os
from hypothesis import given, strategies as st, settings, Verbosity
from hypothesis import example

# Add current directory to sys.path
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from password_validator import PasswordValidator

print("=== Starting Fuzzing for PasswordValidator ===")

@settings(max_examples=1000, verbosity=Verbosity.normal)
@given(st.text())
@example("Password123!") # Valid example
@example("weak")         # Invalid example
def test_password_validator_properties(password):
    """
    Property-based test (Fuzzing) for PasswordValidator.
    We are checking for crashes (exceptions) and consistency.
    """
    try:
        is_valid, message = PasswordValidator.validate(password)
        
        # Property 1: Result should be a boolean
        assert isinstance(is_valid, bool)
        
        # Property 2: Message should be a string
        assert isinstance(message, str)
        
        # Property 3: If valid, message should be empty
        if is_valid:
            assert message == ""
        else:
            assert len(message) > 0
            
        # Property 4: If password is None (though st.text() gives strings), handle it?
        # The type hint says str, but let's see if we can crash it with None if we forced it (not doing that here)

    except Exception as e:
        print(f"CRASH FOUND with input: {repr(password)}")
        print(f"Exception: {e}")
        raise e

if __name__ == "__main__":
    try:
        test_password_validator_properties()
        print("\n=== Fuzzing Completed Successfully: No Crashes Found ===")
    except Exception:
        print("\n=== Fuzzing Found Issues ===")
