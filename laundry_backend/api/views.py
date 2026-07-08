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

    def perform_update(self, serializer):
        instance = serializer.save()
        user = self.request.user
        model = self.serializer_class.Meta.model
        
        # Audit Trail Logging
        if model in [Order] and user.office:
            ActionLog.objects.create(
                office=user.office,
                user=user,
                action=f"{model.__name__.upper()}_UPDATED",
                details=f"Updated ID {instance.id}"
            )


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
        # In a real app, verify Paystack signature here using HMAC
        event = request.data.get('event')
        data = request.data.get('data', {})
        
        if event == 'charge.success':
            reference = data.get('reference')
            # Look up office by reference, update subscription, log payment, etc.
            print(f"Payment successful for reference: {reference}")
            
        return Response(status=200)
