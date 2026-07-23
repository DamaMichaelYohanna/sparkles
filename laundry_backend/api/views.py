import logging
from django.contrib.auth import get_user_model
from django.db import transaction, close_old_connections
from django.db.models import Sum, Count, F, Q
from django.utils import timezone
from threading import Thread

logger = logging.getLogger(__name__)
from rest_framework import generics, permissions
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.exceptions import PermissionDenied
from offices.models import LaundryOffice, PasswordResetOTP
from operations.models import ServiceType, Category, ItemPricing, OrderStatus, Order, OrderItem, ActionLog
from .permissions import IsOfficeAdmin, TierLimitPermission
from .serializers import (
    LaundryOfficeSerializer, ServiceTypeSerializer, CategorySerializer,
    ItemPricingSerializer, OrderStatusSerializer, OrderSerializer, OrderItemSerializer,
    SubUserSerializer
)

User = get_user_model()

def run_in_background(target_func, *args, **kwargs):
    def wrapper():
        try:
            target_func(*args, **kwargs)
        finally:
            close_old_connections()

    def schedule_thread():
        Thread(target=wrapper, daemon=True).start()

    transaction.on_commit(schedule_thread)

class BaseTenantView:
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        if not user.office:
            return self.queryset.none()
        
        if self.queryset.model == LaundryOffice:
            return self.queryset.filter(id=user.office_id)
            
        return self.queryset.filter(office=user.office)

    def perform_create(self, serializer):
        user = self.request.user
        if not user.office:
            raise PermissionDenied("You must belong to an office to perform this action.")
            
        model = self.serializer_class.Meta.model
        if model == LaundryOffice:
            instance = serializer.save()
        elif model == OrderItem:
            order = serializer.validated_data.get('order')
            if order and order.office != user.office:
                raise PermissionDenied("Invalid order for your office.")
            instance = serializer.save()
        else:
            instance = serializer.save(office=user.office)
            
        logger.info("[TenantView] User '%s' created a new '%s' instance (ID: %s) for office '%s'", user.email, model.__name__, instance.id, user.office.name)
            
        # Audit Trail Logging
        if model in [Order]:
            ActionLog.objects.create(
                office=user.office,
                user=user,
                action=f"{model.__name__.upper()}_CREATED",
                details=f"Created ID {instance.id}"
            )
            
            # Trigger WhatsApp notifications in background after transaction commit
            if instance.current_status.is_completed_state:
                from .whatsapp import send_whatsapp_order_completed
                run_in_background(send_whatsapp_order_completed, instance)
            else:
                from .whatsapp import send_whatsapp_order_received
                run_in_background(send_whatsapp_order_received, instance)

    def perform_update(self, serializer):
        model = self.serializer_class.Meta.model
        was_completed = False
        old_status_name = None
        if model == Order:
            try:
                old_order = Order.objects.get(pk=serializer.instance.pk)
                was_completed = old_order.current_status.is_completed_state
                old_status_name = old_order.current_status.name
            except Order.DoesNotExist:
                pass

        instance = serializer.save()
        user = self.request.user
        
        if user.office:
            logger.info("[TenantView] User '%s' updated '%s' instance (ID: %s) for office '%s'", user.email, model.__name__, instance.id, user.office.name)
        
        # Audit Trail Logging
        if model in [Order] and user.office:
            ActionLog.objects.create(
                office=user.office,
                user=user,
                action=f"{model.__name__.upper()}_UPDATED",
                details=f"Updated ID {instance.id}"
            )
            
            # Trigger Web Push notification if status changed
            if old_status_name and instance.current_status.name != old_status_name:
                from .push_notifications import notify_order_status_change
                notify_order_status_change(instance)
            
            # Trigger WhatsApp if transitioned to completed
            if instance.current_status.is_completed_state and not was_completed:
                from .whatsapp import send_whatsapp_order_completed
                run_in_background(send_whatsapp_order_completed, instance)


# LaundryOffice
class LaundryOfficeListCreateView(BaseTenantView, generics.ListCreateAPIView):
    queryset = LaundryOffice.objects.all()
    serializer_class = LaundryOfficeSerializer

class LaundryOfficeRetrieveUpdateDestroyView(BaseTenantView, generics.RetrieveUpdateDestroyAPIView):
    queryset = LaundryOffice.objects.all()
    serializer_class = LaundryOfficeSerializer

# ServiceType
class ServiceTypeListCreateView(BaseTenantView, generics.ListCreateAPIView):
    queryset = ServiceType.objects.select_related('office').all()
    serializer_class = ServiceTypeSerializer

class ServiceTypeRetrieveUpdateDestroyView(BaseTenantView, generics.RetrieveUpdateDestroyAPIView):
    queryset = ServiceType.objects.select_related('office').all()
    serializer_class = ServiceTypeSerializer

# Category
class CategoryListCreateView(BaseTenantView, generics.ListCreateAPIView):
    queryset = Category.objects.select_related('office').all()
    serializer_class = CategorySerializer

class CategoryRetrieveUpdateDestroyView(BaseTenantView, generics.RetrieveUpdateDestroyAPIView):
    queryset = Category.objects.select_related('office').all()
    serializer_class = CategorySerializer

# ItemPricing
class ItemPricingListCreateView(BaseTenantView, generics.ListCreateAPIView):
    queryset = ItemPricing.objects.select_related('office', 'category', 'service_type').all()
    serializer_class = ItemPricingSerializer

class ItemPricingRetrieveUpdateDestroyView(BaseTenantView, generics.RetrieveUpdateDestroyAPIView):
    queryset = ItemPricing.objects.select_related('office', 'category', 'service_type').all()
    serializer_class = ItemPricingSerializer

# OrderStatus
class OrderStatusListCreateView(BaseTenantView, generics.ListCreateAPIView):
    queryset = OrderStatus.objects.select_related('office').all()
    serializer_class = OrderStatusSerializer

class OrderStatusRetrieveUpdateDestroyView(BaseTenantView, generics.RetrieveUpdateDestroyAPIView):
    queryset = OrderStatus.objects.select_related('office').all()
    serializer_class = OrderStatusSerializer

# Order
class OrderListCreateView(BaseTenantView, generics.ListCreateAPIView):
    queryset = Order.objects.select_related('office', 'current_status').prefetch_related('items').all()
    serializer_class = OrderSerializer

class OrderRetrieveUpdateDestroyView(BaseTenantView, generics.RetrieveUpdateDestroyAPIView):
    queryset = Order.objects.select_related('office', 'current_status').prefetch_related('items').all()
    serializer_class = OrderSerializer

# OrderItem
class OrderItemListCreateView(BaseTenantView, generics.ListCreateAPIView):
    queryset = OrderItem.objects.select_related('order', 'item_pricing').all()
    serializer_class = OrderItemSerializer

    def get_queryset(self):
        user = self.request.user
        if not user.office:
            return self.queryset.none()
        return self.queryset.filter(order__office=user.office)

class OrderItemRetrieveUpdateDestroyView(BaseTenantView, generics.RetrieveUpdateDestroyAPIView):
    queryset = OrderItem.objects.select_related('order', 'item_pricing').all()
    serializer_class = OrderItemSerializer

    def get_queryset(self):
        user = self.request.user
        if not user.office:
            return self.queryset.none()
        return self.queryset.filter(order__office=user.office)

# Sub Users
class SubUserListCreateView(generics.ListCreateAPIView):
    serializer_class = SubUserSerializer
    permission_classes = [IsOfficeAdmin, TierLimitPermission]
    pagination_class = None

    def get_queryset(self):
        user = self.request.user
        if not user.office:
            return User.objects.none()
        return User.objects.filter(office=user.office, is_office_admin=False)

    def perform_create(self, serializer):
        user = self.request.user
        if not user.office:
            raise PermissionDenied("You must belong to an office to create users.")
        serializer.save(office=user.office, is_staff=False, is_superuser=False)

class SubUserRetrieveUpdateDestroyView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = SubUserSerializer
    permission_classes = [IsOfficeAdmin]

    def get_queryset(self):
        user = self.request.user
        if not user.office:
            return User.objects.none()
        return User.objects.filter(office=user.office, is_office_admin=False)

# Dashboards
class OfficeOperationsDashboardAPIView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request, *args, **kwargs):
        user = request.user
        if not user.office:
            raise PermissionDenied("You must belong to an office.")

        now = timezone.now()
        orders = Order.objects.filter(office=user.office)
        
        stats = orders.aggregate(
            total_orders_today=Count('id', filter=Q(created_at__date=now.date())),
            pending_orders=Count('id', filter=Q(current_status__is_completed_state=False)),
            completed_orders=Count('id', filter=Q(current_status__is_completed_state=True)),
            overdue_orders=Count('id', filter=Q(current_status__is_completed_state=False, due_date__lt=now)),
        )
        
        recent = orders.select_related('current_status').order_by('-created_at')[:5]
        recent_serialized = OrderSerializer(recent, many=True).data

        return Response({
            "total_orders_today": stats['total_orders_today'] or 0,
            "pending_orders": stats['pending_orders'] or 0,
            "completed_orders": stats['completed_orders'] or 0,
            "overdue_orders": stats['overdue_orders'] or 0,
            "recent_orders": recent_serialized
        })

class OfficeFinancialDashboardAPIView(APIView):
    permission_classes = [IsOfficeAdmin]

    def get(self, request, *args, **kwargs):
        user = request.user
        if not user.office:
            raise PermissionDenied("You must belong to an office.")

        orders = Order.objects.filter(office=user.office)
        
        now = timezone.now()
        this_month_orders = orders.filter(created_at__year=now.year, created_at__month=now.month)

        total_revenue_all_time = orders.aggregate(Sum('total_price'))['total_price__sum'] or 0.00
        total_revenue_this_month = this_month_orders.aggregate(Sum('total_price'))['total_price__sum'] or 0.00
        
        total_outstanding_balances = orders.annotate(
            balance=F('total_price') - F('amount_paid')
        ).filter(balance__gt=0).aggregate(Sum('balance'))['balance__sum'] or 0.00
        
        top_items = OrderItem.objects.filter(order__office=user.office) \
            .values('item_pricing__name') \
            .annotate(total_sold=Sum('quantity')) \
            .order_by('-total_sold')[:5]

        return Response({
            "total_revenue_all_time": total_revenue_all_time,
            "revenue_this_month": total_revenue_this_month,
            "total_outstanding_balances": total_outstanding_balances,
            "top_selling_items": list(top_items)
        })

# Integrations
class PaystackWebhookView(APIView):
    permission_classes = [] # Webhooks shouldn't require our JWT auth
    
    def post(self, request, *args, **kwargs):
        from django.conf import settings
        # Secure Webhook: Verify Paystack signature in production/non-debug mode
        if not settings.DEBUG:
            paystack_signature = request.headers.get('x-paystack-signature')
            if not paystack_signature:
                logger.warning("[Webhook] Missing x-paystack-signature header.")
                return Response({"error": "Missing signature header"}, status=401)
                
            import hmac
            import hashlib
            secret = getattr(settings, 'PAYSTACK_SECRET_KEY', '').encode('utf-8')
            computed_sig = hmac.new(secret, request._request.body, hashlib.sha512).hexdigest()
            
            if not hmac.compare_digest(computed_sig, paystack_signature):
                logger.warning("[Webhook] Invalid Paystack signature provided.")
                return Response({"error": "Invalid signature"}, status=401)

        event = request.data.get('event')
        data = request.data.get('data', {})
        logger.info("[Webhook] Received event: %s", event)
        
        if event == 'charge.success':
            reference = data.get('reference')
            customer_email = data.get('customer', {}).get('email')
            logger.info("[Webhook] Successful charge event. Ref: %s, Customer: %s", reference, customer_email)
            
            # Look up office by pending reference first
            office = LaundryOffice.objects.filter(preferences__pending_subscription__reference=reference).first()
            
            # Fallback to looking up office by customer admin email (for renewal events)
            if not office and customer_email:
                user_obj = User.objects.filter(email=customer_email, is_office_admin=True).first()
                if user_obj and user_obj.office:
                    office = user_obj.office
            
            if office:
                pending = office.preferences.get('pending_subscription', {})
                if pending and pending.get('reference') == reference:
                    # Upgrade initiated from app / browser
                    tier = pending.get('tier', 'free')
                    office.subscription_tier = tier
                    office.preferences.pop('pending_subscription', None)
                else:
                    # Recurring subscription payment from Paystack Plan billing
                    plan_code = data.get('plan', {}).get('plan_code')
                    from django.conf import settings
                    if plan_code == getattr(settings, 'PAYSTACK_PLAN_PREMIUM', 'premium'):
                        office.subscription_tier = 'premium'
                    elif plan_code == getattr(settings, 'PAYSTACK_PLAN_PRO', 'pro'):
                        office.subscription_tier = 'pro'
                    elif plan_code == getattr(settings, 'PAYSTACK_PLAN_STARTER', 'starter'):
                        office.subscription_tier = 'starter'
                
                if not office.preferences:
                    office.preferences = {}
                office.preferences['subscription_status'] = 'active'
                office.save()
                logger.info("[Webhook] Activated/Renewed subscription to tier '%s' for office: %s", office.subscription_tier, office.name)
            else:
                logger.warning("[Webhook] Charge success webhook received but no matching office found (Ref: %s, Email: %s)", reference, customer_email)
                
        elif event in ['subscription.disable', 'subscription.cancel']:
            customer_email = data.get('customer', {}).get('email')
            logger.warning("[Webhook] Subscription disabled/cancelled event for customer: %s", customer_email)
            if customer_email:
                user_obj = User.objects.filter(email=customer_email, is_office_admin=True).first()
                if user_obj and user_obj.office:
                    office = user_obj.office
                    office.subscription_tier = 'free'
                    if not office.preferences:
                        office.preferences = {}
                    office.preferences['subscription_status'] = 'disabled'
                    office.save()
                    logger.warning("[Webhook] Downgraded office %s to FREE due to cancellation/disable notification.", office.name)
            
        return Response(status=200)

class InitializeSubscriptionView(APIView):
    permission_classes = [IsOfficeAdmin]

    def post(self, request):
        import uuid
        user = request.user
        if not user.office:
            logger.warning("[Billing] Init Failed: User '%s' is not associated with an office.", user.email)
            return Response({"error": "No office associated with user"}, status=400)
            
        tier = request.data.get('tier')
        if tier not in ['starter', 'pro', 'premium']:
            logger.warning("[Billing] Init Failed: Invalid subscription tier '%s' requested by '%s'.", tier, user.email)
            return Response({"error": "Invalid subscription tier"}, status=400)
            
        prices = {
            'starter': 250000, # ₦2,500
            'pro': 750000,     # ₦7,500
            'premium': 1500000  # ₦15,000
        }
        amount_kobo = prices[tier]
        reference = f"sub_{uuid.uuid4().hex[:12]}"
        
        logger.info("[Billing] Initializing Paystack transaction for user '%s', office '%s', tier '%s', ref '%s'.", user.email, user.office.name, tier, reference)
        
        # Load subscription plan code from settings
        from django.conf import settings
        plan_code = getattr(settings, f"PAYSTACK_PLAN_{tier.upper()}", None)
        if plan_code and "placeholder" in plan_code:
            plan_code = None # Ignore placeholder plan code for simple sandbox payments
            
        # Initialize Paystack payment
        from .paystack import initialize_payment
        res = initialize_payment(email=user.email, amount_kobo=amount_kobo, reference=reference, plan_code=plan_code)
        
        if res.get('status') == True:
            # Save pending reference in office preferences
            office = user.office
            if not office.preferences:
                office.preferences = {}
            office.preferences['pending_subscription'] = {
                'reference': reference,
                'tier': tier,
                'amount': amount_kobo // 100
            }
            office.save()
            logger.info("[Billing] Paystack checkout URL created for user '%s': %s", user.email, res['data']['authorization_url'])
            return Response({
                "status": "success",
                "authorization_url": res['data']['authorization_url'],
                "reference": reference
            })
        else:
            logger.error("[Billing] Paystack checkout initialization failed: %s", res)
            return Response({"error": res.get('message', 'Failed to initialize payment')}, status=400)

class VerifySubscriptionView(APIView):
    permission_classes = [IsOfficeAdmin]

    def get(self, request):
        user = request.user
        reference = request.query_params.get('reference')
        if not reference:
            logger.warning("[Billing] Verify Failed: Missing reference parameter in request from user '%s'.", user.email)
            return Response({"error": "Reference parameter is required"}, status=400)
            
        office = user.office
        if not office:
            logger.warning("[Billing] Verify Failed: User '%s' has no office.", user.email)
            return Response({"error": "No office associated with user"}, status=400)
            
        logger.info("[Billing] Verifying transaction reference '%s' for office '%s'.", reference, office.name)
        pending = office.preferences.get('pending_subscription')
        if not pending or pending.get('reference') != reference:
            logger.warning("[Billing] Verify Failed: Reference '%s' does not match pending reference for office '%s'.", reference, office.name)
            return Response({"error": "No pending subscription found for this reference"}, status=400)
            
        from .paystack import verify_payment
        res = verify_payment(reference)
        
        if res.get('status') == True and res['data']['status'] == 'success':
            tier = pending.get('tier')
            office.subscription_tier = tier
            # Clear pending subscription
            office.preferences.pop('pending_subscription', None)
            office.save()
            logger.info("[Billing] Payment successfully verified. Office '%s' upgraded to tier '%s'.", office.name, tier)
            return Response({
                "status": "success",
                "message": f"Subscription successfully upgraded to {tier}.",
                "tier": tier
            })
        else:
            logger.warning("[Billing] Payment verification pending/failed for reference '%s'. Paystack Response: %s", reference, res)
            return Response({"error": "Payment verification failed or payment not completed"}, status=400)

class CurrentUserView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        user = request.user
        return Response({
            "id": str(user.id),
            "username": user.username,
            "email": user.email,
            "first_name": user.first_name,
            "last_name": user.last_name,
            "is_office_admin": user.is_office_admin,
            "office_id": str(user.office.id) if user.office else None,
            "office_name": user.office.name if user.office else None,
            "office_contact_info": user.office.contact_info if user.office else "",
            "subscription_tier": user.office.subscription_tier if user.office else 'free',
            "office_preferences": user.office.preferences if user.office else {}
        })

class RegisterOfficeView(APIView):
    permission_classes = [] # Public endpoint

    def post(self, request):
        office_name = request.data.get('office_name')
        email = request.data.get('email')
        password = request.data.get('password')
        
        if not office_name or not email or not password:
            logger.warning("[Register] Failed registration attempt: missing parameters.")
            return Response({"error": "Office name, email, and password are required."}, status=400)
            
        if User.objects.filter(email=email).exists():
            logger.warning("[Register] Failed registration attempt: email '%s' already exists.", email)
            return Response({"error": "A user with this email already exists."}, status=400)
            
        logger.info("[Register] Registering new office '%s' with email '%s'...", office_name, email)
        from django.db import transaction
        try:
            with transaction.atomic():
                # 1. Create office
                office = LaundryOffice.objects.create(
                    name=office_name,
                    subscription_tier='free'
                )
                
                # 2. Create user (owner / admin)
                user = User.objects.create(
                    username=email,
                    email=email,
                    office=office,
                    is_office_admin=True
                )
                user.set_password(password)
                user.save()
                
                # Link primary branch
                user.branches.add(office)
                
                # 3. Initialize default data (Categories, ServiceTypes, ItemPricing)
                clothing = Category.objects.create(office=office, name="Clothing")
                household = Category.objects.create(office=office, name="Household")
                
                wash_iron = ServiceType.objects.create(office=office, name="Wash & Iron")
                dry_clean = ServiceType.objects.create(office=office, name="Dry Clean")
                iron_only = ServiceType.objects.create(office=office, name="Ironing Only")
                
                # Default pricing
                ItemPricing.objects.create(office=office, category=clothing, service_type=wash_iron, name="Shirt", price=1500)
                ItemPricing.objects.create(office=office, category=clothing, service_type=wash_iron, name="Trousers", price=1200)
                ItemPricing.objects.create(office=office, category=clothing, service_type=dry_clean, name="Suit Jacket", price=2500)
                ItemPricing.objects.create(office=office, category=household, service_type=wash_iron, name="Bedsheet", price=2500)
                
            # Send welcome registration email
            from .emails import send_welcome_registration
            send_welcome_registration(email=user.email, office_name=office.name)
            
            logger.info("[Register] Successfully registered office '%s' (ID: %s) for admin email '%s'", office.name, office.id, user.email)
            return Response({
                "status": "success",
                "message": "Office and admin account registered successfully.",
                "office_name": office.name,
                "email": user.email
            }, status=201)
        except Exception as e:
            logger.error("[Register] Registration failed for office '%s', email '%s': %s", office_name, email, e, exc_info=True)
            return Response({"error": f"Registration failed: {str(e)}"}, status=500)


class BranchListCreateView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        user = request.user
        # Self-healing: Ensure user's active office is always in user.branches
        if user.office and not user.branches.filter(id=user.office.id).exists():
            user.branches.add(user.office)

        branches = user.branches.all()
        data = [{
            "id": str(b.id),
            "name": b.name,
            "contact_info": b.contact_info,
            "subscription_tier": b.subscription_tier,
            "is_active": user.office_id == b.id
        } for b in branches]
        return Response(data)

    def post(self, request):
        name = request.data.get('name')
        contact_info = request.data.get('contact_info', '')
        
        if not name:
            logger.warning("[Branch] Failed branch creation: missing name parameter from '%s'", user.email)
            return Response({"error": "Branch name is required."}, status=400)
            
        user = request.user
        if not user.is_office_admin:
            logger.warning("[Branch] Forbidden branch creation attempt by non-admin user '%s'", user.email)
            return Response({"error": "Only office admins / owners can create new branches."}, status=403)
            
        current_branches_count = user.branches.count()
        tier = user.office.subscription_tier if user.office else 'free'
        if not tier or tier.lower() not in ['starter', 'pro', 'premium']:
            tier = 'free'
        else:
            tier = tier.lower()
        
        # Enforce tier-based branch limit
        if tier == 'free' and current_branches_count >= 1:
            logger.warning("[Branch] Limit reached: Free tier branch limit (1) exceeded by '%s'", user.email)
            return Response({"error": "Free tier allows a maximum of 1 branch. Please upgrade your subscription."}, status=403)
        elif tier == 'starter' and current_branches_count >= 1:
            logger.warning("[Branch] Limit reached: Starter tier branch limit (1) exceeded by '%s'", user.email)
            return Response({"error": "Starter tier allows a maximum of 1 branch. Please upgrade your subscription to Pro or Premium."}, status=403)
        elif tier == 'pro' and current_branches_count >= 3:
            logger.warning("[Branch] Limit reached: Pro tier branch limit (3) exceeded by '%s'", user.email)
            return Response({"error": "Pro tier allows a maximum of 3 branches. Please upgrade your subscription to Premium."}, status=403)
            
        logger.info("[Branch] User '%s' is registering a new branch '%s' under tier '%s'...", user.email, name, tier)
        from django.db import transaction
        try:
            with transaction.atomic():
                # Self-healing before switching: Link user's active office to branches relation
                if user.office and not user.branches.filter(id=user.office.id).exists():
                    user.branches.add(user.office)

                branch = LaundryOffice.objects.create(
                    name=name,
                    contact_info=contact_info,
                    subscription_tier=tier
                )
                
                user.branches.add(branch)
                user.office = branch
                user.save()
                
                # Populate new branch with initial items
                clothing = Category.objects.create(office=branch, name="Clothing")
                household = Category.objects.create(office=branch, name="Household")
                
                wash_iron = ServiceType.objects.create(office=branch, name="Wash & Iron")
                dry_clean = ServiceType.objects.create(office=branch, name="Dry Clean")
                iron_only = ServiceType.objects.create(office=branch, name="Ironing Only")
                
                ItemPricing.objects.create(office=branch, category=clothing, service_type=wash_iron, name="Shirt", price=1500)
                ItemPricing.objects.create(office=branch, category=clothing, service_type=wash_iron, name="Trousers", price=1200)
                ItemPricing.objects.create(office=branch, category=clothing, service_type=dry_clean, name="Suit Jacket", price=2500)
                ItemPricing.objects.create(office=branch, category=household, service_type=wash_iron, name="Bedsheet", price=2500)
                
            logger.info("[Branch] Successfully created and switched user '%s' to new branch '%s' (ID: %s)", user.email, branch.name, branch.id)
            return Response({
                "status": "success",
                "message": f"Branch '{branch.name}' registered and set as active workspace successfully.",
                "id": str(branch.id),
                "name": branch.name,
                "subscription_tier": branch.subscription_tier
            }, status=201)
        except Exception as e:
            logger.error("[Branch] Failed to register branch '%s' for '%s': %s", name, user.email, e, exc_info=True)
            return Response({"error": f"Failed to register branch: {str(e)}"}, status=500)


class BranchSwitchView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        office_id = request.data.get('office_id')
        if not office_id:
            logger.warning("[Branch] BranchSwitch Failed: Missing office_id parameter.")
            return Response({"error": "Office ID is required."}, status=400)
            
        user = request.user
        target_office = user.branches.filter(id=office_id).first()
        if not target_office:
            logger.warning("[Branch] BranchSwitch Forbidden: User '%s' does not have access to branch '%s'", user.email, office_id)
            return Response({"error": "You do not have access to this branch office workspace."}, status=403)
            
        user.office = target_office
        user.save()
        
        logger.info("[Branch] User '%s' switched active branch workspace to '%s' (ID: %s)", user.email, target_office.name, target_office.id)
        return Response({
            "status": "success",
            "message": f"Switched active workspace to branch: {target_office.name}",
            "office_id": str(target_office.id),
            "office_name": target_office.name,
            "subscription_tier": target_office.subscription_tier
        })


import random

class RequestPasswordResetView(APIView):
    permission_classes = [] # Public endpoint

    def post(self, request):
        email = request.data.get('email', '').strip()
        if not email:
            logger.warning("[Auth] Password reset request failed: Missing email.")
            return Response({"error": "Email is required."}, status=400)
            
        user_exists = User.objects.filter(email=email).exists()
        logger.info("[Auth] Password reset requested for email '%s'", email)
        
        if user_exists:
            # 1. Invalidate all older OTPs for this email to prevent multiple usage
            PasswordResetOTP.objects.filter(email=email, is_used=False).update(is_used=True)
            
            # 2. Generate random 6-digit verification code
            otp = f"{random.randint(100000, 999999)}"
            
            # 3. Create active verification OTP code valid for 15 minutes
            expires_at = timezone.now() + timezone.timedelta(minutes=15)
            PasswordResetOTP.objects.create(
                email=email,
                otp=otp,
                expires_at=expires_at
            )
            
            # 4. Dispatch the verification email
            from .emails import send_password_reset_otp
            send_password_reset_otp(email=email, otp=otp)
            logger.info("[Auth] Password reset OTP sent to '%s'", email)
        else:
            logger.warning("[Auth] Password reset requested for non-existent email '%s'", email)
            
        return Response({
            "status": "success",
            "message": "If a matching account exists, a 6-digit verification code has been sent to your email."
        })


class ConfirmPasswordResetView(APIView):
    permission_classes = [] # Public endpoint

    def post(self, request):
        email = request.data.get('email', '').strip()
        otp = request.data.get('otp', '').strip()
        password = request.data.get('password')
        
        if not email or not otp or not password:
            logger.warning("[Auth] ConfirmPasswordReset Failed: Missing parameters.")
            return Response({"error": "Email, verification code, and new password are required."}, status=400)
            
        if len(password) < 6:
            logger.warning("[Auth] ConfirmPasswordReset Failed: New password for '%s' too short.", email)
            return Response({"error": "Password must be at least 6 characters long."}, status=400)
            
        logger.info("[Auth] Confirm password reset started for email '%s'...", email)
        from django.db import transaction
        try:
            with transaction.atomic():
                # Query matching active OTP code with row locking
                otp_record = PasswordResetOTP.objects.select_for_update().filter(
                    email=email,
                    otp=otp,
                    is_used=False,
                    expires_at__gt=timezone.now()
                ).first()
                
                if not otp_record:
                    logger.warning("[Auth] ConfirmPasswordReset Failed: Invalid/expired OTP record for '%s'", email)
                    return Response({"error": "Invalid or expired verification code."}, status=400)
                    
                # Mark as used immediately to avoid double spend/concurrency usage
                otp_record.is_used = True
                otp_record.save()
                
                # Fetch matching user and reset password
                user = User.objects.get(email=email)
                user.set_password(password)
                user.save()
                
            logger.info("[Auth] Password reset successfully verified and saved for '%s'", email)
            return Response({
                "status": "success",
                "message": "Your password has been reset successfully."
            })
        except User.DoesNotExist:
            logger.warning("[Auth] ConfirmPasswordReset Failed: User '%s' not found.", email)
            return Response({"error": "User with this email does not exist."}, status=400)
        except Exception as e:
            logger.error("[Auth] ConfirmPasswordReset Exception for '%s': %s", email, e, exc_info=True)
            return Response({"error": f"Password reset failed: {str(e)}"}, status=500)


class VerifyOTPView(APIView):
    permission_classes = [] # Public endpoint

    def post(self, request):
        email = request.data.get('email', '').strip()
        otp = request.data.get('otp', '').strip()
        
        if not email or not otp:
            logger.warning("[Auth] VerifyOTP Failed: Missing parameters.")
            return Response({"error": "Email and verification code are required."}, status=400)
            
        logger.info("[Auth] Verifying OTP for email '%s'...", email)
        otp_record = PasswordResetOTP.objects.filter(
            email=email,
            otp=otp,
            is_used=False,
            expires_at__gt=timezone.now()
        ).first()
        
        if not otp_record:
            logger.warning("[Auth] VerifyOTP Failed: Invalid/expired OTP for '%s'", email)
            return Response({"error": "Invalid or expired verification code."}, status=400)
            
        logger.info("[Auth] OTP verified successfully for '%s'", email)
        return Response({
            "status": "success",
            "message": "Verification code is valid."
        })


class SavePushSubscriptionAPIView(APIView):
    permission_classes = []  # Public endpoint

    def post(self, request):
        customer_phone = request.data.get('customer_phone', '').strip()
        endpoint = request.data.get('endpoint', '').strip()
        keys = request.data.get('keys', {})
        p256dh = keys.get('p256dh', '').strip()
        auth = keys.get('auth', '').strip()

        if not customer_phone or not endpoint or not p256dh or not auth:
            logger.warning("[PushNotification] Subscription registration failed: missing parameters.")
            return Response({"error": "Missing subscription parameters."}, status=400)

        from operations.models import WebPushSubscription, Customer
        customer = Customer.objects.filter(phone=customer_phone, is_deleted=False).first()
        
        subscription, created = WebPushSubscription.objects.update_or_create(
            endpoint=endpoint,
            defaults={
                'customer': customer,
                'customer_phone': customer_phone,
                'p256dh': p256dh,
                'auth': auth,
                'is_deleted': False
            }
        )

        logger.info("[PushNotification] Saved subscription for customer %s (created: %s, linked customer: %s)", customer_phone, created, customer)
        return Response({"status": "success", "message": "Subscription saved."})
