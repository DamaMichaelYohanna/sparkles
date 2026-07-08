from django.urls import path
from rest_framework_simplejwt.views import TokenObtainPairView, TokenRefreshView
from . import views
from .sync_views import SyncAPIView

urlpatterns = [
    # Auth
    path('token/', TokenObtainPairView.as_view(), name='token_obtain_pair'),
    path('token/refresh/', TokenRefreshView.as_view(), name='token_refresh'),

    # LaundryOffice
    path('offices/', views.LaundryOfficeListCreateView.as_view(), name='office-list'),
    path('offices/<uuid:pk>/', views.LaundryOfficeRetrieveUpdateDestroyView.as_view(), name='office-detail'),

    # ServiceType
    path('service-types/', views.ServiceTypeListCreateView.as_view(), name='service-type-list'),
    path('service-types/<uuid:pk>/', views.ServiceTypeRetrieveUpdateDestroyView.as_view(), name='service-type-detail'),

    # Category
    path('categories/', views.CategoryListCreateView.as_view(), name='category-list'),
    path('categories/<uuid:pk>/', views.CategoryRetrieveUpdateDestroyView.as_view(), name='category-detail'),

    # ItemPricing
    path('item-pricing/', views.ItemPricingListCreateView.as_view(), name='item-pricing-list'),
    path('item-pricing/<uuid:pk>/', views.ItemPricingRetrieveUpdateDestroyView.as_view(), name='item-pricing-detail'),

    # OrderStatus
    path('order-statuses/', views.OrderStatusListCreateView.as_view(), name='order-status-list'),
    path('order-statuses/<uuid:pk>/', views.OrderStatusRetrieveUpdateDestroyView.as_view(), name='order-status-detail'),

    # Order
    path('orders/', views.OrderListCreateView.as_view(), name='order-list'),
    path('orders/<uuid:pk>/', views.OrderRetrieveUpdateDestroyView.as_view(), name='order-detail'),

    # OrderItem
    path('order-items/', views.OrderItemListCreateView.as_view(), name='order-item-list'),
    path('order-items/<uuid:pk>/', views.OrderItemRetrieveUpdateDestroyView.as_view(), name='order-item-detail'),
    # Sub-users
    path('users/', views.SubUserListCreateView.as_view(), name='subuser-list'),
    path('users/<uuid:pk>/', views.SubUserRetrieveUpdateDestroyView.as_view(), name='subuser-detail'),

    # Dashboards
    path('dashboard/operations/', views.OfficeOperationsDashboardAPIView.as_view(), name='dashboard-operations'),
    path('dashboard/finance/', views.OfficeFinancialDashboardAPIView.as_view(), name='dashboard-finance'),

    # Sync
    path('sync/', SyncAPIView.as_view(), name='api-sync'),
    
    # Webhooks
    path('webhooks/paystack/', views.PaystackWebhookView.as_view(), name='webhook-paystack'),
]
