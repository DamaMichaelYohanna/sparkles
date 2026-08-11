import logging
from django.shortcuts import render, get_object_or_404, redirect
from django.contrib.auth.decorators import user_passes_test
from django.contrib.auth import login as auth_login, logout as auth_logout, authenticate
from django.contrib import messages
from django.db.models import Sum, Count, Q
from django.conf import settings
from offices.models import LaundryOffice, User, SubscriptionLog
from operations.models import Order

logger = logging.getLogger(__name__)

def landing_page(request):
    return render(request, 'landing/index.html')

def terms_of_service(request):
    return render(request, 'landing/terms.html')

def privacy_policy(request):
    return render(request, 'landing/privacy.html')


def custom_login(request):
    if request.user.is_authenticated:
        if request.user.is_superuser or request.user.is_staff:
            next_url = request.GET.get('next') or request.POST.get('next') or 'dashboard'
            return redirect(next_url)

    if request.method == 'POST':
        username = request.POST.get('username', '').strip()
        password = request.POST.get('password', '').strip()
        next_url = request.POST.get('next', '').strip() or request.GET.get('next', '').strip() or 'dashboard'

        if not username or not password:
            messages.error(request, "Please enter both username/email and password.")
            return render(request, 'landing/login.html', {'next': next_url, 'username': username})

        user = authenticate(request, username=username, password=password)

        if user is None and '@' in username:
            try:
                user_obj = User.objects.filter(email__iexact=username).first()
                if user_obj:
                    user = authenticate(request, username=user_obj.username, password=password)
            except Exception:
                pass

        if user is not None:
            if not user.is_active:
                messages.error(request, "This account is inactive. Please contact support.")
            elif not (user.is_staff or user.is_superuser):
                messages.error(request, "Access restricted to administrative staff.")
            else:
                auth_login(request, user)
                messages.success(request, f"Welcome back, {user.get_full_name() or user.username}!")
                return redirect(next_url)
        else:
            messages.error(request, "Invalid username or password.")

        return render(request, 'landing/login.html', {'next': next_url, 'username': username})

    next_url = request.GET.get('next', '')
    return render(request, 'landing/login.html', {'next': next_url})


def custom_logout(request):
    auth_logout(request)
    messages.info(request, "You have been logged out successfully.")
    return redirect('login')


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
    context = {
        'offices': offices,
    }
    return render(request, 'landing/offices.html', context)


@user_passes_test(lambda u: u.is_superuser)
def delete_office(request, pk):
    if request.method == 'POST':
        office = get_object_or_404(LaundryOffice, pk=pk)
        office_name = office.name
        office.delete()
        messages.success(request, f"Office '{office_name}' has been successfully deleted.")
    return redirect('offices_list')


@user_passes_test(lambda u: u.is_superuser or u.is_staff)
def subscriptions_view(request):
    if request.method == 'POST':
        office_id = request.POST.get('office_id')
        subscription_tier = request.POST.get('subscription_tier')

        if office_id and subscription_tier:
            office = get_object_or_404(LaundryOffice, pk=office_id)
            valid_tiers = {choice for choice, _ in LaundryOffice.SUBSCRIPTION_TIERS}

            if subscription_tier in valid_tiers:
                old_tier = office.subscription_tier
                office.subscription_tier = subscription_tier
                office.save(update_fields=['subscription_tier', 'updated_at'])
                
                # Log manual change
                SubscriptionLog.objects.create(
                    office=office,
                    customer_email=request.user.email,
                    event_type='manual',
                    paystack_event='admin_override',
                    reference=f"manual_{office.id.hex[:8]}",
                    amount=0.00,
                    tier=subscription_tier,
                    status='success',
                    payload={'old_tier': old_tier, 'new_tier': subscription_tier, 'changed_by': request.user.email}
                )
                
                messages.success(request, f"Updated {office.name} to {office.get_subscription_tier_display()} subscription.")
            else:
                messages.error(request, 'Invalid subscription tier selected.')

    offices = LaundryOffice.objects.all().order_by('-created_at')
    tier_counts = {
        tier: offices.filter(subscription_tier=tier).count()
        for tier, _ in LaundryOffice.SUBSCRIPTION_TIERS
    }
    context = {
        'offices': offices,
        'subscription_tiers': LaundryOffice.SUBSCRIPTION_TIERS,
        'tier_counts': tier_counts,
        'total_subscriptions': offices.count(),
    }
    return render(request, 'landing/subscriptions.html', context)


@user_passes_test(lambda u: u.is_superuser or u.is_staff)
def subscription_logs_view(request):
    logs_qs = SubscriptionLog.objects.select_related('office').all().order_by('-created_at')

    # Filtering by event_type
    selected_event = request.GET.get('event_type', 'all').lower().strip()
    if selected_event in ['new', 'renewal', 'failed', 'cancelled', 'manual']:
        logs = logs_qs.filter(event_type=selected_event)
    else:
        selected_event = 'all'
        logs = logs_qs

    # Search filter
    search_query = request.GET.get('search', '').strip()
    if search_query:
        logs = logs.filter(
            Q(customer_email__icontains=search_query) |
            Q(reference__icontains=search_query) |
            Q(office__name__icontains=search_query) |
            Q(paystack_event__icontains=search_query)
        )

    # Metrics
    total_logs = logs_qs.count()
    new_count = logs_qs.filter(event_type='new').count()
    renewal_count = logs_qs.filter(event_type='renewal').count()
    failed_count = logs_qs.filter(event_type='failed').count()
    cancelled_count = logs_qs.filter(event_type='cancelled').count()

    context = {
        'logs': logs[:100],
        'selected_event': selected_event,
        'search_query': search_query,
        'total_logs': total_logs,
        'new_count': new_count,
        'renewal_count': renewal_count,
        'failed_count': failed_count,
        'cancelled_count': cancelled_count,
        'event_types': SubscriptionLog.EVENT_TYPES,
    }
    return render(request, 'landing/subscription_logs.html', context)

@user_passes_test(lambda u: u.is_superuser or u.is_staff)
def users_list(request):
    all_users_qs = User.objects.select_related('office').all().order_by('-date_joined')
    
    total_count = all_users_qs.count()
    staff_count = all_users_qs.filter(Q(is_staff=True) | Q(is_superuser=True)).count()
    customer_count = all_users_qs.filter(is_staff=False, is_superuser=False).count()
    
    selected_role = request.GET.get('role', 'all').lower().strip()
    
    if selected_role == 'staff':
        users = all_users_qs.filter(Q(is_staff=True) | Q(is_superuser=True))
    elif selected_role == 'customer':
        users = all_users_qs.filter(is_staff=False, is_superuser=False)
    else:
        selected_role = 'all'
        users = all_users_qs

    context = {
        'users': users,
        'selected_role': selected_role,
        'total_count': total_count,
        'staff_count': staff_count,
        'customer_count': customer_count,
    }
    return render(request, 'landing/users.html', context)

@user_passes_test(lambda u: u.is_superuser or u.is_staff)
def send_user_email(request):
    if request.method == 'POST':
        import logging
        from threading import Thread
        logger = logging.getLogger(__name__)

        target_type = request.POST.get('target_type')
        subject = request.POST.get('subject', '').strip()
        message_body = request.POST.get('message_body', '').strip()
        cta_text = request.POST.get('cta_text', '').strip() or None
        cta_link = request.POST.get('cta_link', '').strip() or None
        single_email = request.POST.get('single_email', '').strip()
        
        if not subject or not message_body:
            messages.error(request, "Subject and Message Body are required.")
            return redirect('users_list')
            
        all_active_users = User.objects.filter(is_active=True).exclude(email__isnull=True).exclude(email='')

        # Determine recipients
        if target_type == 'all':
            recipients = all_active_users
        elif target_type == 'staff':
            recipients = all_active_users.filter(Q(is_staff=True) | Q(is_superuser=True))
        elif target_type == 'customer':
            recipients = all_active_users.filter(is_staff=False, is_superuser=False)
        elif target_type == 'single':
            if not single_email:
                messages.error(request, "Specific email address is required.")
                return redirect('users_list')
            
            class TempEntry:
                def __init__(self, email):
                    self.email = email
            recipients = [TempEntry(single_email)]
        else:
            messages.error(request, "Invalid target type.")
            return redirect('users_list')
            
        recipients_list = list(recipients)
        if not recipients_list:
            messages.warning(request, "No user accounts matched your selection or have valid email addresses.")
            return redirect('users_list')
            
        # Send emails in a background thread to prevent blocking
        def send_user_emails_background(recipients, email_subject, email_body, c_text, c_link):
            from api.emails import send_custom_user_email
            for user_entry in recipients:
                try:
                    send_custom_user_email(
                        email=user_entry.email,
                        subject=email_subject,
                        message_body=email_body,
                        cta_text=c_text,
                        cta_link=c_link
                    )
                except Exception as e:
                    logger.error(f"Error sending custom user email to {user_entry.email}: {e}")
                    
        thread = Thread(target=send_user_emails_background, args=(recipients_list, subject, message_body, cta_text, cta_link))
        thread.daemon = True
        thread.start()
        
        messages.success(request, f"Custom email broadcast started for {len(recipients_list)} user(s) in the background.")
        
    return redirect('users_list')

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
            
            # Send waitlist welcome email
            from api.emails import send_waitlist_welcome
            send_waitlist_welcome(email=entry.email)
            
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
        
        # Send invitation email if marked as notified
        if entry.is_notified:
            from api.emails import send_waitlist_notified
            send_waitlist_notified(email=entry.email)
            
    return redirect('waitlist_dashboard')

@user_passes_test(lambda u: u.is_superuser)
def delete_waitlist_entry(request, pk):
    if request.method == 'POST':
        entry = get_object_or_404(WaitlistEntry, pk=pk)
        entry.delete()
    return redirect('waitlist_dashboard')

@user_passes_test(lambda u: u.is_superuser or u.is_staff)
def send_waitlist_email(request):
    if request.method == 'POST':
        import logging
        from threading import Thread
        logger = logging.getLogger(__name__)

        target_type = request.POST.get('target_type')
        subject = request.POST.get('subject', '').strip()
        message_body = request.POST.get('message_body', '').strip()
        cta_text = request.POST.get('cta_text', '').strip() or None
        cta_link = request.POST.get('cta_link', '').strip() or None
        single_email = request.POST.get('single_email', '').strip()
        
        if not subject or not message_body:
            messages.error(request, "Subject and Message Body are required.")
            return redirect('waitlist_dashboard')
            
        # Determine recipients
        if target_type == 'all':
            recipients = WaitlistEntry.objects.all()
        elif target_type == 'pending':
            recipients = WaitlistEntry.objects.filter(is_notified=False)
        elif target_type == 'notified':
            recipients = WaitlistEntry.objects.filter(is_notified=True)
        elif target_type == 'single':
            if not single_email:
                messages.error(request, "Specific email address is required.")
                return redirect('waitlist_dashboard')
            
            class TempEntry:
                def __init__(self, email):
                    self.email = email
            recipients = [TempEntry(single_email)]
        else:
            messages.error(request, "Invalid target type.")
            return redirect('waitlist_dashboard')
            
        recipients_list = list(recipients)
        if not recipients_list:
            messages.warning(request, "No waitlist entries matched your selection.")
            return redirect('waitlist_dashboard')
            
        # Send emails in a background thread to prevent blocking
        def send_emails_background(recipients, email_subject, email_body, c_text, c_link):
            from api.emails import send_custom_waitlist_email
            for entry in recipients:
                try:
                    send_custom_waitlist_email(
                        email=entry.email,
                        subject=email_subject,
                        message_body=email_body,
                        cta_text=c_text,
                        cta_link=c_link
                    )
                except Exception as e:
                    logger.error(f"Error sending custom waitlist email to {entry.email}: {e}")
                    
        thread = Thread(target=send_emails_background, args=(recipients_list, subject, message_body, cta_text, cta_link))
        thread.daemon = True
        thread.start()
        
        messages.success(request, f"Custom email sending started for {len(recipients_list)} recipient(s) in the background.")
        
    return redirect('waitlist_dashboard')


from django.http import HttpResponse
from django.urls import reverse

def sitemap_xml(request):
    urls = [
        reverse('landing-page'),
        reverse('terms-of-service'),
        reverse('privacy-policy'),
    ]
    
    xml_content = '<?xml version="1.0" encoding="UTF-8"?>\n'
    xml_content += '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n'
    
    for url in urls:
        abs_url = request.build_absolute_uri(url)
        xml_content += '  <url>\n'
        xml_content += f'    <loc>{abs_url}</loc>\n'
        xml_content += '    <changefreq>weekly</changefreq>\n'
        xml_content += '    <priority>0.8</priority>\n'
        xml_content += '  </url>\n'
        
    xml_content += '</urlset>\n'
    return HttpResponse(xml_content, content_type='application/xml')

def robots_txt(request):
    sitemap_url = request.build_absolute_uri(reverse('sitemap-xml'))
    content = "User-agent: *\n"
    content += "Allow: /\n\n"
    content += f"Sitemap: {sitemap_url}\n"
    return HttpResponse(content, content_type='text/plain')


@user_passes_test(lambda u: u.is_superuser or u.is_staff)
def toggle_user_active(request, pk):
    if request.method == 'POST':
        user = get_object_or_404(User, pk=pk)
        if user == request.user:
            messages.error(request, "You cannot block your own account.")
        else:
            user.is_active = not user.is_active
            user.save()
            action = "unblocked" if user.is_active else "blocked"
            messages.success(request, f"User {user.username} has been successfully {action}.")
    return redirect('users_list')


@user_passes_test(lambda u: u.is_superuser)
def toggle_user_staff(request, pk):
    if request.method == 'POST':
        user = get_object_or_404(User, pk=pk)
        if user == request.user:
            messages.error(request, "You cannot alter your own staff role.")
        else:
            user.is_staff = not user.is_staff
            user.save(update_fields=['is_staff'])
            status_str = "promoted to Staff" if user.is_staff else "demoted from Staff to Customer"
            messages.success(request, f"User {user.username} has been successfully {status_str}.")
    return redirect('users_list')


@user_passes_test(lambda u: u.is_superuser)
def delete_user(request, pk):
    if request.method == 'POST':
        user = get_object_or_404(User, pk=pk)
        if user == request.user:
            messages.error(request, "You cannot delete your own account.")
        else:
            username = user.username
            user.delete()
            messages.success(request, f"User {username} has been successfully deleted.")
    return redirect('users_list')


def public_receipt_view(request, tracking_code):
    """
    Renders a public digital receipt page for customers using their short tracking code.
    No login required.
    """
    # Fetch the order, prefetching items and related models for efficiency
    order = get_object_or_404(
        Order.objects.select_related('office', 'current_status').prefetch_related('items__item_pricing', 'items__item_pricing__category'),
        tracking_code=tracking_code
    )
    
    # Calculate outstanding balance
    outstanding_balance = order.total_price - order.amount_paid
    if outstanding_balance < 0:
        outstanding_balance = 0
        
    # Get all status steps for this office's workflow
    from operations.models import OrderStatus
    office_statuses = list(OrderStatus.objects.filter(office=order.office).order_by('sequence_order'))
    
    if not office_statuses:
        # Create standard status list for visual rendering
        status_names = ['Pending', 'Received', 'Washing', 'Ironing', 'Ready', 'Completed']
        statuses_list = []
        is_active_found = False
        for name in status_names:
            active = (name.lower() == order.current_status.name.lower())
            if active:
                is_active_found = True
            
            # Previous ones are completed
            completed = not active and not is_active_found
            
            statuses_list.append({
                'name': name,
                'is_active': active,
                'is_completed': completed
            })
    else:
        # Build list based on database status sequence order
        statuses_list = []
        current_seq = order.current_status.sequence_order
        for status in office_statuses:
            is_active = (status.id == order.current_status.id) or (status.name.lower() == order.current_status.name.lower())
            is_completed = False
            if not is_active:
                is_completed = (status.sequence_order < current_seq)
            
            statuses_list.append({
                'name': status.name,
                'is_active': is_active,
                'is_completed': is_completed
            })
            
    # Fetch other orders for the same customer phone to display in history
    other_orders = []
    newer_active_order = None
    if order.customer_phone:
        other_orders = Order.objects.filter(
            customer_phone=order.customer_phone
        ).exclude(id=order.id).select_related('current_status').order_by('-created_at')[:5]
        
        # Check if there is a newer active (non-completed) order
        newer_active_order = Order.objects.filter(
            customer_phone=order.customer_phone,
            created_at__gt=order.created_at,
            current_status__is_completed_state=False
        ).select_related('current_status').order_by('-created_at').first()

    context = {
        'order': order,
        'outstanding_balance': outstanding_balance,
        'statuses': statuses_list,
        'other_orders': other_orders,
        'newer_active_order': newer_active_order,
        'vapid_public_key': getattr(settings, 'VAPID_PUBLIC_KEY', '') or '',
    }
    return render(request, 'landing/receipt.html', context)


def public_latest_receipt_view(request):
    return render(request, 'landing/latest_receipt.html')


def pwa_manifest_view(request):
    from django.http import JsonResponse
    protocol = "https" if request.is_secure() else "http"
    host = request.get_host()
    logo_url = f"{protocol}://{host}/static/landing/images/logo.png"
    
    manifest_data = {
        "name": "Sparkles Receipts",
        "short_name": "Receipts",
        "start_url": "/r/latest/",
        "display": "standalone",
        "background_color": "#f8fafc",
        "theme_color": "#0284c7",
        "icons": [
            {
                "src": logo_url,
                "sizes": "512x512",
                "type": "image/png"
            }
        ]
    }
    return JsonResponse(manifest_data)


from django.db import ProgrammingError, OperationalError
from operations.models import SupportTicket

@user_passes_test(lambda u: u.is_superuser or u.is_staff)
def admin_tickets_list(request):
    try:
        tickets = SupportTicket.objects.select_related('office', 'user').filter(is_deleted=False).order_by('-created_at')
        
        # Filter by type
        ticket_type = request.GET.get('ticket_type', '').strip()
        if ticket_type:
            tickets = tickets.filter(ticket_type=ticket_type)
            
        # Filter by status
        status = request.GET.get('status', '').strip()
        if status:
            tickets = tickets.filter(status=status)
            
        # Search
        search = request.GET.get('search', '').strip()
        if search:
            tickets = tickets.filter(
                Q(title__icontains=search) | 
                Q(description__icontains=search) | 
                Q(office__name__icontains=search)
            )
        
        # Force evaluation inside try block so missing table exceptions are caught
        tickets_list = list(tickets)
    except (ProgrammingError, OperationalError) as e:
        logger.warning("[SupportTicket] Database table missing or unmigrated: %s", e)
        tickets_list = []
        ticket_type = ''
        status = ''
        search = ''

    context = {
        'tickets': tickets_list,
        'ticket_types': SupportTicket.TICKET_TYPES,
        'status_choices': SupportTicket.STATUS_CHOICES,
        'selected_type': ticket_type,
        'selected_status': status,
        'search_query': search,
    }
    return render(request, 'landing/tickets_list.html', context)


@user_passes_test(lambda u: u.is_superuser or u.is_staff)
def admin_ticket_detail(request, pk):
    try:
        ticket = get_object_or_404(SupportTicket, pk=pk)
    except (ProgrammingError, OperationalError) as e:
        logger.warning("[SupportTicket] Database table missing: %s", e)
        messages.error(request, "Support Tickets table is currently unavailable. Please try again in a moment.")
        return redirect('admin_tickets_list')
    
    if request.method == 'POST':
        status = request.POST.get('status')
        admin_notes = request.POST.get('admin_notes', '').strip()
        
        valid_statuses = {choice for choice, _ in SupportTicket.STATUS_CHOICES}
        if status in valid_statuses:
            ticket.status = status
            ticket.admin_notes = admin_notes
            ticket.save()
            messages.success(request, f"Ticket status and response updated successfully.")
            return redirect('admin_ticket_detail', pk=pk)
        else:
            messages.error(request, "Invalid status selected.")
            
    context = {
        'ticket': ticket,
        'status_choices': SupportTicket.STATUS_CHOICES,
    }
    return render(request, 'landing/ticket_detail.html', context)


@user_passes_test(lambda u: u.is_superuser)
def delete_ticket(request, pk):
    if request.method == 'POST':
        try:
            ticket = get_object_or_404(SupportTicket, pk=pk)
            ticket_title = ticket.title
            ticket.is_deleted = True
            ticket.save(update_fields=['is_deleted'])
            messages.success(request, f"Support ticket '{ticket_title}' has been deleted successfully.")
        except Exception as e:
            logger.error("Error deleting ticket: %s", e)
            messages.error(request, "Unable to delete ticket at this time.")
    return redirect('admin_tickets_list')
