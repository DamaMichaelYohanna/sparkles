import requests
from django.conf import settings

def initialize_payment(email, amount_kobo, reference, plan_code=None, metadata=None):
    """
    Initializes a Paystack transaction.
    amount_kobo: Amount in the smallest currency unit (e.g., Kobo for NGN)
    """
    url = "https://api.paystack.co/transaction/initialize"
    headers = {
        "Authorization": f"Bearer {getattr(settings, 'PAYSTACK_SECRET_KEY', 'sk_test_placeholder')}",
        "Content-Type": "application/json"
    }
    payload = {
        "email": email,
        "amount": amount_kobo,
        "reference": reference,
    }
    if metadata:
        payload["metadata"] = metadata
    if plan_code:
        payload["plan"] = plan_code
    response = requests.post(url, json=payload, headers=headers)
    return response.json()

def verify_payment(reference):
    """
    Verifies a Paystack transaction.
    """
    url = f"https://api.paystack.co/transaction/verify/{reference}"
    headers = {
        "Authorization": f"Bearer {getattr(settings, 'PAYSTACK_SECRET_KEY', 'sk_test_placeholder')}",
    }
    response = requests.get(url, headers=headers)
    return response.json()
