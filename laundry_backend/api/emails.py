from django.conf import settings
import logging

logger = logging.getLogger(__name__)

# ─────────────────────────────────────────────────────────────────────────────
# Shared design constants
# ─────────────────────────────────────────────────────────────────────────────
_BRAND_BG      = "#111111"
_CARD_BG       = "#1b1b1b"
_ACCENT        = "#6b7280"
_ACCENT_LIGHT  = "#f3f4f6"
_TEXT_MAIN     = "#ffffff"
_TEXT_MUTED    = "#cbd5e1"
_BORDER        = "rgba(255,255,255,0.12)"

_BASE_STYLES = f"""
    <style>
        @import url('https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&display=swap');
        * {{ box-sizing: border-box; margin: 0; padding: 0; }}
        body {{
            font-family: 'Plus Jakarta Sans', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
            background-color: {_BRAND_BG};
            color: {_TEXT_MAIN};
            -webkit-font-smoothing: antialiased;
        }}
        .wrapper {{
            width: 100%;
            background-color: {_BRAND_BG};
            padding: 40px 16px;
        }}
        .card {{
            max-width: 600px;
            margin: 0 auto;
            background: {_CARD_BG};
            border-radius: 20px;
            border: 1px solid {_BORDER};
            overflow: hidden;
        }}
        /* Header strip */
        .card-header {{
            background: linear-gradient(135deg, #000000 0%, #2a2a2a 50%, #000000 100%);
            padding: 36px 40px 32px;
            text-align: center;
            border-bottom: 1px solid {_BORDER};
        }}
        .logo-row {{
            display: inline-flex;
            align-items: center;
            gap: 10px;
            margin-bottom: 0;
        }}
        .logo-dot {{
            width: 32px;
            height: 32px;
            border-radius: 8px;
            background: linear-gradient(135deg, #f5f5f5, #7c7c7c);
            display: inline-block;
        }}
        .logo-text {{
            font-size: 20px;
            font-weight: 800;
            color: #ffffff;
            letter-spacing: -0.5px;
        }}
        /* Body */
        .card-body {{
            padding: 36px 40px 32px;
        }}
        .headline {{
            font-size: 22px;
            font-weight: 800;
            color: {_TEXT_MAIN};
            line-height: 1.3;
            margin-bottom: 8px;
        }}
        .subline {{
            font-size: 14px;
            color: {_TEXT_MUTED};
            margin-bottom: 28px;
        }}
        p {{
            font-size: 15px;
            color: {_TEXT_MUTED};
            line-height: 1.8;
            margin-bottom: 16px;
        }}
        strong {{ color: {_TEXT_MAIN}; }}
        /* CTA button */
        .btn-wrapper {{ text-align: center; margin: 28px 0; }}
        .btn {{
            display: inline-block;
            padding: 14px 36px;
            background: linear-gradient(135deg, #f5f5f5, #c4c4c4);
            color: #ffffff !important;
            text-decoration: none;
            border-radius: 50px;
            font-weight: 700;
            font-size: 15px;
            letter-spacing: 0.01em;
        }}
        /* Info card / highlight box */
        .info-box {{
            background: rgba(255,255,255,0.04);
            border: 1px solid rgba(255,255,255,0.16);
            border-radius: 12px;
            padding: 20px 24px;
            margin: 20px 0;
        }}
        .info-box p {{ margin: 0; font-size: 14px; }}
        /* Step list */
        .steps {{ list-style: none; padding: 0; margin: 12px 0 20px; }}
        .steps li {{
            display: flex;
            align-items: flex-start;
            gap: 14px;
            padding: 12px 0;
            border-bottom: 1px solid {_BORDER};
            font-size: 14px;
            color: {_TEXT_MUTED};
        }}
        .steps li:last-child {{ border-bottom: none; }}
        .step-num {{
            flex-shrink: 0;
            width: 24px;
            height: 24px;
            border-radius: 50%;
            background: linear-gradient(135deg, #f5f5f5, #7c7c7c);
            color: #fff;
            font-size: 12px;
            font-weight: 700;
            display: flex;
            align-items: center;
            justify-content: center;
        }}
        /* OTP box */
        .otp-box {{
            background: rgba(255,255,255,0.06);
            border: 1px dashed rgba(255,255,255,0.28);
            border-radius: 12px;
            text-align: center;
            padding: 24px;
            margin: 24px 0;
            font-size: 36px;
            font-weight: 800;
            letter-spacing: 10px;
            color: {_ACCENT_LIGHT};
        }}
        /* Badge chip */
        .badge {{
            display: inline-block;
            background: rgba(255,255,255,0.08);
            border: 1px solid rgba(255,255,255,0.18);
            color: {_ACCENT_LIGHT};
            border-radius: 50px;
            padding: 4px 14px;
            font-size: 12px;
            font-weight: 600;
            letter-spacing: 0.05em;
            text-transform: uppercase;
            margin-bottom: 14px;
        }}
        /* Divider */
        .divider {{
            border: none;
            border-top: 1px solid {_BORDER};
            margin: 24px 0;
        }}
        /* Footer */
        .card-footer {{
            background: rgba(255,255,255,0.03);
            border-top: 1px solid {_BORDER};
            padding: 20px 40px;
            text-align: center;
        }}
        .card-footer p {{
            font-size: 12px;
            color: #475569;
            margin: 0;
            line-height: 1.6;
        }}
        .card-footer a {{
            color: #e5e7eb;
            text-decoration: none;
        }}
    </style>
"""

def _html_wrapper(inner_html: str) -> str:
    """Wraps email body content in the full branded shell."""
    return f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    {_BASE_STYLES}
</head>
<body>
<div class="wrapper">
    <div class="card">
        <div class="card-header">
            <div class="logo-row">
                <span class="logo-dot"></span>
                <span class="logo-text">Sparkles</span>
            </div>
        </div>
        <div class="card-body">
            {inner_html}
        </div>
        <div class="card-footer">
            <p>
                &copy; 2026 Dama Technologies LTD. All rights reserved.<br>
                <a href="https://www.sparkles.com.ng/privacy/">Privacy Policy</a>
                &nbsp;&middot;&nbsp;
                <a href="https://www.sparkles.com.ng/terms/">Terms of Service</a>
                &nbsp;&middot;&nbsp;
                <a href="https://www.sparkles.com.ng">www.sparkles.com.ng</a>
            </p>
        </div>
    </div>
</div>
</body>
</html>"""


def _send_html_email(subject, to_email, html_content, text_content):
    """Send HTML email via Resend SDK; falls back to logger in local dev."""
    try:
        api_key   = getattr(settings, 'RESEND_API_KEY', None)
        from_email = getattr(settings, 'DEFAULT_FROM_EMAIL', 'Sparkles <support@sparkles.com.ng>')

        if not api_key:
            logger.info(
                "[EMAIL FALLBACK] To=%s | Subject=%s\n%s",
                to_email, subject, text_content
            )
            return True

        import resend
        resend.api_key = api_key
        resend.Emails.send({
            "from":    from_email,
            "to":      [to_email],
            "subject": subject,
            "html":    html_content,
            "text":    text_content,
        })
        logger.info("Email sent via Resend to %s — %s", to_email, subject)
        return True
    except Exception as e:
        logger.error("Failed to send email to %s: %s", to_email, str(e))
        return False


# ─────────────────────────────────────────────────────────────────────────────
# 1. Waitlist — Confirmation (sent immediately when someone joins the waitlist)
# ─────────────────────────────────────────────────────────────────────────────
def send_waitlist_welcome(email):
    subject = "Your Sparkles waitlist request is confirmed"

    text_content = (
        "Hello,\n\n"
        "Thank you for joining the Sparkles waitlist. Your request has been received and confirmed.\n\n"
        "We are opening access gradually and will get back to you if a slot becomes available.\n\n"
        "We appreciate your interest and hope to welcome you soon.\n\n"
        "Best regards,\n"
        "The Sparkles Team\n"
        "https://www.sparkles.com.ng"
    )

    inner = """
        <div class="badge">Waitlist Confirmed</div>
        <h1 class="headline">You're on the list</h1>
        <p class="subline">We'll reach out if a spot opens up.</p>

        <p>
            Thanks for your interest in Sparkles. We have received your request and added your email to
            the waitlist.
        </p>

        <div class="info-box">
            <p>
                We are opening access in stages and will contact you when a slot becomes available.
                We hope to work with you soon.
            </p>
        </div>

        <hr class="divider">
        <p style="font-size:13px;">
            If a space opens for your office, we will reach out directly.
        </p>
        <p><strong>The Sparkles Team</strong></p>
    """

    return _send_html_email(subject, email, _html_wrapper(inner), text_content)


# ─────────────────────────────────────────────────────────────────────────────
# 2. Waitlist — Invitation (sent when admin marks a waitlist entry as notified)
# ─────────────────────────────────────────────────────────────────────────────
def send_waitlist_notified(email):
    subject = "Sparkles waitlist update"

    text_content = (
        "Hello!\n\n"
        "We are reaching out to let you know that your waitlist entry is still active.\n\n"
        "If a slot opens for your office, we will contact you directly.\n\n"
        "Thank you for being patient with us.\n\n"
        "Best regards,\n"
        "The Sparkles Team"
    )

    inner = """
        <div class="badge">Waitlist Update</div>
        <h1 class="headline">We have your details</h1>
        <p class="subline">We may be in touch when a slot opens.</p>

        <p>
            Your email is on our waitlist. When we are able to take the next group of clients, we will
            get back to you directly.
        </p>

        <div class="info-box">
            <p>
                We appreciate your interest and hope to reach out with a place for you soon.
            </p>
        </div>

        <hr class="divider">
        <p style="font-size:13px;">
            Thank you for your patience.
        </p>
        <p><strong>The Sparkles Team</strong></p>
    """

    return _send_html_email(subject, email, _html_wrapper(inner), text_content)


# ─────────────────────────────────────────────────────────────────────────────
# 3. Registration — Welcome (sent when a new office registers in the app)
# ─────────────────────────────────────────────────────────────────────────────
def send_welcome_registration(email, office_name):
    subject = f"Welcome to Sparkles — {office_name} is live! 🌟"

    text_content = (
        f"Welcome to Sparkles!\n\n"
        f"Congratulations! Your laundry workspace '{office_name}' has been registered successfully.\n"
        f"Your admin account is linked to: {email}\n\n"
        f"Next Steps:\n"
        f"1. Open the Sparkles app and log in with your email and password.\n"
        f"2. Go to Settings → Services to add your service types (Wash & Iron, Dry Clean, etc.).\n"
        f"3. Add your Item Pricing and Categories.\n"
        f"4. Invite staff members from Settings → Team.\n"
        f"5. Create your first order and let Sparkles handle the rest!\n\n"
        f"Need help? Reply to this email — our team is happy to assist.\n\n"
        f"Best regards,\n"
        f"The Sparkles Team\n"
        f"https://www.sparkles.com.ng"
    )

    inner = f"""
        <div class="badge">Welcome Aboard</div>
        <h1 class="headline">Welcome to Sparkles! 🌟</h1>
        <p class="subline">Your workspace is live and ready to go.</p>

        <div class="info-box">
            <p>
                <strong>🏢 Office registered:</strong> {office_name}<br>
                <strong>📧 Admin account:</strong> {email}
            </p>
        </div>

        <p>
            Congratulations — your laundry workspace is fully set up. Here's everything you need
            to get running in the next 10 minutes:
        </p>

        <ul class="steps">
            <li>
                <span class="step-num">1</span>
                <span>Open the <strong>Sparkles app</strong> and log in with your email and password.</span>
            </li>
            <li>
                <span class="step-num">2</span>
                <span>Go to <strong>Settings → Services</strong> to add your service types (Wash &amp; Iron, Dry Clean, etc.).</span>
            </li>
            <li>
                <span class="step-num">3</span>
                <span>Add your <strong>Item Pricing</strong> and Categories to match your business.</span>
            </li>
            <li>
                <span class="step-num">4</span>
                <span>Invite <strong>staff members</strong> from Settings → Team so they can take orders.</span>
            </li>
            <li>
                <span class="step-num">5</span>
                <span>Create your <strong>first order</strong> — Sparkles will handle receipts, tracking, and notifications!</span>
            </li>
        </ul>

        <div class="btn-wrapper">
            <a href="https://www.sparkles.com.ng/#pricing" class="btn">View Subscription Plans →</a>
        </div>

        <hr class="divider">
        <p style="font-size:13px;">
            Questions about setup? Reply to this email or visit
            <a href="https://www.sparkles.com.ng" style="color:#6366f1;">www.sparkles.com.ng</a>.
            We typically respond within a few hours.
        </p>
        <p><strong>The Sparkles Team</strong><br>
        <span style="color:#475569;font-size:13px;">Dama Technologies LTD</span></p>
    """

    return _send_html_email(subject, email, _html_wrapper(inner), text_content)


# ─────────────────────────────────────────────────────────────────────────────
# 4. Password Reset OTP
# ─────────────────────────────────────────────────────────────────────────────
def send_password_reset_otp(email, otp):
    subject = "Your Sparkles Password Reset Code"

    text_content = (
        f"Hello,\n\n"
        f"We received a request to reset your Sparkles password.\n\n"
        f"Your verification code is: {otp}\n\n"
        f"This code expires in 15 minutes. If you did not request a password reset, "
        f"please ignore this email — your account is safe.\n\n"
        f"Best regards,\n"
        f"The Sparkles Team"
    )

    inner = f"""
        <div class="badge">Security</div>
        <h1 class="headline">Password Reset Request</h1>
        <p class="subline">Use the code below to reset your Sparkles password.</p>

        <p>
            We received a request to reset the password for your Sparkles account linked to
            <strong>{email}</strong>.
        </p>

        <p>Enter this verification code in the app:</p>

        <div class="otp-box">{otp}</div>

        <p style="text-align:center;font-size:13px;color:#64748b;">
            This code expires in <strong style="color:{_TEXT_MUTED};">15 minutes</strong>.
        </p>

        <hr class="divider">
        <p style="font-size:13px;">
            If you did not request a password reset, you can safely ignore this email.
            Your account has not been changed.
        </p>
        <p><strong>The Sparkles Team</strong></p>
    """

    return _send_html_email(subject, email, _html_wrapper(inner), text_content)


# ─────────────────────────────────────────────────────────────────────────────
# 5. Waitlist — Custom Broadcast/Single Email
# ─────────────────────────────────────────────────────────────────────────────
def send_custom_waitlist_email(email, subject, message_body, cta_text=None, cta_link=None):
    # Convert newlines to HTML br tags
    body_html_formatted = message_body.replace("\n", "<br>")
    
    cta_html = ""
    text_content = message_body
    if cta_text and cta_link:
        cta_html = f"""
        <div class="btn-wrapper">
            <a href="{cta_link}" class="btn">{cta_text} &rarr;</a>
        </div>
        """
        text_content += f"\n\n{cta_text}: {cta_link}"
        
    text_content += "\n\nBest regards,\nThe Sparkles Team"

    inner = f"""
        <div class="badge">Waitlist Update</div>
        <h1 class="headline">{subject}</h1>
        
        <p>
            {body_html_formatted}
        </p>

        {cta_html}

        <hr class="divider">
        <p><strong>The Sparkles Team</strong></p>
    """
    
    return _send_html_email(subject, email, _html_wrapper(inner), text_content)

