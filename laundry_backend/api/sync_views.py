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
        categories_data = data.get('categories', [])
        service_types_data = data.get('service_types', [])
        item_pricing_data = data.get('item_pricing', [])

        processed_orders = 0
        processed_items = 0
        processed_configs = 0

        # Process Categories
        for cat_dict in categories_data:
            cat_id = cat_dict.get('id')
            if not cat_id: continue
            try:
                cat_obj = Category.objects.get(id=cat_id, office=office)
                incoming_updated_at = parse(cat_dict.get('updated_at', ''))
                if incoming_updated_at > cat_obj.updated_at:
                    if cat_dict.get('is_deleted', False):
                        cat_obj.is_deleted = True
                    else:
                        cat_obj.name = cat_dict.get('name', cat_obj.name)
                    cat_obj.save()
                    processed_configs += 1
            except Category.DoesNotExist:
                if not cat_dict.get('is_deleted', False):
                    Category.objects.create(
                        id=cat_id,
                        office=office,
                        name=cat_dict.get('name', '')
                    )
                    processed_configs += 1

        # Process Service Types
        for srv_dict in service_types_data:
            srv_id = srv_dict.get('id')
            if not srv_id: continue
            try:
                srv_obj = ServiceType.objects.get(id=srv_id, office=office)
                incoming_updated_at = parse(srv_dict.get('updated_at', ''))
                if incoming_updated_at > srv_obj.updated_at:
                    if srv_dict.get('is_deleted', False):
                        srv_obj.is_deleted = True
                    else:
                        srv_obj.name = srv_dict.get('name', srv_obj.name)
                        srv_obj.description = srv_dict.get('description', srv_obj.description)
                    srv_obj.save()
                    processed_configs += 1
            except ServiceType.DoesNotExist:
                if not srv_dict.get('is_deleted', False):
                    ServiceType.objects.create(
                        id=srv_id,
                        office=office,
                        name=srv_dict.get('name', ''),
                        description=srv_dict.get('description', '')
                    )
                    processed_configs += 1

        # Process Item Pricing
        for ip_dict in item_pricing_data:
            ip_id = ip_dict.get('id')
            if not ip_id: continue
            try:
                ip_obj = ItemPricing.objects.get(id=ip_id, office=office)
                incoming_updated_at = parse(ip_dict.get('updated_at', ''))
                if incoming_updated_at > ip_obj.updated_at:
                    if ip_dict.get('is_deleted', False):
                        ip_obj.is_deleted = True
                    else:
                        ip_obj.name = ip_dict.get('name', ip_obj.name)
                        ip_obj.price = ip_dict.get('price', ip_obj.price)
                    ip_obj.save()
                    processed_configs += 1
            except ItemPricing.DoesNotExist:
                if not ip_dict.get('is_deleted', False):
                    cat_id = ip_dict.get('category_id')
                    srv_id = ip_dict.get('service_type_id')
                    
                    # Resolve category and service type objects
                    cat_obj = None
                    if cat_id:
                        cat_obj = Category.objects.filter(id=cat_id, office=office).first()
                    srv_obj = None
                    if srv_id:
                        srv_obj = ServiceType.objects.filter(id=srv_id, office=office).first()

                    if srv_obj:
                        ItemPricing.objects.create(
                            id=ip_id,
                            office=office,
                            category=cat_obj,
                            service_type=srv_obj,
                            name=ip_dict.get('name', ''),
                            price=ip_dict.get('price', 0)
                        )
                        processed_configs += 1

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
                        order_obj.discount_amount = order_dict.get('discount_amount', order_obj.discount_amount)
                        
                        # Handle status which might be an ID or string in the payload depending on frontend
                        status_val = order_dict.get('current_status')
                        if status_val:
                            status_obj = OrderStatus.objects.filter(office=office, name__iexact=status_val).first()
                            if not status_obj:
                                status_obj = OrderStatus.objects.create(
                                    office=office,
                                    name=status_val,
                                    sequence_order=OrderStatus.objects.filter(office=office).count() + 1,
                                    is_completed_state=(status_val.lower() == 'completed')
                                )
                            order_obj.current_status = status_obj
                                
                    order_obj.save()
                    processed_orders += 1
            except Order.DoesNotExist:
                if not order_dict.get('is_deleted', False):
                    # Create new
                    status_val = order_dict.get('current_status') or 'Pending'
                    status_obj = OrderStatus.objects.filter(office=office, name__iexact=status_val).first()
                    if not status_obj:
                        status_obj = OrderStatus.objects.create(
                            office=office,
                            name=status_val,
                            sequence_order=OrderStatus.objects.filter(office=office).count() + 1,
                            is_completed_state=(status_val.lower() == 'completed')
                        )
                    Order.objects.create(
                        id=order_id,
                        office=office,
                        customer_name=order_dict.get('customer_name', 'Unknown'),
                        customer_phone=order_dict.get('customer_phone', ''),
                        total_price=order_dict.get('total_price', 0),
                        amount_paid=order_dict.get('amount_paid', 0),
                        discount_amount=order_dict.get('discount_amount', 0),
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
            "processed_items": processed_items,
            "processed_configs": processed_configs
        })
