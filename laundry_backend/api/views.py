from django.contrib.auth import get_user_model
from django.db.models import Sum, Count, F
from django.utils import timezone
from rest_framework import generics, permissions
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.exceptions import PermissionDenied
from rest_framework.exceptions import PermissionDenied
from offices.models import LaundryOffice
from operations.models import ServiceType, Category, ItemPricing, OrderStatus, Order, OrderItem, ActionLog
from .permissions import IsOfficeAdmin, TierLimitPermission
from .serializers import (
    LaundryOfficeSerializer, ServiceTypeSerializer, CategorySerializer,
    ItemPricingSerializer, OrderStatusSerializer, OrderSerializer, OrderItemSerializer,
    SubUserSerializer
)

User = get_user_model()

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
            
        # Audit Trail Logging
        if model in [Order]:
            ActionLog.objects.create(
                office=user.office,
                user=user,
                action=f"{model.__name__.upper()}_CREATED",
                details=f"Created ID {instance.id}"
            )
            
            # Trigger WhatsApp if created as completed
            if instance.current_status.is_completed_state:
                from .whatsapp import send_whatsapp_order_completed
                send_whatsapp_order_completed(instance)

    def perform_update(self, serializer):
        model = self.serializer_class.Meta.model
        was_completed = False
        if model == Order:
            try:
                old_order = Order.objects.get(pk=serializer.instance.pk)
                was_completed = old_order.current_status.is_completed_state
            except Order.DoesNotExist:
                pass

        instance = serializer.save()
        user = self.request.user
        
        # Audit Trail Logging
        if model in [Order] and user.office:
            ActionLog.objects.create(
                office=user.office,
                user=user,
                action=f"{model.__name__.upper()}_UPDATED",
                details=f"Updated ID {instance.id}"
            )
            
            # Trigger WhatsApp if transitioned to completed
            if instance.current_status.is_completed_state and not was_completed:
                from .whatsapp import send_whatsapp_order_completed
                send_whatsapp_order_completed(instance)


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
        
        total_orders_today = orders.filter(created_at__date=now.date()).count()
        pending_orders = orders.filter(current_status__is_completed_state=False).count()
        completed_orders = orders.filter(current_status__is_completed_state=True).count()
        overdue_orders = orders.filter(
            current_status__is_completed_state=False, 
            due_date__lt=now
        ).count()
        
        recent = orders.select_related('current_status').order_by('-created_at')[:5]
        recent_serialized = OrderSerializer(recent, many=True).data

        return Response({
            "total_orders_today": total_orders_today,
            "pending_orders": pending_orders,
            "completed_orders": completed_orders,
            "overdue_orders": overdue_orders,
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
        event = request.data.get('event')
        data = request.data.get('data', {})
        
        if event == 'charge.success':
            reference = data.get('reference')
            customer_email = data.get('customer', {}).get('email')
            print(f"Payment successful for reference: {reference}, email: {customer_email}")
            
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
                print(f"Webhook: Activated/Renewed subscription to {office.subscription_tier} for office: {office.name}")
                
        elif event in ['subscription.disable', 'subscription.cancel']:
            customer_email = data.get('customer', {}).get('email')
            print(f"Subscription disabled/cancelled for customer: {customer_email}")
            if customer_email:
                user_obj = User.objects.filter(email=customer_email, is_office_admin=True).first()
                if user_obj and user_obj.office:
                    office = user_obj.office
                    office.subscription_tier = 'free'
                    if not office.preferences:
                        office.preferences = {}
                    office.preferences['subscription_status'] = 'disabled'
                    office.save()
                    print(f"Webhook: Downgraded office {office.name} to FREE due to cancel/renewal failure.")
            
        return Response(status=200)

class InitializeSubscriptionView(APIView):
    permission_classes = [IsOfficeAdmin]

    def post(self, request):
        import uuid
        user = request.user
        if not user.office:
            return Response({"error": "No office associated with user"}, status=400)
            
        tier = request.data.get('tier')
        if tier not in ['starter', 'pro', 'premium']:
            return Response({"error": "Invalid subscription tier"}, status=400)
            
        prices = {
            'starter': 250000, # ₦2,500
            'pro': 750000,     # ₦7,500
            'premium': 1500000  # ₦15,000
        }
        amount_kobo = prices[tier]
        reference = f"sub_{uuid.uuid4().hex[:12]}"
        
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
            return Response({
                "status": "success",
                "authorization_url": res['data']['authorization_url'],
                "reference": reference
            })
        else:
            return Response({"error": res.get('message', 'Failed to initialize payment')}, status=400)

class VerifySubscriptionView(APIView):
    permission_classes = [IsOfficeAdmin]

    def get(self, request):
        user = request.user
        reference = request.query_params.get('reference')
        if not reference:
            return Response({"error": "Reference parameter is required"}, status=400)
            
        office = user.office
        if not office:
            return Response({"error": "No office associated with user"}, status=400)
            
        pending = office.preferences.get('pending_subscription')
        if not pending or pending.get('reference') != reference:
            return Response({"error": "No pending subscription found for this reference"}, status=400)
            
        from .paystack import verify_payment
        res = verify_payment(reference)
        
        if res.get('status') == True and res['data']['status'] == 'success':
            tier = pending.get('tier')
            office.subscription_tier = tier
            # Clear pending subscription
            office.preferences.pop('pending_subscription', None)
            office.save()
            return Response({
                "status": "success",
                "message": f"Subscription successfully upgraded to {tier}.",
                "tier": tier
            })
        else:
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
            "subscription_tier": user.office.subscription_tier if user.office else 'free'
        })

class RegisterOfficeView(APIView):
    permission_classes = [] # Public endpoint

    def post(self, request):
        office_name = request.data.get('office_name')
        email = request.data.get('email')
        password = request.data.get('password')
        
        if not office_name or not email or not password:
            return Response({"error": "Office name, email, and password are required."}, status=400)
            
        if User.objects.filter(email=email).exists():
            return Response({"error": "A user with this email already exists."}, status=400)
            
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
            
            return Response({
                "status": "success",
                "message": "Office and admin account registered successfully.",
                "office_name": office.name,
                "email": user.email
            }, status=201)
        except Exception as e:
            return Response({"error": f"Registration failed: {str(e)}"}, status=500)
