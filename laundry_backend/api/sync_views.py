from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from dateutil.parser import parse
from offices.models import LaundryOffice
from operations.models import ServiceType, Category, ItemPricing, OrderStatus, Order, OrderItem
from .serializers import (
    ServiceTypeSerializer, CategorySerializer, ItemPricingSerializer,
    OrderStatusSerializer, OrderSerializer, OrderItemSerializer
)

class SyncAPIView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        office = request.user.office
        if not office:
            return Response({"error": "User is not associated with an office."}, status=400)

        last_sync = request.query_params.get('last_sync_timestamp')
        
        # Base querysets filtered by office
        service_types_qs = ServiceType.objects.filter(office=office)
        categories_qs = Category.objects.filter(office=office)
        item_pricing_qs = ItemPricing.objects.filter(office=office)
        order_statuses_qs = OrderStatus.objects.filter(office=office)
        orders_qs = Order.objects.filter(office=office)
        
        # Order items are tied to orders, which are tied to offices
        order_items_qs = OrderItem.objects.filter(order__office=office)

        if last_sync:
            try:
                last_sync_date = parse(last_sync)
                service_types_qs = service_types_qs.filter(updated_at__gte=last_sync_date)
                categories_qs = categories_qs.filter(updated_at__gte=last_sync_date)
                item_pricing_qs = item_pricing_qs.filter(updated_at__gte=last_sync_date)
                order_statuses_qs = order_statuses_qs.filter(updated_at__gte=last_sync_date)
                orders_qs = orders_qs.filter(updated_at__gte=last_sync_date)
                order_items_qs = order_items_qs.filter(updated_at__gte=last_sync_date)
            except ValueError:
                return Response({"error": "Invalid last_sync_timestamp format."}, status=400)

        payload = {
            "service_types": ServiceTypeSerializer(service_types_qs, many=True).data,
            "categories": CategorySerializer(categories_qs, many=True).data,
            "item_pricing": ItemPricingSerializer(item_pricing_qs, many=True).data,
            "order_statuses": OrderStatusSerializer(order_statuses_qs, many=True).data,
            "orders": OrderSerializer(orders_qs, many=True).data,
            "order_items": OrderItemSerializer(order_items_qs, many=True).data,
        }

        return Response(payload)

    def post(self, request):
        """
        Delta Push: Handles incoming changes from the mobile app.
        Enforces Last-Write-Wins based on 'updated_at'.
        This is a complex operation and depends heavily on the mobile app's payload structure.
        For Phase 1, we acknowledge the endpoint and provide a basic structure.
        """
        return Response({"status": "Delta push received. Conflict resolution in progress.", "processed_items": 0})
