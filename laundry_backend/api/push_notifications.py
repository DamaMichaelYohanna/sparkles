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
    vapid_claims = {"sub": settings.VAPID_CLAIM_EMAIL}

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
        logger.info("[WebPush] Successfully sent push to %s", subscription.customer_phone)
        return True
    except WebPushException as ex:
        logger.warning("[WebPush] WebPushException: %s", ex)
        # If the browser push service returned 410 Gone, the subscription is expired or revoked. Delete it!
        if ex.response is not None and ex.response.status_code == 410:
            logger.info("[WebPush] Subscription expired or revoked (410). Deleting subscription for %s", subscription.customer_phone)
            subscription.delete()
        return False
    except Exception as e:
        logger.error("[WebPush] Failed to send push: %s", e, exc_info=True)
        return False


def notify_order_status_change(order):
    """
    Finds all active subscriptions for the order's customer phone,
    and sends them web push notifications indicating the status change.
    """
    if not order.customer_phone:
        return

    from django.db.models import Q
    q_filter = Q(customer_phone=order.customer_phone)
    if order.customer:
        q_filter |= Q(customer=order.customer)

    subscriptions = WebPushSubscription.objects.filter(
        q_filter,
        is_deleted=False
    ).distinct()
    if not subscriptions.exists():
        logger.info("[WebPush] No push subscriptions found for phone %s", order.customer_phone)
        return

    title = f"Sparkles | {order.office.name}"
    body = f"Order #{order.tracking_code} is now: {order.current_status.name}."
    
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
