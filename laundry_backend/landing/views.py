from django.shortcuts import render
from django.contrib.auth.decorators import user_passes_test
from django.db.models import Sum, Count
from offices.models import LaundryOffice, User
from operations.models import Order

def landing_page(request):
    return render(request, 'landing/index.html')

@user_passes_test(lambda u: u.is_superuser or u.is_staff)
def dashboard(request):
    total_offices = LaundryOffice.objects.count()
    total_users = User.objects.count()
    total_orders = Order.objects.count()
    total_revenue = Order.objects.aggregate(Sum('total_price'))['total_price__sum'] or 0.00
    
    recent_orders = Order.objects.select_related('office').order_by('-created_at')[:8]
    
    orders_by_office = LaundryOffice.objects.annotate(order_count=Count('orders')).values('name', 'order_count')
    chart_labels = [o['name'] for o in orders_by_office]
    chart_data = [o['order_count'] for o in orders_by_office]

    context = {
        'total_offices': total_offices,
        'total_users': total_users,
        'total_orders': total_orders,
        'total_revenue': total_revenue,
        'recent_orders': recent_orders,
        'chart_labels': chart_labels,
        'chart_data': chart_data,
    }
    return render(request, 'landing/dashboard.html', context)
