from django.db import models
from offices.models import BaseModel

class ServiceType(BaseModel):
    office = models.ForeignKey('offices.LaundryOffice', on_delete=models.CASCADE, related_name='service_types')
    name = models.CharField(max_length=100) 
    description = models.TextField(blank=True)

class Category(BaseModel):
    office = models.ForeignKey('offices.LaundryOffice', on_delete=models.CASCADE, related_name='categories')
    name = models.CharField(max_length=100) 

class ItemPricing(BaseModel):
    office = models.ForeignKey('offices.LaundryOffice', on_delete=models.CASCADE, related_name='item_prices')
    category = models.ForeignKey(Category, on_delete=models.SET_NULL, null=True, blank=True)
    service_type = models.ForeignKey(ServiceType, on_delete=models.CASCADE)
    name = models.CharField(max_length=100) 
    price = models.DecimalField(max_digits=10, decimal_places=2)

class OrderStatus(BaseModel):
    office = models.ForeignKey('offices.LaundryOffice', on_delete=models.CASCADE, related_name='statuses')
    name = models.CharField(max_length=50) 
    sequence_order = models.PositiveIntegerField(default=0)
    is_completed_state = models.BooleanField(default=False)

class Customer(BaseModel):
    office = models.ForeignKey('offices.LaundryOffice', on_delete=models.CASCADE, related_name='customers')
    name = models.CharField(max_length=255)
    phone = models.CharField(max_length=50, db_index=True, null=True, blank=True)
    is_whatsapp = models.BooleanField(default=False)

    class Meta:
        unique_together = ('office', 'phone')

    def __str__(self):
        return f"{self.name} ({self.phone})"

class Order(BaseModel):
    office = models.ForeignKey('offices.LaundryOffice', on_delete=models.CASCADE, related_name='orders')
    customer = models.ForeignKey(Customer, on_delete=models.SET_NULL, null=True, blank=True, related_name='orders')
    customer_name = models.CharField(max_length=255)
    customer_phone = models.CharField(max_length=50)
    customer_is_whatsapp = models.BooleanField(default=False)
    current_status = models.ForeignKey(OrderStatus, on_delete=models.RESTRICT)
    total_price = models.DecimalField(max_digits=10, decimal_places=2, default=0.00)
    amount_paid = models.DecimalField(max_digits=10, decimal_places=2, default=0.00)
    discount_amount = models.DecimalField(max_digits=10, decimal_places=2, default=0.00)
    due_date = models.DateTimeField(null=True, blank=True)
    custom_notes = models.TextField(blank=True)
    tracking_code = models.CharField(max_length=50, unique=True, null=True, blank=True, db_index=True)

    class Meta:
        indexes = [
            models.Index(fields=['office', 'created_at']),
            models.Index(fields=['office', 'due_date']),
            models.Index(fields=['office', 'current_status']),
        ]

    def save(self, *args, **kwargs):
        if not self.tracking_code:
            import random
            import string
            for _ in range(10):
                code = ''.join(random.choices(string.ascii_uppercase + string.digits, k=8))
                if not Order.objects.filter(tracking_code=code).exists():
                    self.tracking_code = code
                    break

        # Auto-create or link Customer profile if customer FK is missing but phone/name exists
        if not self.customer_id and self.office_id:
            phone = (self.customer_phone or '').strip()
            name = (self.customer_name or '').strip()
            if phone:
                customer, _ = Customer.objects.get_or_create(
                    office=self.office,
                    phone=phone,
                    defaults={
                        'name': name or 'Customer',
                        'is_whatsapp': self.customer_is_whatsapp
                    }
                )
                self.customer = customer
            elif name:
                customer, _ = Customer.objects.get_or_create(
                    office=self.office,
                    name=name,
                    phone='',
                    defaults={
                        'is_whatsapp': self.customer_is_whatsapp
                    }
                )
                self.customer = customer

        super().save(*args, **kwargs)


class OrderItem(BaseModel):
    order = models.ForeignKey(Order, on_delete=models.CASCADE, related_name='items')
    item_pricing = models.ForeignKey(ItemPricing, on_delete=models.RESTRICT)
    quantity = models.PositiveIntegerField(default=1)
    unit_price = models.DecimalField(max_digits=10, decimal_places=2)
    discount_amount = models.DecimalField(max_digits=10, decimal_places=2, default=0.00)
    subtotal = models.DecimalField(max_digits=10, decimal_places=2)

class ActionLog(BaseModel):
    office = models.ForeignKey('offices.LaundryOffice', on_delete=models.CASCADE, related_name='action_logs')
    user = models.ForeignKey('offices.User', on_delete=models.SET_NULL, null=True, blank=True)
    action = models.CharField(max_length=50) # e.g., "ORDER_CREATED", "ORDER_PAID"
    details = models.TextField(blank=True)

class WebPushSubscription(BaseModel):
    customer = models.ForeignKey(Customer, on_delete=models.CASCADE, null=True, blank=True, related_name='subscriptions')
    customer_phone = models.CharField(max_length=50, db_index=True)
    endpoint = models.TextField(unique=True)
    p256dh = models.CharField(max_length=255)
    auth = models.CharField(max_length=255)
