"""
Email service for sending verification codes
Supports multiple email providers (AWS SES, SendGrid, SMTP)
"""
import os
import boto3
from botocore.exceptions import ClientError

class EmailService:
    """
    Email service for sending verification emails
    """
    
    # Email configuration
    SENDER_EMAIL = os.environ.get("SENDER_EMAIL", "noreply@medusa-health.com")
    SENDER_NAME = "MeDUSA Health System"
    
    def __init__(self):
        """Initialize email service with AWS SES"""
        self.ses_client = None
        self.use_ses = os.environ.get("USE_SES", "false").lower() == "true"
        
        if self.use_ses:
            try:
                # Use SES_REGION if provided, otherwise use AWS_REGION (auto-provided by Lambda)
                region = os.environ.get("SES_REGION") or os.environ.get("AWS_REGION", "us-east-1")
                self.ses_client = boto3.client('ses', region_name=region)
                print(f"[EmailService] AWS SES initialized in region: {region}")
            except Exception as e:
                print(f"[EmailService] Failed to initialize AWS SES: {e}")
                self.use_ses = False
    
    def send_verification_code(self, email: str, code: str, code_type: str = "registration") -> bool:
        """
        Send verification code email
        
        Args:
            email: Recipient email address
            code: 6-digit verification code
            code_type: Type of verification (registration or password_reset)
            
        Returns:
            True if email sent successfully, False otherwise
        """
        print(f"[EmailService] send_verification_code called: email={email}, code_type={code_type}")
        print(f"[EmailService] use_ses={self.use_ses}, ses_client={self.ses_client is not None}")
        
        if code_type == "password_reset":
            subject = "Password Reset Verification Code - MeDUSA"
            message = self._generate_password_reset_email(code)
        else:
            subject = "Email Verification Code - MeDUSA"
            message = self._generate_verification_email(code)
        
        print(f"[EmailService] Generated email: subject={subject}, message_length={len(message)}")
        
        if self.use_ses and self.ses_client:
            print(f"[EmailService] Attempting to send via SES...")
            result = self._send_via_ses(email, subject, message)
            print(f"[EmailService] SES send result: {result}")
            return result
        else:
            print(f"[EmailService] Falling back to console logging (use_ses={self.use_ses}, ses_client={self.ses_client is not None})")
            # Fallback to console logging for development
            return self._log_email(email, subject, code)
    
    def _send_via_ses(self, recipient: str, subject: str, html_body: str) -> bool:
        """
        Send email via AWS SES
        
        Args:
            recipient: Recipient email address
            subject: Email subject
            html_body: HTML email body
            
        Returns:
            True if successful, False otherwise
        """
        try:
            # Extract plain text from HTML for better deliverability
            import re
            text_body = re.sub(r'<[^>]+>', '', html_body)  # Strip HTML tags
            text_body = re.sub(r'\s+', ' ', text_body).strip()  # Clean whitespace
            
            response = self.ses_client.send_email(
                Source=f"{self.SENDER_NAME} <{self.SENDER_EMAIL}>",
                Destination={
                    'ToAddresses': [recipient]
                },
                Message={
                    'Subject': {
                        'Data': subject,
                        'Charset': 'UTF-8'
                    },
                    'Body': {
                        'Html': {
                            'Data': html_body,
                            'Charset': 'UTF-8'
                        },
                        'Text': {
                            'Data': text_body,
                            'Charset': 'UTF-8'
                        }
                    }
                },
                # Add configuration set for better tracking (optional)
                # ConfigurationSetName='medusa-email-config'
            )
            print(f"[EmailService] SUCCESS: Email sent successfully to {recipient}")
            print(f"[EmailService] Message ID: {response['MessageId']}")
            print(f"[EmailService] From: {self.SENDER_EMAIL}")
            print(f"[EmailService] To: {recipient}")
            print(f"[EmailService] Subject: {subject}")
            return True
        except ClientError as e:
            error_code = e.response['Error']['Code']
            error_message = e.response['Error']['Message']
            print(f"[EmailService] ERROR: Failed to send email: {error_code} - {error_message}")
            print(f"[EmailService] Recipient: {recipient}")
            print(f"[EmailService] Sender: {self.SENDER_EMAIL}")
            # Log full error for debugging
            import traceback
            print(f"[EmailService] Traceback: {traceback.format_exc()}")
            return False
        except Exception as e:
            print(f"[EmailService] ERROR: Unexpected error sending email: {str(e)}")
            import traceback
            print(f"[EmailService] Traceback: {traceback.format_exc()}")
            return False
    
    def _log_email(self, recipient: str, subject: str, code: str) -> bool:
        """
        Log email to console (development fallback)
        
        Args:
            recipient: Recipient email address
            subject: Email subject
            code: Verification code
            
        Returns:
            Always True (for development)
        """
        print("\n" + "="*60)
        print("[EmailService] EMAIL (Development Mode - Not Actually Sent)")
        print("="*60)
        print(f"To: {recipient}")
        print(f"Subject: {subject}")
        print(f"Verification Code: {code}")
        print("="*60 + "\n")
        return True
    
    def _generate_verification_email(self, code: str) -> str:
        """Generate HTML email for email verification"""
        return f"""
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <style>
                body {{ font-family: Arial, sans-serif; line-height: 1.6; color: #333; }}
                .container {{ max-width: 600px; margin: 0 auto; padding: 20px; }}
                .header {{ background: #1976D2; color: white; padding: 20px; text-align: center; }}
                .content {{ background: #f8f9fa; padding: 30px; border-radius: 5px; }}
                .code {{ font-size: 32px; font-weight: bold; color: #1976D2; text-align: center; 
                         padding: 20px; background: white; border-radius: 5px; margin: 20px 0; 
                         letter-spacing: 5px; }}
                .footer {{ text-align: center; margin-top: 20px; color: #666; font-size: 12px; }}
            </style>
        </head>
        <body>
            <div class="container">
                <div class="header">
                    <h1>MeDUSA Health System</h1>
                    <p>Email Verification</p>
                </div>
                <div class="content">
                    <h2>Verify Your Email Address</h2>
                    <p>Thank you for registering with MeDUSA Health System. To complete your registration, 
                       please use the following verification code:</p>
                    <div class="code">{code}</div>
                    <p>This code will expire in 10 minutes.</p>
                    <p>If you didn't request this verification code, please ignore this email.</p>
                </div>
                <div class="footer">
                    <p>&copy; 2025 MeDUSA Health System. All rights reserved.</p>
                    <p>This is an automated message, please do not reply.</p>
                </div>
            </div>
        </body>
        </html>
        """
    
    def _generate_password_reset_email(self, code: str) -> str:
        """Generate HTML email for password reset"""
        return f"""
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <style>
                body {{ font-family: Arial, sans-serif; line-height: 1.6; color: #333; }}
                .container {{ max-width: 600px; margin: 0 auto; padding: 20px; }}
                .header {{ background: #D32F2F; color: white; padding: 20px; text-align: center; }}
                .content {{ background: #f8f9fa; padding: 30px; border-radius: 5px; }}
                .code {{ font-size: 32px; font-weight: bold; color: #D32F2F; text-align: center; 
                         padding: 20px; background: white; border-radius: 5px; margin: 20px 0; 
                         letter-spacing: 5px; }}
                .warning {{ background: #fff3cd; border-left: 4px solid #ff9800; padding: 15px; 
                           margin: 20px 0; }}
                .footer {{ text-align: center; margin-top: 20px; color: #666; font-size: 12px; }}
            </style>
        </head>
        <body>
            <div class="container">
                <div class="header">
                    <h1>MeDUSA Health System</h1>
                    <p>Password Reset Request</p>
                </div>
                <div class="content">
                    <h2>Reset Your Password</h2>
                    <p>We received a request to reset your password. Use the following verification code 
                       to proceed with the password reset:</p>
                    <div class="code">{code}</div>
                    <p>This code will expire in 10 minutes.</p>
                    <div class="warning">
                        <strong>⚠️ Security Notice:</strong> If you didn't request a password reset, 
                        please ignore this email and ensure your account is secure.
                    </div>
                </div>
                <div class="footer">
                    <p>&copy; 2025 MeDUSA Health System. All rights reserved.</p>
                    <p>This is an automated message, please do not reply.</p>
                </div>
            </div>
        </body>
        </html>
        """

    def send_welcome_with_mfa(self, email: str, mfa_secret: str, role: str = "patient") -> bool:
        """
        Send welcome email with MFA secret after successful registration.
        
        Args:
            email: User's email address
            mfa_secret: The MFA TOTP secret for the user
            role: User's role (patient, doctor, admin)
            
        Returns:
            True if email sent successfully, False otherwise
        """
        print(f"[EmailService] send_welcome_with_mfa called: email={email}, role={role}")
        
        subject = "Welcome to MeDUSA - Your MFA Setup Information"
        message = self._generate_welcome_mfa_email(email, mfa_secret, role)
        
        if self.use_ses and self.ses_client:
            return self._send_via_ses(email, subject, message)
        else:
            # Note: In dev mode, MFA secret is logged to file only (not console) for debugging
            return self._log_email(email, subject, "[MFA_SECRET_REDACTED]")
    
    def _generate_welcome_mfa_email(self, email: str, mfa_secret: str, role: str) -> str:
        """Generate HTML email for welcome with MFA setup instructions"""
        # Generate otpauth URI for QR code (compatible with Google Authenticator, etc.)
        otpauth_uri = f"otpauth://totp/MeDUSA:{email}?secret={mfa_secret}&issuer=MeDUSA"
        
        return f"""
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <style>
                body {{ font-family: Arial, sans-serif; line-height: 1.6; color: #333; }}
                .container {{ max-width: 600px; margin: 0 auto; padding: 20px; }}
                .header {{ background: #4CAF50; color: white; padding: 20px; text-align: center; }}
                .content {{ background: #f8f9fa; padding: 30px; border-radius: 5px; }}
                .secret-box {{ font-size: 18px; font-weight: bold; color: #4CAF50; text-align: center; 
                             padding: 20px; background: white; border-radius: 5px; margin: 20px 0; 
                             letter-spacing: 3px; font-family: monospace; word-break: break-all; }}
                .steps {{ background: white; padding: 20px; border-radius: 5px; margin: 20px 0; }}
                .steps ol {{ padding-left: 20px; }}
                .steps li {{ margin-bottom: 10px; }}
                .warning {{ background: #fff3cd; border-left: 4px solid #ff9800; padding: 15px; 
                           margin: 20px 0; }}
                .security {{ background: #e8f5e9; border-left: 4px solid #4CAF50; padding: 15px; 
                           margin: 20px 0; }}
                .footer {{ text-align: center; margin-top: 20px; color: #666; font-size: 12px; }}
                .role-badge {{ display: inline-block; background: #1976D2; color: white; 
                              padding: 5px 15px; border-radius: 20px; font-size: 14px; }}
            </style>
        </head>
        <body>
            <div class="container">
                <div class="header">
                    <h1>🎉 Welcome to MeDUSA!</h1>
                    <p>Your account has been created successfully</p>
                </div>
                <div class="content">
                    <p>Hello! Your MeDUSA account has been created with the role: 
                       <span class="role-badge">{role.upper()}</span></p>
                    
                    <h2>🔐 Two-Factor Authentication (MFA) Setup</h2>
                    <p>For your security, MFA is <strong>required</strong> for all MeDUSA accounts. 
                       Please set up your authenticator app using the secret below:</p>
                    
                    <div class="secret-box">{mfa_secret}</div>
                    
                    <div class="steps">
                        <h3>Setup Instructions:</h3>
                        <ol>
                            <li>Download an authenticator app if you don't have one:
                                <ul>
                                    <li>Google Authenticator (iOS/Android)</li>
                                    <li>Microsoft Authenticator (iOS/Android)</li>
                                    <li>Authy (iOS/Android/Desktop)</li>
                                </ul>
                            </li>
                            <li>Open the authenticator app and add a new account</li>
                            <li>Choose "Enter setup key manually" or "Enter a provided key"</li>
                            <li>Enter the following details:
                                <ul>
                                    <li><strong>Account name:</strong> {email}</li>
                                    <li><strong>Secret key:</strong> {mfa_secret}</li>
                                    <li><strong>Type:</strong> Time-based (TOTP)</li>
                                </ul>
                            </li>
                            <li>The app will now generate 6-digit codes that refresh every 30 seconds</li>
                            <li>Use this code along with your password to log in</li>
                        </ol>
                    </div>
                    
                    <div class="security">
                        <strong>🛡️ Security Tips:</strong>
                        <ul>
                            <li>Save this secret key in a secure location as a backup</li>
                            <li>Never share your MFA codes with anyone</li>
                            <li>MeDUSA staff will never ask for your MFA code</li>
                        </ul>
                    </div>
                    
                    <div class="warning">
                        <strong>⚠️ Important:</strong> This email contains sensitive security information. 
                        Please delete this email after saving your MFA secret in your authenticator app.
                    </div>
                </div>
                <div class="footer">
                    <p>&copy; 2025 MeDUSA Health System. All rights reserved.</p>
                    <p>This is an automated message, please do not reply.</p>
                </div>
            </div>
        </body>
        </html>
        """

