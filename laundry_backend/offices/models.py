import uuid
from django.db import models
from django.contrib.auth.models import AbstractUser

class User(AbstractUser):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    office = models.ForeignKey(
        'LaundryOffice', 
        on_delete=models.CASCADE, 
        related_name='users',
        null=True, 
        blank=True
    )
    is_office_admin = models.BooleanField(default=False)
    branches = models.ManyToManyField(
        'LaundryOffice',
        related_name='branch_users',
        blank=True
    )

class BaseModel(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    is_deleted = models.BooleanField(default=False)

    class Meta:
        abstract = True

class LaundryOffice(BaseModel):
    SUBSCRIPTION_TIERS = [
        ('free', 'Free'),
        ('starter', 'Starter'),
        ('pro', 'Pro'),
        ('premium', 'Premium'),
    ]
    name = models.CharField(max_length=255)
    contact_info = models.CharField(max_length=255, blank=True)
    preferences = models.JSONField(default=dict, blank=True)
    subscription_tier = models.CharField(max_length=20, choices=SUBSCRIPTION_TIERS, default='free', db_index=True)

class OfficeImage(BaseModel):
    office = models.ForeignKey(LaundryOffice, on_delete=models.CASCADE, related_name='images')
    image = models.ImageField(upload_to='office_images/')
    description = models.CharField(max_length=255, blank=True)

class PasswordResetOTP(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    email = models.EmailField(db_index=True)
    otp = models.CharField(max_length=6, db_index=True)
    created_at = models.DateTimeField(auto_now_add=True)
    expires_at = models.DateTimeField()
    is_used = models.BooleanField(default=False)

    class Meta:
        verbose_name_plural = "Password Reset OTPs"
        indexes = [
            models.Index(fields=['email', 'is_used', 'expires_at']),
        ]

    def __str__(self):
        return f"{self.email} - {self.otp}"

class SubscriptionLog(BaseModel):
    EVENT_TYPES = [
        ('new', 'New Subscription'),
        ('renewal', 'Renewal'),
        ('failed', 'Payment Failed'),
        ('cancelled', 'Cancelled / Disabled'),
        ('manual', 'Manual Admin Change'),
    ]

    office = models.ForeignKey(LaundryOffice, on_delete=models.SET_NULL, null=True, blank=True, related_name='subscription_logs')
    customer_email = models.EmailField(blank=True)
    event_type = models.CharField(max_length=30, choices=EVENT_TYPES, db_index=True)
    paystack_event = models.CharField(max_length=100, blank=True)
    reference = models.CharField(max_length=100, blank=True, db_index=True)
    amount = models.DecimalField(max_digits=12, decimal_places=2, default=0.00)
    tier = models.CharField(max_length=20, blank=True)
    status = models.CharField(max_length=50, default='success')
    payload = models.JSONField(default=dict, blank=True)

    class Meta:
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['office', '-created_at']),
            models.Index(fields=['event_type', '-created_at']),
            models.Index(fields=['reference']),
        ]

    def __str__(self):
        target = self.office.name if self.office else (self.customer_email or "Unknown Office")
        return f"{target} - {self.get_event_type_display()} ({self.status})"
