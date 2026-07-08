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
        office = request.user.office
        if not office:
            return Response({"error": "User is not associated with an office."}, status=400)

        data = request.data
        orders_data = data.get('orders', [])
        order_items_data = data.get('order_items', [])

        processed_orders = 0
        processed_items = 0

        # Process Orders
        for order_dict in orders_data:
            order_id = order_dict.get('id')
            if not order_id: continue
            
            try:
                order_obj = Order.objects.get(id=order_id, office=office)
                # Last write wins
                incoming_updated_at = parse(order_dict.get('updated_at', ''))
                if incoming_updated_at > order_obj.updated_at:
                    if order_dict.get('is_deleted', False):
                        order_obj.is_deleted = True
                    else:
                        order_obj.customer_name = order_dict.get('customer_name', order_obj.customer_name)
                        order_obj.customer_phone = order_dict.get('customer_phone', order_obj.customer_phone)
                        order_obj.total_price = order_dict.get('total_price', order_obj.total_price)
                        order_obj.amount_paid = order_dict.get('amount_paid', order_obj.amount_paid)
                        
                        # Handle status which might be an ID or string in the payload depending on frontend
                        status_val = order_dict.get('current_status')
                        if status_val:
                            # Simple approach: assume frontend sends the name for now, or fetch the status object
                            status_obj = OrderStatus.objects.filter(office=office, name=status_val).first()
                            if status_obj:
                                order_obj.current_status = status_obj
                                
                    order_obj.save()
                    processed_orders += 1
            except Order.DoesNotExist:
                if not order_dict.get('is_deleted', False):
                    # Create new
                    status_val = order_dict.get('current_status')
                    status_obj = OrderStatus.objects.filter(office=office, name=status_val).first()
                    Order.objects.create(
                        id=order_id,
                        office=office,
                        customer_name=order_dict.get('customer_name', 'Unknown'),
                        customer_phone=order_dict.get('customer_phone', ''),
                        total_price=order_dict.get('total_price', 0),
                        amount_paid=order_dict.get('amount_paid', 0),
                        current_status=status_obj
                    )
                    processed_orders += 1

        # Process Order Items
        for item_dict in order_items_data:
            item_id = item_dict.get('id')
            order_id = item_dict.get('order_id') # Make sure flutter sends order_id
            pricing_id = item_dict.get('item_pricing_id')
            if not item_id or not order_id or not pricing_id: continue

            try:
                item_obj = OrderItem.objects.get(id=item_id, order__office=office)
                incoming_updated_at = parse(item_dict.get('updated_at', ''))
                if incoming_updated_at > item_obj.updated_at:
                    if item_dict.get('is_deleted', False):
                        item_obj.is_deleted = True
                    else:
                        item_obj.quantity = item_dict.get('quantity', item_obj.quantity)
                        item_obj.unit_price = item_dict.get('unit_price', item_obj.unit_price)
                        item_obj.discount_amount = item_dict.get('discount_amount', item_obj.discount_amount)
                        item_obj.subtotal = item_dict.get('subtotal', item_obj.subtotal)
                    item_obj.save()
                    processed_items += 1
            except OrderItem.DoesNotExist:
                if not item_dict.get('is_deleted', False):
                    try:
                        order_ref = Order.objects.get(id=order_id, office=office)
                        pricing_ref = ItemPricing.objects.get(id=pricing_id, office=office)
                        OrderItem.objects.create(
                            id=item_id,
                            order=order_ref,
                            item_pricing=pricing_ref,
                            quantity=item_dict.get('quantity', 1),
                            unit_price=item_dict.get('unit_price', 0),
                            discount_amount=item_dict.get('discount_amount', 0),
                            subtotal=item_dict.get('subtotal', 0)
                        )
                        processed_items += 1
                    except (Order.DoesNotExist, ItemPricing.DoesNotExist):
                        pass

        return Response({
            "status": "success",
            "processed_orders": processed_orders,
            "processed_items": processed_items
        })
