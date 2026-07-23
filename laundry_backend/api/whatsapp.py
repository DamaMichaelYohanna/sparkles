import requests
from django.conf import settings
import logging

logger = logging.getLogger(__name__)

def _format_clean_phone(phone_number):
    clean_phone = ''.join(c for c in str(phone_number or '') if c.isdigit())
    if len(clean_phone) == 11 and clean_phone.startswith('0'):
        clean_phone = '234' + clean_phone[1:]
    return clean_phone

def send_whatsapp_notification(phone_number, message_body):
    """
    Sends a freeform text WhatsApp notification using Meta WhatsApp Cloud API.
    Fails gracefully to console logging if credentials are not configured.
    """
    access_token = getattr(settings, 'WHATSAPP_ACCESS_TOKEN', None)
    phone_number_id = getattr(settings, 'WHATSAPP_PHONE_NUMBER_ID', None)
    api_version = getattr(settings, 'WHATSAPP_API_VERSION', 'v18.0')

    clean_phone = _format_clean_phone(phone_number)
    if not clean_phone:
        return {"status": "error", "message": "Invalid phone number"}

    if not access_token or not phone_number_id:
        print("=========================================")
        print("CONSOLE WHATSAPP FALLBACK (No Meta API Credentials)")
        print(f"To: {clean_phone}")
        print(f"Message: {message_body}")
        print("=========================================")
        logger.info(f"WhatsApp message printed to console (local fallback) to {clean_phone}")
        return {"status": "mock_success", "message": "Mock notification queued"}

    api_url = f"https://graph.facebook.com/{api_version}/{phone_number_id}/messages"
    headers = {
        "Authorization": f"Bearer {access_token}",
        "Content-Type": "application/json"
    }
    payload = {
        "messaging_product": "whatsapp",
        "recipient_type": "individual",
        "to": clean_phone,
        "type": "text",
        "text": {
            "preview_url": False,
            "body": message_body
        }
    }

    try:
        response = requests.post(api_url, json=payload, headers=headers, timeout=10)
        if response.status_code == 200:
            logger.info(f"WhatsApp sent successfully via Meta Cloud API to {clean_phone}")
            return response.json()
        else:
            logger.error(f"Meta WhatsApp Cloud API failed with status {response.status_code}: {response.text}")
            return {"status": "error", "code": response.status_code, "message": response.text}
    except Exception as e:
        logger.error(f"Error calling Meta WhatsApp Cloud API: {str(e)}")
        return {"status": "error", "message": str(e)}


def send_whatsapp_template_notification(phone_number, template_name, language_code, parameters, fallback_text):
    """
    Sends an approved Utility Message Template via Meta WhatsApp Cloud API.
    Required by Meta when initiating conversations outside the 24-hr customer service window.
    """
    access_token = getattr(settings, 'WHATSAPP_ACCESS_TOKEN', None)
    phone_number_id = getattr(settings, 'WHATSAPP_PHONE_NUMBER_ID', None)
    api_version = getattr(settings, 'WHATSAPP_API_VERSION', 'v18.0')

    clean_phone = _format_clean_phone(phone_number)
    if not clean_phone:
        return {"status": "error", "message": "Invalid phone number"}

    if not access_token or not phone_number_id:
        print("=========================================")
        print("CONSOLE WHATSAPP TEMPLATE FALLBACK (No Meta API Credentials)")
        print(f"To: {clean_phone}")
        print(f"Template Name: {template_name} ({language_code})")
        print(f"Parameters: {parameters}")
        print(f"Fallback Text:\n{fallback_text}")
        print("=========================================")
        logger.info(f"WhatsApp template printed to console (local fallback) to {clean_phone}")
        return {"status": "mock_success", "message": "Mock template notification logged"}

    api_url = f"https://graph.facebook.com/{api_version}/{phone_number_id}/messages"
    headers = {
        "Authorization": f"Bearer {access_token}",
        "Content-Type": "application/json"
    }

    # Meta Cloud API Template Payload
    payload = {
        "messaging_product": "whatsapp",
        "recipient_type": "individual",
        "to": clean_phone,
        "type": "template",
        "template": {
            "name": template_name,
            "language": {
                "code": language_code
            },
            "components": [
                {
                    "type": "body",
                    "parameters": [{"type": "text", "text": str(p)} for p in parameters]
                }
            ]
        }
    }

    try:
        response = requests.post(api_url, json=payload, headers=headers, timeout=10)
        if response.status_code == 200:
            logger.info(f"WhatsApp template '{template_name}' sent successfully via Meta Cloud API to {clean_phone}")
            return response.json()
        else:
            logger.warning(f"Meta WhatsApp Template API returned status {response.status_code}: {response.text}. Attempting text fallback...")
            return send_whatsapp_notification(phone_number, fallback_text)
    except Exception as e:
        logger.error(f"Error sending Meta WhatsApp Template: {str(e)}")
        return send_whatsapp_notification(phone_number, fallback_text)


def send_whatsapp_order_completed(order):
    """
    Constructs and sends a WhatsApp notification to the customer
    when their laundry order is completed.
    """
    if not order.customer_phone:
        return

    message = (
        f"Hello {order.customer_name},\n\n"
        f"Great news! Your laundry order is ready for collection at Sparkles {order.office.name}.\n\n"
        f"Order Summary:\n"
        f"- Total Amount: ₦{order.total_price:,.2f}\n"
        f"- Amount Paid: ₦{order.amount_paid:,.2f}\n"
    )
    
    balance = order.total_price - order.amount_paid
    if balance > 0:
        message += f"- Balance Due: ₦{balance:,.2f}\n"
    else:
        message += "- Status: Paid in Full\n"
        
    message += (
        f"\nThank you for choosing Sparkles!\n"
        f"If you have any questions, feel free to contact us."
    )

    return send_whatsapp_notification(order.customer_phone, message)


def send_whatsapp_order_received(order):
    """
    Constructs and sends a Meta WhatsApp Utility template message to the customer
    whenever a new order is created and a customer phone number is present.

    Meta Template Format:
    Hi {{1}}
    Your order has been created at {{2}}
    Here is your tracking link {{3}}
    """
    if not order.customer_phone:
        logger.info(f"Skipping WhatsApp order creation notification for Order #{order.tracking_code}: No phone number provided.")
        return

    customer_name = (order.customer_name or 'Customer').strip()
    office_name = (order.office.name or 'Sparkles Laundry').strip()

    base_url = getattr(settings, 'SPARKLES_PORTAL_BASE_URL', 'https://sparkles.app')
    receipt_url = f"{base_url.rstrip('/')}/r/{order.tracking_code}/"

    template_name = getattr(settings, 'WHATSAPP_TEMPLATE_ORDER_CREATED', 'order_created')
    language_code = getattr(settings, 'WHATSAPP_TEMPLATE_LANGUAGE', 'en')
    
    # Parameters matching Meta Template: {{1}}=Name, {{2}}=Office, {{3}}=URL
    parameters = [customer_name, office_name, receipt_url]

    fallback_text = (
        f"Hi {customer_name}\n"
        f"Your order has been created at {office_name}\n"
        f"Here is your tracking link {receipt_url}"
    )

    return send_whatsapp_template_notification(
        phone_number=order.customer_phone,
        template_name=template_name,
        language_code=language_code,
        parameters=parameters,
        fallback_text=fallback_text
    )
