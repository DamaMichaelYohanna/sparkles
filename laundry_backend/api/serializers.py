from django.contrib.auth import get_user_model
from rest_framework import serializers
from offices.models import LaundryOffice
from operations.models import ServiceType, Category, ItemPricing, OrderStatus, Order, OrderItem

User = get_user_model()

class LaundryOfficeSerializer(serializers.ModelSerializer):
    class Meta:
        model = LaundryOffice
        fields = '__all__'

class ServiceTypeSerializer(serializers.ModelSerializer):
    class Meta:
        model = ServiceType
        fields = '__all__'
        read_only_fields = ['office']

class CategorySerializer(serializers.ModelSerializer):
    class Meta:
        model = Category
        fields = '__all__'
        read_only_fields = ['office']

class ItemPricingSerializer(serializers.ModelSerializer):
    class Meta:
        model = ItemPricing
        fields = '__all__'
        read_only_fields = ['office']

class OrderStatusSerializer(serializers.ModelSerializer):
    class Meta:
        model = OrderStatus
        fields = '__all__'
        read_only_fields = ['office']

class OrderItemSerializer(serializers.ModelSerializer):
    class Meta:
        model = OrderItem
        fields = '__all__'

class OrderSerializer(serializers.ModelSerializer):
    items = OrderItemSerializer(many=True, read_only=True)
    class Meta:
        model = Order
        fields = '__all__'
        read_only_fields = ['office']


class SubUserSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True)

    class Meta:
        model = User
        fields = ['id', 'username', 'email', 'first_name', 'last_name', 'password', 'is_office_admin']
        read_only_fields = ['id', 'is_office_admin']

    def create(self, validated_data):
        password = validated_data.pop('password')
        validated_data['is_office_admin'] = False
        user = User(**validated_data)
        user.set_password(password)
        user.save()
        return user
