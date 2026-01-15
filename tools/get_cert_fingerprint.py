import ssl
import socket
import hashlib

hostname = '7i5ew9xg55.execute-api.us-east-1.amazonaws.com'
port = 443

context = ssl.create_default_context()
with socket.create_connection((hostname, port)) as sock:
    with context.wrap_socket(sock, server_hostname=hostname) as ssock:
        cert = ssock.getpeercert(binary_form=True)
        sha256_fingerprint = hashlib.sha256(cert).hexdigest()
        print(f"SHA-256 Fingerprint: {sha256_fingerprint}")
        
        # Get the full cert details to see the issuer
        cert_dict = ssock.getpeercert()
        print(f"Issuer: {cert_dict.get('issuer')}")
