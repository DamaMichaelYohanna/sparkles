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
    subscription_tier = models.CharField(max_length=20, choices=SUBSCRIPTION_TIERS, default='free')

class OfficeImage(BaseModel):
    office = models.ForeignKey(LaundryOffice, on_delete=models.CASCADE, related_name='images')
    image = models.ImageField(upload_to='office_images/')
    description = models.CharField(max_length=255, blank=True)
