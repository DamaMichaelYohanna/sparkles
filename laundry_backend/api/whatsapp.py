import requests
from django.conf import settings
import logging

logger = logging.getLogger(__name__)

def send_whatsapp_notification(phone_number, message_body):
    """
    Sends a WhatsApp notification using Meta WhatsApp Cloud API.
    Fails gracefully to console logging if credentials are not configured.
    """
    access_token = getattr(settings, 'WHATSAPP_ACCESS_TOKEN', None)
    phone_number_id = getattr(settings, 'WHATSAPP_PHONE_NUMBER_ID', None)
    api_version = getattr(settings, 'WHATSAPP_API_VERSION', 'v18.0')

    # Clean recipient phone number (Meta requires digits only: country code + subscriber, e.g. 23480xxxxxxxx)
    clean_phone = ''.join(c for c in phone_number if c.isdigit())
    # If the clean phone is a Nigerian local format (starts with '0' and has 11 digits), format with country code 234
    if len(clean_phone) == 11 and clean_phone.startswith('0'):
        clean_phone = '234' + clean_phone[1:]

    if not access_token or not phone_number_id:
        # Development / Sandbox Fallback
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

def send_whatsapp_order_completed(order):
    """
    Constructs and sends a professional WhatsApp notification to the customer
    when their laundry order is completed.
    """
    # Only send if the customer has a phone number
    if not order.customer_phone:
        return
        
    # Check if the customer opted in / wants WhatsApp notifications
    if not order.customer_is_whatsapp:
        logger.info(f"Skipping WhatsApp notification for Order {order.id}: customer did not request WhatsApp notifications.")
        return

    # Construct a beautiful and professional receipt message
    message = (
        f"Hello {order.customer_name},\n\n"
        f"Great news! Your laundry order is ready for collection at Sparkles {order.office.name}.\n\n"
        f"Order Summary:\n"
        f"- Total Amount: ₦{order.total_price:,.2f}\n"
        f"- Amount Paid: ₦{order.amount_paid:,.2f}\n"
    )
    
    # Add pending balance details if any
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
