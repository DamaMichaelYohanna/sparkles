import logging
from django.db import IntegrityError
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from dateutil.parser import parse
from django.utils import timezone
from offices.models import LaundryOffice
from operations.models import ServiceType, Category, ItemPricing, OrderStatus, Order, OrderItem, Customer
from .serializers import (
    ServiceTypeSerializer, CategorySerializer, ItemPricingSerializer,
    OrderStatusSerializer, OrderSerializer, OrderItemSerializer, CustomerSerializer
)

from .permissions import TierLimitPermission

logger = logging.getLogger(__name__)

def make_aware(dt):
    if dt is None:
        return None
    return timezone.make_aware(dt) if timezone.is_naive(dt) else dt

class SyncAPIView(APIView):
    permission_classes = [IsAuthenticated, TierLimitPermission]

    def get(self, request):
        office = request.user.office
        if not office:
            logger.warning("Sync GET warning: User '%s' is not associated with any office.", request.user.email)
            return Response({"error": "User is not associated with an office."}, status=400)

        last_sync = request.query_params.get('last_sync_timestamp')
        
        # Base querysets filtered by office
        service_types_qs = ServiceType.objects.filter(office=office)
        categories_qs = Category.objects.filter(office=office)
        item_pricing_qs = ItemPricing.objects.filter(office=office)
        order_statuses_qs = OrderStatus.objects.filter(office=office)
        orders_qs = Order.objects.filter(office=office)
        customers_qs = Customer.objects.filter(office=office)
        
        # Order items are tied to orders, which are tied to offices
        order_items_qs = OrderItem.objects.filter(order__office=office)

        if last_sync:
            try:
                last_sync_date = make_aware(parse(last_sync))
                service_types_qs = service_types_qs.filter(updated_at__gte=last_sync_date)
                categories_qs = categories_qs.filter(updated_at__gte=last_sync_date)
                item_pricing_qs = item_pricing_qs.filter(updated_at__gte=last_sync_date)
                order_statuses_qs = order_statuses_qs.filter(updated_at__gte=last_sync_date)
                orders_qs = orders_qs.filter(updated_at__gte=last_sync_date)
                order_items_qs = order_items_qs.filter(updated_at__gte=last_sync_date)
                customers_qs = customers_qs.filter(updated_at__gte=last_sync_date)
            except ValueError:
                return Response({"error": "Invalid last_sync_timestamp format."}, status=400)

        payload = {
            "service_types": ServiceTypeSerializer(service_types_qs, many=True).data,
            "categories": CategorySerializer(categories_qs, many=True).data,
            "item_pricing": ItemPricingSerializer(item_pricing_qs, many=True).data,
            "order_statuses": OrderStatusSerializer(order_statuses_qs, many=True).data,
            "orders": OrderSerializer(orders_qs, many=True).data,
            "order_items": OrderItemSerializer(order_items_qs, many=True).data,
            "customers": CustomerSerializer(customers_qs, many=True).data,
        }

        return Response(payload)

    def post(self, request):
        office = request.user.office
        if not office:
            logger.warning("Sync POST warning: User '%s' is not associated with any office.", request.user.email)
            return Response({"error": "User is not associated with an office."}, status=400)

        data = request.data
        orders_data = data.get('orders', [])
        order_items_data = data.get('order_items', [])
        categories_data = data.get('categories', [])
        service_types_data = data.get('service_types', [])
        item_pricing_data = data.get('item_pricing', [])
        customers_data = data.get('customers', [])

        logger.info(
            "Sync POST started for user '%s', office '%s'. Payload: %d orders, %d items, %d categories, %d service types, %d item pricings, %d customers", 
            request.user.email, 
            office.name, 
            len(orders_data), 
            len(order_items_data), 
            len(categories_data), 
            len(service_types_data), 
            len(item_pricing_data),
            len(customers_data)
        )

        processed_orders = 0
        processed_items = 0
        processed_configs = 0

        # Process Customers
        for cust_dict in customers_data:
            cust_id = cust_dict.get('id')
            if not cust_id: continue
            
            phone = cust_dict.get('phone')
            if phone == '':
                phone = None

            try:
                existing_cust = Customer.objects.filter(id=cust_id).first()
                if existing_cust:
                    if existing_cust.office != office:
                        continue
                    incoming_updated_at = make_aware(parse(cust_dict.get('updated_at', '')))
                    if cust_dict.get('is_deleted', False):
                        existing_cust.is_deleted = True
                    else:
                        existing_cust.name = cust_dict.get('name', existing_cust.name)
                        existing_cust.phone = phone
                        existing_cust.is_whatsapp = cust_dict.get('is_whatsapp', existing_cust.is_whatsapp)
                    existing_cust.updated_at = incoming_updated_at
                    existing_cust.save()
                else:
                    if not cust_dict.get('is_deleted', False):
                        Customer.objects.create(
                            id=cust_id,
                            office=office,
                            name=cust_dict.get('name', ''),
                            phone=phone,
                            is_whatsapp=cust_dict.get('is_whatsapp', False),
                            created_at=make_aware(parse(cust_dict.get('created_at'))) if cust_dict.get('created_at') else None,
                            updated_at=make_aware(parse(cust_dict.get('updated_at'))) if cust_dict.get('updated_at') else None
                        )
            except IntegrityError as e:
                logger.warning("Customer sync conflict: ID='%s', office='%s', phone='%s'. Error: %s", cust_id, office.id, phone, str(e))
                continue

        # Process Categories
        for cat_dict in categories_data:
            cat_id = cat_dict.get('id')
            if not cat_id: continue
            
            existing_cat = Category.objects.filter(id=cat_id).first()
            if existing_cat:
                if existing_cat.office != office:
                    # Belongs to another branch, skip
                    continue
                # Update
                incoming_updated_at = make_aware(parse(cat_dict.get('updated_at', '')))
                if incoming_updated_at > existing_cat.updated_at or cat_dict.get('is_deleted', False):
                    if cat_dict.get('is_deleted', False):
                        existing_cat.is_deleted = True
                    else:
                        existing_cat.name = cat_dict.get('name', existing_cat.name)
                    existing_cat.updated_at = incoming_updated_at
                    existing_cat.save()
                    processed_configs += 1
            else:
                if not cat_dict.get('is_deleted', False):
                    Category.objects.create(
                        id=cat_id,
                        office=office,
                        name=cat_dict.get('name', ''),
                        created_at=make_aware(parse(cat_dict.get('created_at'))) if cat_dict.get('created_at') else None,
                        updated_at=make_aware(parse(cat_dict.get('updated_at'))) if cat_dict.get('updated_at') else None
                    )
                    processed_configs += 1

        # Process Service Types
        for srv_dict in service_types_data:
            srv_id = srv_dict.get('id')
            if not srv_id: continue
            
            existing_srv = ServiceType.objects.filter(id=srv_id).first()
            if existing_srv:
                if existing_srv.office != office:
                    # Belongs to another branch, skip
                    continue
                # Update
                incoming_updated_at = make_aware(parse(srv_dict.get('updated_at', '')))
                if incoming_updated_at > existing_srv.updated_at or srv_dict.get('is_deleted', False):
                    if srv_dict.get('is_deleted', False):
                        existing_srv.is_deleted = True
                    else:
                        existing_srv.name = srv_dict.get('name', existing_srv.name)
                        existing_srv.description = srv_dict.get('description', existing_srv.description)
                    existing_srv.updated_at = incoming_updated_at
                    existing_srv.save()
                    processed_configs += 1
            else:
                if not srv_dict.get('is_deleted', False):
                    ServiceType.objects.create(
                        id=srv_id,
                        office=office,
                        name=srv_dict.get('name', ''),
                        description=srv_dict.get('description', ''),
                        created_at=make_aware(parse(srv_dict.get('created_at'))) if srv_dict.get('created_at') else None,
                        updated_at=make_aware(parse(srv_dict.get('updated_at'))) if srv_dict.get('updated_at') else None
                    )
                    processed_configs += 1

        # Process Item Pricing
        for ip_dict in item_pricing_data:
            ip_id = ip_dict.get('id')
            if not ip_id: continue
            
            existing_ip = ItemPricing.objects.filter(id=ip_id).first()
            if existing_ip:
                if existing_ip.office != office:
                    # Belongs to another branch, skip
                    continue
                # Update
                incoming_updated_at = make_aware(parse(ip_dict.get('updated_at', '')))
                if incoming_updated_at > existing_ip.updated_at or ip_dict.get('is_deleted', False):
                    if ip_dict.get('is_deleted', False):
                        existing_ip.is_deleted = True
                    else:
                        existing_ip.name = ip_dict.get('name', existing_ip.name)
                        existing_ip.price = ip_dict.get('price', existing_ip.price)
                    existing_ip.updated_at = incoming_updated_at
                    existing_ip.save()
                    processed_configs += 1
            else:
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
                            price=ip_dict.get('price', 0),
                            created_at=make_aware(parse(ip_dict.get('created_at'))) if ip_dict.get('created_at') else None,
                            updated_at=make_aware(parse(ip_dict.get('updated_at'))) if ip_dict.get('updated_at') else None
                        )
                        processed_configs += 1

        # Process Orders
        for order_dict in orders_data:
            order_id = order_dict.get('id')
            if not order_id: continue
            
            existing_order = Order.objects.filter(id=order_id).first()
            if existing_order:
                if existing_order.office != office:
                    # Belongs to another branch, skip
                    continue
                # Update
                was_completed = existing_order.current_status.is_completed_state
                old_status_name = existing_order.current_status.name
                incoming_updated_at = make_aware(parse(order_dict.get('updated_at', '')))
                # Always apply updates from the client since the client is the source of truth for POS orders
                if order_dict.get('is_deleted', False):
                    existing_order.is_deleted = True
                else:
                    existing_order.customer_name = order_dict.get('customer_name', existing_order.customer_name)
                    existing_order.customer_phone = order_dict.get('customer_phone', existing_order.customer_phone)
                    existing_order.customer_is_whatsapp = order_dict.get('customer_is_whatsapp', existing_order.customer_is_whatsapp)
                    existing_order.total_price = order_dict.get('total_price', existing_order.total_price)
                    existing_order.amount_paid = order_dict.get('amount_paid', existing_order.amount_paid)
                    existing_order.discount_amount = order_dict.get('discount_amount', existing_order.discount_amount)
                    existing_order.tracking_code = order_dict.get('tracking_code', existing_order.tracking_code)
                    
                    customer_id = order_dict.get('customer') or order_dict.get('customer_id')
                    if customer_id:
                        existing_order.customer = Customer.objects.filter(id=customer_id, office=office).first()
                    
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
                        existing_order.current_status = status_obj
                            
                existing_order.updated_at = incoming_updated_at
                existing_order.save()
                processed_orders += 1
                
                # Trigger Web Push notification if status changed
                if existing_order.current_status.name != old_status_name:
                    from .push_notifications import notify_order_status_change
                    notify_order_status_change(existing_order)
                
                # Trigger WhatsApp if transitioned to completed during sync
                if existing_order.current_status.is_completed_state and not was_completed:
                    from threading import Thread
                    from .whatsapp import send_whatsapp_order_completed
                    Thread(target=send_whatsapp_order_completed, args=(existing_order,), daemon=True).start()
            else:
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
                    try:
                        customer_obj = None
                        customer_id = order_dict.get('customer') or order_dict.get('customer_id')
                        if customer_id:
                            customer_obj = Customer.objects.filter(id=customer_id, office=office).first()
                        
                        new_order = Order.objects.create(
                            id=order_id,
                            office=office,
                            customer=customer_obj,
                            customer_name=order_dict.get('customer_name', 'Unknown'),
                            customer_phone=order_dict.get('customer_phone', ''),
                            customer_is_whatsapp=order_dict.get('customer_is_whatsapp', False),
                            total_price=order_dict.get('total_price', 0),
                            amount_paid=order_dict.get('amount_paid', 0),
                            discount_amount=order_dict.get('discount_amount', 0),
                            current_status=status_obj,
                            tracking_code=order_dict.get('tracking_code'),
                            created_at=make_aware(parse(order_dict.get('created_at'))) if order_dict.get('created_at') else None,
                            updated_at=make_aware(parse(order_dict.get('updated_at'))) if order_dict.get('updated_at') else None
                        )
                        processed_orders += 1
                        
                        # Trigger WhatsApp notifications in the background
                        from threading import Thread
                        if new_order.current_status.is_completed_state:
                            from .whatsapp import send_whatsapp_order_completed
                            Thread(target=send_whatsapp_order_completed, args=(new_order,), daemon=True).start()
                        else:
                            from .whatsapp import send_whatsapp_order_received
                            Thread(target=send_whatsapp_order_received, args=(new_order,), daemon=True).start()
                    except IntegrityError:
                        # Fallback for concurrent sync requests: update the record instead
                        existing_order = Order.objects.filter(id=order_id).first()
                        if existing_order and existing_order.office == office:
                            existing_order.customer_name = order_dict.get('customer_name', existing_order.customer_name)
                            existing_order.customer_phone = order_dict.get('customer_phone', existing_order.customer_phone)
                            existing_order.customer_is_whatsapp = order_dict.get('customer_is_whatsapp', existing_order.customer_is_whatsapp)
                            existing_order.total_price = order_dict.get('total_price', existing_order.total_price)
                            existing_order.amount_paid = order_dict.get('amount_paid', existing_order.amount_paid)
                            existing_order.discount_amount = order_dict.get('discount_amount', existing_order.discount_amount)
                            existing_order.tracking_code = order_dict.get('tracking_code', existing_order.tracking_code)
                            existing_order.current_status = status_obj
                            
                            customer_id = order_dict.get('customer') or order_dict.get('customer_id')
                            if customer_id:
                                existing_order.customer = Customer.objects.filter(id=customer_id, office=office).first()
                            
                            existing_order.save()
                            processed_orders += 1

        # Process Order Items
        for item_dict in order_items_data:
            item_id = item_dict.get('id')
            order_id = item_dict.get('order_id') # Make sure flutter sends order_id
            pricing_id = item_dict.get('item_pricing_id')
            if not item_id or not order_id or not pricing_id: continue

            existing_item = OrderItem.objects.filter(id=item_id).first()
            if existing_item:
                if existing_item.order.office != office:
                    # Belongs to another branch, skip
                    continue
                # Update
                incoming_updated_at = make_aware(parse(item_dict.get('updated_at', '')))
                # Always apply updates from the client since the client is the source of truth for POS order items
                if item_dict.get('is_deleted', False):
                    existing_item.is_deleted = True
                else:
                    existing_item.quantity = item_dict.get('quantity', existing_item.quantity)
                    existing_item.unit_price = item_dict.get('unit_price', existing_item.unit_price)
                    existing_item.discount_amount = item_dict.get('discount_amount', existing_item.discount_amount)
                    existing_item.subtotal = item_dict.get('subtotal', existing_item.subtotal)
                existing_item.updated_at = incoming_updated_at
                existing_item.save()
                processed_items += 1
            else:
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
                            subtotal=item_dict.get('subtotal', 0),
                            created_at=make_aware(parse(item_dict.get('created_at'))) if item_dict.get('created_at') else None,
                            updated_at=make_aware(parse(item_dict.get('updated_at'))) if item_dict.get('updated_at') else None
                        )
                        processed_items += 1
                    except (Order.DoesNotExist, ItemPricing.DoesNotExist):
                        pass

        logger.info(
            "Sync POST completed for user '%s', office '%s'. Processed: %d orders, %d items, %d configs", 
            request.user.email, 
            office.name, 
            processed_orders, 
            processed_items, 
            processed_configs
        )
        return Response({
            "status": "success",
            "processed_orders": processed_orders,
            "processed_items": processed_items,
            "processed_configs": processed_configs
        })
