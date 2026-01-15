import socket
import ssl

hostname = 'zcrqexrdw1.execute-api.us-east-1.amazonaws.com'
port = 443

# Create a context that supports TLS 1.2 and 1.3
context = ssl.create_default_context()

print(f"Connecting to {hostname}:{port}...")

try:
    with socket.create_connection((hostname, port)) as sock:
        with context.wrap_socket(sock, server_hostname=hostname) as ssock:
            print(f"Connected!")
            print(f"TLS Protocol: {ssock.version()}")
            cipher_info = ssock.cipher()
            print(f"Cipher Suite: {cipher_info[0]}")
            print(f"Protocol Version: {cipher_info[1]}")
            print(f"Secret Bits: {cipher_info[2]}")
except Exception as e:
    print(f"Connection failed: {e}")
