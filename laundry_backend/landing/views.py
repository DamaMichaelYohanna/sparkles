from django.shortcuts import render, get_object_or_404, redirect
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

@user_passes_test(lambda u: u.is_superuser or u.is_staff)
def offices_list(request):
    offices = LaundryOffice.objects.all().order_by('-created_at')
    context = {'offices': offices}
    return render(request, 'landing/offices.html', context)

@user_passes_test(lambda u: u.is_superuser or u.is_staff)
def users_list(request):
    users = User.objects.select_related('office').all().order_by('-date_joined')
    context = {'users': users}
    return render(request, 'landing/users.html', context)

@user_passes_test(lambda u: u.is_superuser or u.is_staff)
def settings_view(request):
    # Placeholder for actual settings logic
    context = {}
    return render(request, 'landing/settings.html', context)

from rest_framework.views import APIView
from rest_framework.response import Response
from .models import WaitlistEntry
import re

class JoinWaitlistView(APIView):
    permission_classes = [] # Public access

    def post(self, request):
        email = request.data.get('email', '').strip()
        if not email:
            return Response({"error": "Email is required."}, status=400)
            
        if not re.match(r'^[\w\.-]+@[\w\.-]+\.\w+$', email):
            return Response({"error": "Please enter a valid email address."}, status=400)
            
        if WaitlistEntry.objects.filter(email=email).exists():
            return Response({"error": "This email is already on the waitlist."}, status=400)
            
        try:
            entry = WaitlistEntry.objects.create(email=email)
            return Response({
                "status": "success",
                "message": "Thank you! You have successfully joined the waitlist.",
                "email": entry.email
            }, status=201)
        except Exception as e:
            return Response({"error": f"Failed to join waitlist: {str(e)}"}, status=500)

@user_passes_test(lambda u: u.is_superuser or u.is_staff)
def waitlist_dashboard(request):
    waitlist = WaitlistEntry.objects.all().order_by('-created_at')
    context = {'waitlist': waitlist}
    return render(request, 'landing/waitlist.html', context)

@user_passes_test(lambda u: u.is_superuser or u.is_staff)
def toggle_waitlist_notified(request, pk):
    if request.method == 'POST':
        entry = get_object_or_404(WaitlistEntry, pk=pk)
        entry.is_notified = not entry.is_notified
        entry.save()
    return redirect('waitlist_dashboard')

@user_passes_test(lambda u: u.is_superuser or u.is_staff)
def delete_waitlist_entry(request, pk):
    if request.method == 'POST':
        entry = get_object_or_404(WaitlistEntry, pk=pk)
        entry.delete()
    return redirect('waitlist_dashboard')
