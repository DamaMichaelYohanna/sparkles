import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

from offices.models import LaundryOffice, User
from operations.models import ItemPricing, Category, ServiceType

# Create Office
office, _ = LaundryOffice.objects.get_or_create(
    name="Sparkles Main Office", 
    defaults={'subscription_tier': 'premium'}
)

# Create Admin User
username = 'admin'
password = 'password123'
user, created = User.objects.get_or_create(
    username=username, 
    defaults={'email': 'admin@sparkles.com', 'office': office, 'is_office_admin': True}
)

user.set_password(password)
user.save()
print(f"User '{username}' with password '{password}' created/updated successfully.")

# Add some mock items if none exist so the app has data to sync
if not ItemPricing.objects.filter(office=office).exists():
    cat, _ = Category.objects.get_or_create(office=office, name="Clothing")
    serv, _ = ServiceType.objects.get_or_create(office=office, name="Wash & Iron")
    
    ItemPricing.objects.create(office=office, category=cat, service_type=serv, name="Shirt", price=1500)
    ItemPricing.objects.create(office=office, category=cat, service_type=serv, name="Trousers", price=1200)
    ItemPricing.objects.create(office=office, category=cat, service_type=serv, name="Bedsheet", price=2500)
    print("Created mock pricing data for testing.")
