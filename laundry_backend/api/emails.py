from django.core.mail import EmailMultiAlternatives
from django.conf import settings
import logging

logger = logging.getLogger(__name__)

def _send_html_email(subject, to_email, html_content, text_content):
    """
    Helper function to send HTML emails via Resend SDK with plain text fallback.
    """
    try:
        api_key = getattr(settings, 'RESEND_API_KEY', None)
        from_email = getattr(settings, 'DEFAULT_FROM_EMAIL', 'Sparkles <onboarding@resend.dev>')
        
        # Local development fallback: if no API key is specified, print to console
        if not api_key:
            print("=========================================")
            print(f"CONSOLE EMAIL FALLBACK (No Resend API Key)")
            print(f"To: {to_email}")
            print(f"From: {from_email}")
            print(f"Subject: {subject}")
            print(f"Plain Text:\n{text_content}")
            print("=========================================")
            logger.info(f"Email printed to console (local dev fallback) to {to_email}")
            return True
            
        import resend
        resend.api_key = api_key
        
        params = {
            "from": from_email,
            "to": [to_email],
            "subject": subject,
            "html": html_content,
            "text": text_content,
        }
        
        resend.Emails.send(params)
        logger.info(f"Email sent successfully via Resend API to {to_email} with subject: {subject}")
        return True
    except Exception as e:
        logger.error(f"Failed to send email via Resend to {to_email}: {str(e)}")
        return False

def send_waitlist_welcome(email):
    subject = "You're on the Sparkles Waitlist!"
    
    text_content = (
        "Hello,\n\n"
        "Thank you for joining the Sparkles waitlist! We are thrilled to have your interest.\n\n"
        "We are currently onboarding selected laundry offices. By securing your spot early, you qualify for "
        "our 50% early adopter discount and priority onboarding support.\n\n"
        "We will reach out as soon as your account slot is ready. In the meantime, feel free to visit our "
        "landing page to learn more about our features.\n\n"
        "Best regards,\n"
        "The Sparkles Team"
    )
    
    html_content = """
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="utf-8">
        <style>
            body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; line-height: 1.6; color: #333; background-color: #fafafa; margin: 0; padding: 0; }
            .container { max-width: 600px; margin: 40px auto; padding: 30px; border: 1px solid #eef0f2; border-radius: 12px; background-color: #ffffff; box-shadow: 0 4px 12px rgba(0,0,0,0.02); }
            .header { text-align: center; margin-bottom: 30px; border-bottom: 1px solid #eef0f2; padding-bottom: 20px; }
            .header h2 { margin: 0; color: #1a1a1a; font-weight: 800; letter-spacing: -0.5px; }
            .footer { margin-top: 40px; font-size: 12px; color: #6c757d; text-align: center; border-top: 1px solid #eef0f2; padding-top: 20px; }
        </style>
    </head>
    <body>
        <div class="container">
            <div class="header">
                <h2>Sparkles</h2>
            </div>
            <p>Hello,</p>
            <p>Thank you for joining the Sparkles waitlist! We are thrilled to have your interest.</p>
            <p>We are currently onboarding selected laundry offices. By securing your spot early, you qualify for our <strong>50% early adopter discount</strong> and priority onboarding support.</p>
            <p>We will reach out as soon as your account slot is ready. In the meantime, feel free to visit our landing page to learn more about our features.</p>
            <p>Best regards,<br><strong>The Sparkles Team</strong></p>
            <div class="footer">
                <p>&copy; 2026 Sparkles Inc. All rights reserved.</p>
            </div>
        </div>
    </body>
    </html>
    """
    return _send_html_email(subject, email, html_content, text_content)

def send_waitlist_notified(email):
    subject = "Your Sparkles Account is Ready!"
    
    text_content = (
        "Hello!\n\n"
        "Great news! We have opened up onboarding slots for early adopters, and your invitation is now active.\n\n"
        "You can now register your laundry office and start managing branches, staff, and pricing immediately.\n\n"
        "To get started, simply download our companion mobile application and register your office directly inside the app.\n\n"
        "If you have any questions or need assistance, reply directly to this email.\n\n"
        "Best regards,\n"
        "The Sparkles Team"
    )
    
    html_content = """
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="utf-8">
        <style>
            body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; line-height: 1.6; color: #333; background-color: #fafafa; margin: 0; padding: 0; }
            .container { max-width: 600px; margin: 40px auto; padding: 30px; border: 1px solid #eef0f2; border-radius: 12px; background-color: #ffffff; box-shadow: 0 4px 12px rgba(0,0,0,0.02); }
            .header { text-align: center; margin-bottom: 30px; border-bottom: 1px solid #eef0f2; padding-bottom: 20px; }
            .header h2 { margin: 0; color: #1a1a1a; font-weight: 800; letter-spacing: -0.5px; }
            .btn-wrapper { text-align: center; margin: 30px 0; }
            .btn { display: inline-block; padding: 12px 28px; background-color: #121416; color: #ffffff !important; text-decoration: none; border-radius: 50px; font-weight: 700; font-size: 0.95rem; box-shadow: 0 4px 12px rgba(0,0,0,0.15); }
            .footer { margin-top: 40px; font-size: 12px; color: #6c757d; text-align: center; border-top: 1px solid #eef0f2; padding-top: 20px; }
        </style>
    </head>
    <body>
        <div class="container">
            <div class="header">
                <h2>Sparkles Invitation</h2>
            </div>
            <p>Hello!</p>
            <p>Great news! We have opened up onboarding slots for early adopters, and your invitation is now active.</p>
            <p>You can now register your laundry office and start managing branches, staff, and pricing immediately.</p>
            <p>To get started, simply download our companion mobile application and register your office directly inside the app, or visit our portal below:</p>
            <div class="btn-wrapper">
                <a href="https://sparkles-green.vercel.app/" class="btn">Access Portal</a>
            </div>
            <p>If you have any questions or need assistance setting up your workspace, reply directly to this email. Our onboarding team is happy to help!</p>
            <p>Best regards,<br><strong>The Sparkles Team</strong></p>
            <div class="footer">
                <p>&copy; 2026 Sparkles Inc. All rights reserved.</p>
            </div>
        </div>
    </body>
    </html>
    """
    return _send_html_email(subject, email, html_content, text_content)

def send_welcome_registration(email, office_name):
    subject = f"Welcome to Sparkles! Your workspace '{office_name}' is active"
    
    text_content = (
        f"Welcome to Sparkles!\n\n"
        f"Congratulations! Your laundry workspace '{office_name}' has been registered successfully.\n\n"
        f"Your admin account is setup with the email: {email}.\n\n"
        f"Next Steps:\n"
        f"1. Download the companion mobile app on your Android or iOS device.\n"
        f"2. Log in using your registered email and password.\n"
        f"3. Configure your Services, Categories, and Staff members under Settings.\n"
        f"4. Start tracking intakes, managing collections, and automating receipts!\n\n"
        f"If you have any questions, feel free to contact our support team at any time.\n\n"
        f"Best regards,\n"
        f"The Sparkles Team"
    )
    
    html_content = f"""
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="utf-8">
        <style>
            body {{ font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; line-height: 1.6; color: #333; background-color: #fafafa; margin: 0; padding: 0; }}
            .container {{ max-width: 600px; margin: 40px auto; padding: 30px; border: 1px solid #eef0f2; border-radius: 12px; background-color: #ffffff; box-shadow: 0 4px 12px rgba(0,0,0,0.02); }}
            .header {{ text-align: center; margin-bottom: 30px; border-bottom: 1px solid #eef0f2; padding-bottom: 20px; }}
            .header h2 {{ margin: 0; color: #1a1a1a; font-weight: 800; letter-spacing: -0.5px; }}
            .steps {{ padding-left: 20px; margin: 20px 0; }}
            .steps li {{ margin-bottom: 10px; }}
            .footer {{ margin-top: 40px; font-size: 12px; color: #6c757d; text-align: center; border-top: 1px solid #eef0f2; padding-top: 20px; }}
        </style>
    </head>
    <body>
        <div class="container">
            <div class="header">
                <h2>Welcome to Sparkles</h2>
            </div>
            <p>Hello,</p>
            <p>Congratulations! Your laundry workspace <strong>{office_name}</strong> has been registered successfully.</p>
            <p>Your admin account has been set up with the email <strong>{email}</strong>.</p>
            <p><strong>Next Steps to get started:</strong></p>
            <ol class="steps">
                <li>Download the companion mobile app on your Android or iOS device.</li>
                <li>Log in using your registered email and password.</li>
                <li>Configure your Services, Categories, and Staff members under Settings.</li>
                <li>Start tracking intakes, managing collections, and automating receipts!</li>
            </ol>
            <p>If you have any questions or need assistance onboarding your team, feel free to reply to this email at any time.</p>
            <p>Best regards,<br><strong>The Sparkles Team</strong></p>
            <div class="footer">
                <p>&copy; 2026 Sparkles Inc. All rights reserved.</p>
            </div>
        </div>
    </body>
    </html>
    """
    return _send_html_email(subject, email, html_content, text_content)

def send_password_reset_otp(email, otp):
    subject = "Sparkles Password Reset Verification Code"
    text_content = f"Your password reset verification code is: {otp}. It expires in 15 minutes."
    html_content = f"""
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="utf-8">
        <style>
            body {{ font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; line-height: 1.6; color: #333; background-color: #fafafa; margin: 0; padding: 0; }}
            .container {{ max-width: 600px; margin: 40px auto; padding: 30px; border: 1px solid #eef0f2; border-radius: 12px; background-color: #ffffff; box-shadow: 0 4px 12px rgba(0,0,0,0.02); }}
            .header {{ text-align: center; margin-bottom: 30px; border-bottom: 1px solid #eef0f2; padding-bottom: 20px; }}
            .header h2 {{ margin: 0; color: #1a1a1a; font-weight: 800; letter-spacing: -0.5px; }}
            .otp-box {{ background-color: #f4f5f7; padding: 15px; border-radius: 8px; text-align: center; font-size: 24px; font-weight: bold; letter-spacing: 4px; margin: 25px 0; color: #1a1a1a; border: 1px dashed #eef0f2; }}
            .footer {{ margin-top: 40px; font-size: 12px; color: #6c757d; text-align: center; border-top: 1px solid #eef0f2; padding-top: 20px; }}
        </style>
    </head>
    <body>
        <div class="container">
            <div class="header">
                <h2>Sparkles Reset Verification</h2>
            </div>
            <p>Hello,</p>
            <p>We received a request to reset your password. Use the following verification code to proceed:</p>
            <div class="otp-box">{otp}</div>
            <p>This code will expire in 15 minutes. If you did not make this request, you can safely ignore this email.</p>
            <p>Best regards,<br><strong>The Sparkles Team</strong></p>
            <div class="footer">
                <p>&copy; 2026 Sparkles Inc. All rights reserved.</p>
            </div>
        </div>
    </body>
    </html>
    """
    return _send_html_email(subject, email, html_content, text_content)
