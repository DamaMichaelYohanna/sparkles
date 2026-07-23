import json
import logging
from django.conf import settings
from pywebpush import webpush, WebPushException
from operations.models import WebPushSubscription

logger = logging.getLogger(__name__)

def send_web_push(subscription, title, body, url):
    """
    Sends a web push notification to a browser push service endpoint.
    """
    vapid_private_key = settings.VAPID_PRIVATE_KEY
    vapid_public_key = settings.VAPID_PUBLIC_KEY
    
    sub_claim = settings.VAPID_CLAIM_EMAIL or "mailto:support@sparkles.com.ng"
    if not sub_claim.startswith("mailto:") and not sub_claim.startswith("https://"):
        sub_claim = f"mailto:{sub_claim}"
    vapid_claims = {"sub": sub_claim}

    if not vapid_private_key or not vapid_public_key:
        logger.warning("[WebPush] Skipping push notification: VAPID keys not configured in settings.")
        return False

    payload = {
        "title": title,
        "body": body,
        "url": url
    }

    try:
        webpush(
            subscription_info={
                "endpoint": subscription.endpoint,
                "keys": {
                    "p256dh": subscription.p256dh,
                    "auth": subscription.auth
                }
            },
            data=json.dumps(payload),
            vapid_private_key=vapid_private_key,
            vapid_claims=vapid_claims,
        )
        logger.info("[WebPush] Successfully sent push to %s (endpoint: %s...)", subscription.customer_phone, subscription.endpoint[:30])
        return True
    except WebPushException as ex:
        logger.warning("[WebPush] WebPushException for %s: %s", subscription.customer_phone, ex)
        # Delete ONLY if 410 Gone (explicitly unsubscribed/invalidated by push service)
        if ex.response is not None and ex.response.status_code == 410:
            logger.info("[WebPush] Subscription expired (410 Gone). Deleting subscription for %s", subscription.customer_phone)
            subscription.delete()
        return False
    except Exception as e:
        logger.error("[WebPush] Failed to send push to %s: %s", subscription.customer_phone, e, exc_info=True)
        return False


def notify_order_status_change(order):
    """
    Finds all active subscriptions for the order's customer phone,
    and sends them web push notifications indicating the status change.
    """
    if not order.customer_phone and not order.customer:
        return

    from django.db.models import Q
    raw_phone = (order.customer_phone or '').strip()
    digits = ''.join(filter(str.isdigit, raw_phone))
    last_10 = digits[-10:] if len(digits) >= 7 else ''

    q_filter = Q()
    if raw_phone:
        q_filter |= Q(customer_phone=raw_phone)
    if last_10:
        q_filter |= Q(customer_phone__endswith=last_10)
    if order.customer:
        q_filter |= Q(customer=order.customer)
        if order.customer.phone:
            q_filter |= Q(customer_phone=order.customer.phone)
            cust_digits = ''.join(filter(str.isdigit, order.customer.phone))
            if len(cust_digits) >= 7:
                q_filter |= Q(customer_phone__endswith=cust_digits[-10:])

    subscriptions = WebPushSubscription.objects.filter(
        q_filter,
        is_deleted=False
    ).distinct()

    if not subscriptions.exists():
        logger.info("[WebPush] No push subscriptions found for phone '%s' (last10: '%s')", raw_phone, last_10)
        return

    status_name = order.current_status.name if order.current_status else 'Updated'
    title = f"Sparkles | {order.office.name}"
    body = f"Order #{order.tracking_code} is now: {status_name}."
    
    # Construct receipt detail URL dynamically based on settings
    base_url = settings.SPARKLES_PORTAL_BASE_URL.rstrip('/')
    url = f"{base_url}/r/{order.tracking_code}/"

    from threading import Thread
    for subscription in subscriptions:
        # Send asynchronously in a background thread so we don't block request flows
        Thread(
            target=send_web_push,
            args=(subscription, title, body, url),
            daemon=True
        ).start()
