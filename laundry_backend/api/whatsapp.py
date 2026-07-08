import requests
from django.conf import settings

def send_whatsapp_notification(phone_number, message_body):
    """
    Sends a WhatsApp notification.
    Example uses Twilio WhatsApp API structure, but can be adapted to Meta API or Termii.
    """
    # Assuming Twilio or a similar API provider
    api_url = getattr(settings, 'WHATSAPP_API_URL', 'https://api.twilio.com/2010-04-01/Accounts/{AccountSid}/Messages.json')
    api_key = getattr(settings, 'WHATSAPP_API_KEY', 'placeholder_key')
    
    # Payload structure depends on the provider.
    # This is a generic scaffold.
    payload = {
        "To": f"whatsapp:{phone_number}",
        "From": f"whatsapp:{getattr(settings, 'WHATSAPP_FROM_NUMBER', '+14155238886')}",
        "Body": message_body
    }
    
    # In a real scenario, requests.post would be used with proper auth.
    # For now, we mock the success.
    # response = requests.post(api_url, data=payload, auth=(settings.WHATSAPP_ACCOUNT_SID, settings.WHATSAPP_AUTH_TOKEN))
    # return response.json()
    
    print(f"Mock WhatsApp Sent to {phone_number}: {message_body}")
    return {"status": "success", "message": "Mock notification queued"}
