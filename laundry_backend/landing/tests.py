from django.test import TestCase, Client
from django.urls import reverse
from offices.models import User, LaundryOffice
from operations.models import SupportTicket
from landing.models import WaitlistEntry

class AuthDashboardTests(TestCase):
    def setUp(self):
        self.client = Client()
        
        # Create a regular user (customer)
        self.regular_user = User.objects.create_user(
            username='regularuser',
            email='regular@sparkles.com.ng',
            password='Password123!'
        )
        
        # Create a staff user (non-superuser)
        self.staff_user = User.objects.create_user(
            username='staffuser',
            email='staff@sparkles.com.ng',
            password='Password123!',
            is_staff=True
        )
        
        # Create a superuser
        self.superuser = User.objects.create_superuser(
            username='superadmin',
            email='admin@sparkles.com.ng',
            password='Password123!'
        )
        
        # Create a test waitlist entry
        self.waitlist_entry = WaitlistEntry.objects.create(
            email='waitlist_test@example.com'
        )

    def test_login_page_renders(self):
        response = self.client.get(reverse('login'))
        self.assertEqual(response.status_code, 200)
        self.assertTemplateUsed(response, 'landing/login.html')

    def test_admin_login_renders_custom_template(self):
        response = self.client.get('/admin/login/')
        self.assertEqual(response.status_code, 200)
        self.assertTemplateUsed(response, 'admin/login.html')

    def test_unauthenticated_dashboard_access_redirects(self):
        response = self.client.get(reverse('dashboard'))
        self.assertEqual(response.status_code, 302)
        self.assertIn('/login/', response.url)

    def test_invalid_login_credentials(self):
        response = self.client.post(reverse('login'), {
            'username': 'staffuser',
            'password': 'WrongPassword!'
        })
        self.assertEqual(response.status_code, 200)
        self.assertContains(response, 'Invalid username or password')

    def test_non_staff_login_restricted(self):
        response = self.client.post(reverse('login'), {
            'username': 'regularuser',
            'password': 'Password123!'
        })
        self.assertEqual(response.status_code, 200)
        self.assertContains(response, 'Access restricted to administrative staff')

    def test_staff_login_successful_and_redirects(self):
        response = self.client.post(reverse('login'), {
            'username': 'staffuser',
            'password': 'Password123!',
            'next': '/dashboard/'
        })
        self.assertRedirects(response, '/dashboard/')
        
        # Verify staff can access dashboard
        dash_response = self.client.get(reverse('dashboard'))
        self.assertEqual(dash_response.status_code, 200)
        self.assertContains(dash_response, 'Staff')

    def test_staff_cannot_delete_waitlist_entry(self):
        self.client.login(username='staffuser', password='Password123!')
        response = self.client.post(reverse('delete_waitlist', args=[self.waitlist_entry.id]))
        self.assertEqual(response.status_code, 302)
        self.assertTrue(WaitlistEntry.objects.filter(id=self.waitlist_entry.id).exists())

    def test_staff_cannot_delete_user(self):
        self.client.login(username='staffuser', password='Password123!')
        response = self.client.post(reverse('delete_user', args=[self.regular_user.id]))
        self.assertEqual(response.status_code, 302)
        self.assertTrue(User.objects.filter(id=self.regular_user.id).exists())

    def test_superuser_can_delete_waitlist_entry(self):
        self.client.login(username='superadmin', password='Password123!')
        response = self.client.post(reverse('delete_waitlist', args=[self.waitlist_entry.id]))
        self.assertEqual(response.status_code, 302)
        self.assertFalse(WaitlistEntry.objects.filter(id=self.waitlist_entry.id).exists())

    def test_superuser_can_delete_user(self):
        self.client.login(username='superadmin', password='Password123!')
        response = self.client.post(reverse('delete_user', args=[self.regular_user.id]))
        self.assertEqual(response.status_code, 302)
        self.assertFalse(User.objects.filter(id=self.regular_user.id).exists())

    def test_logout(self):
        self.client.login(username='staffuser', password='Password123!')
        response = self.client.get(reverse('logout'))
        self.assertRedirects(response, reverse('login'))
        
        dash_response = self.client.get(reverse('dashboard'))
        self.assertEqual(dash_response.status_code, 302)

    def test_user_list_role_filtering(self):
        self.client.login(username='superadmin', password='Password123!')
        
        # Test 'all' filter tab
        resp_all = self.client.get(reverse('users_list') + '?role=all')
        self.assertEqual(resp_all.status_code, 200)
        self.assertEqual(len(resp_all.context['users']), 3)

        # Test 'staff' filter tab
        resp_staff = self.client.get(reverse('users_list') + '?role=staff')
        self.assertEqual(resp_staff.status_code, 200)
        self.assertEqual(len(resp_staff.context['users']), 2) # staff_user + superuser

        # Test 'customer' filter tab
        resp_customer = self.client.get(reverse('users_list') + '?role=customer')
        self.assertEqual(resp_customer.status_code, 200)
        self.assertEqual(len(resp_customer.context['users']), 1) # regular_user

    def test_superuser_can_toggle_staff_status(self):
        self.client.login(username='superadmin', password='Password123!')
        
        # Promote customer to staff
        resp_promote = self.client.post(reverse('toggle_user_staff', args=[self.regular_user.id]))
        self.assertRedirects(resp_promote, reverse('users_list'))
        self.regular_user.refresh_from_db()
        self.assertTrue(self.regular_user.is_staff)

        # Demote staff back to customer
        resp_demote = self.client.post(reverse('toggle_user_staff', args=[self.regular_user.id]))
        self.assertRedirects(resp_demote, reverse('users_list'))
        self.regular_user.refresh_from_db()
        self.assertFalse(self.regular_user.is_staff)

    def test_staff_cannot_toggle_staff_status(self):
        self.client.login(username='staffuser', password='Password123!')
        response = self.client.post(reverse('toggle_user_staff', args=[self.regular_user.id]))
        self.assertEqual(response.status_code, 302) # Redirected due to @user_passes_test(is_superuser)
        self.regular_user.refresh_from_db()
        self.assertFalse(self.regular_user.is_staff)

    def test_superuser_cannot_demote_self(self):
        self.client.login(username='superadmin', password='Password123!')
        response = self.client.post(reverse('toggle_user_staff', args=[self.superuser.id]))
        self.assertRedirects(response, reverse('users_list'))
        self.superuser.refresh_from_db()
        self.assertTrue(self.superuser.is_staff)

    def test_superuser_can_delete_office(self):
        office = LaundryOffice.objects.create(name="Office To Delete")
        self.client.login(username='superadmin', password='Password123!')
        response = self.client.post(reverse('delete_office', args=[office.id]))
        self.assertRedirects(response, reverse('offices_list'))
        self.assertFalse(LaundryOffice.objects.filter(id=office.id).exists())

    def test_staff_cannot_delete_office(self):
        office = LaundryOffice.objects.create(name="Office Main")
        self.client.login(username='staffuser', password='Password123!')
        response = self.client.post(reverse('delete_office', args=[office.id]))
        self.assertEqual(response.status_code, 302)
        self.assertTrue(LaundryOffice.objects.filter(id=office.id).exists())

    def test_superuser_can_delete_ticket(self):
        office = LaundryOffice.objects.create(name="Ticket Office")
        ticket = SupportTicket.objects.create(
            office=office,
            title="Complaint Ticket",
            description="Bad service",
            ticket_type="complaint"
        )
        self.client.login(username='superadmin', password='Password123!')
        response = self.client.post(reverse('delete_ticket', args=[ticket.id]))
        self.assertRedirects(response, reverse('admin_tickets_list'))
        ticket.refresh_from_db()
        self.assertTrue(ticket.is_deleted)

    def test_staff_cannot_delete_ticket(self):
        office = LaundryOffice.objects.create(name="Ticket Office 2")
        ticket = SupportTicket.objects.create(
            office=office,
            title="Feature Request",
            description="Add dark mode",
            ticket_type="feature_request"
        )
        self.client.login(username='staffuser', password='Password123!')
        response = self.client.post(reverse('delete_ticket', args=[ticket.id]))
        self.assertEqual(response.status_code, 302)
        ticket.refresh_from_db()
        self.assertFalse(ticket.is_deleted)

    def test_staff_list_view_access(self):
        self.client.login(username='staffuser', password='Password123!')
        response = self.client.get(reverse('staff_list'))
        self.assertEqual(response.status_code, 200)
        self.assertTemplateUsed(response, 'landing/staff.html')
        self.assertIn('staff_users', response.context)
        self.assertEqual(len(response.context['staff_users']), 2) # staffuser + superadmin

    def test_create_staff_user_success(self):
        office = LaundryOffice.objects.create(name="Central Branch")
        self.client.login(username='superadmin', password='Password123!')
        response = self.client.post(reverse('create_staff_user'), {
            'username': 'new_staff_member',
            'email': 'newstaff@sparkles.com.ng',
            'first_name': 'New',
            'last_name': 'Staff',
            'password': 'StaffPassword123!',
            'office': str(office.id),
            'is_office_admin': 'on',
        })
        self.assertRedirects(response, reverse('staff_list'))
        created = User.objects.get(username='new_staff_member')
        self.assertTrue(created.is_staff)
        self.assertTrue(created.is_office_admin)
        self.assertEqual(created.email, 'newstaff@sparkles.com.ng')
        self.assertEqual(created.office, office)
        self.assertTrue(created.check_password('StaffPassword123!'))

    def test_create_staff_user_validation(self):
        self.client.login(username='superadmin', password='Password123!')
        # Attempt to create user with existing username
        response = self.client.post(reverse('create_staff_user'), {
            'username': 'staffuser',
            'email': 'unique_email@sparkles.com.ng',
            'password': 'Password123!',
        })
        self.assertRedirects(response, reverse('staff_list'))
        self.assertEqual(User.objects.filter(username='staffuser').count(), 1)

    def test_tier_limit_permission_order_limits(self):
        from api.permissions import TierLimitPermission
        from operations.models import Order
        from unittest.mock import MagicMock

        perm = TierLimitPermission()
        
        class DummyView:
            pass
        DummyView.__name__ = 'OrderListCreateView'
        view = DummyView()

        office = LaundryOffice.objects.create(name="Free Branch", subscription_tier="free")
        user = User.objects.create_user(username="free_tier_user", password="Password123!", office=office)
        
        request = MagicMock()
        request.method = 'POST'
        request.user = user

        from operations.models import OrderStatus
        status = OrderStatus.objects.create(office=office, name="Pending")

        # Under 20 orders -> allowed
        self.assertTrue(perm.has_permission(request, view))

        # Create 20 orders for office
        for i in range(20):
            Order.objects.create(office=office, current_status=status, customer_name="Test Customer", customer_phone="12345", total_price=100)

        # 20 orders -> denied for Free tier
        self.assertFalse(perm.has_permission(request, view))
        self.assertIn("20 orders per year", perm.message)

        # Starter tier -> allowed (20 < 100)
        office.subscription_tier = "starter"
        office.save()
        self.assertTrue(perm.has_permission(request, view))

        # Pro tier -> allowed (20 < 500)
        office.subscription_tier = "pro"
        office.save()
        self.assertTrue(perm.has_permission(request, view))


class RegistrationProTrialTests(TestCase):
    def setUp(self):
        self.client = Client()

    def test_registration_assigns_pro_trial_and_logs(self):
        from offices.models import SubscriptionLog
        response = self.client.post(
            reverse('api-register'),
            data={
                'office_name': 'Sparkle Cleaners',
                'email': 'owner@sparklecleaners.com',
                'password': 'StrongPassword123!'
            },
            content_type='application/json'
        )
        self.assertEqual(response.status_code, 201)
        data = response.json()
        self.assertEqual(data['status'], 'success')
        self.assertEqual(data['subscription_tier'], 'pro')
        self.assertEqual(data['effective_subscription_tier'], 'pro')
        self.assertIsNotNone(data['subscription_expires_at'])

        office = LaundryOffice.objects.get(name='Sparkle Cleaners')
        self.assertEqual(office.subscription_tier, 'pro')
        self.assertEqual(office.effective_tier, 'pro')
        self.assertIsNotNone(office.subscription_expires_at)

        # Check SubscriptionLog
        log = SubscriptionLog.objects.filter(office=office).first()
        self.assertIsNotNone(log)
        self.assertEqual(log.tier, 'pro')
        self.assertEqual(log.event_type, 'new')

    def test_effective_tier_downgrades_to_free_after_expiry(self):
        from django.utils import timezone
        import datetime

        # Office registered with expired trial (past date)
        expired_date = timezone.now() - datetime.timedelta(days=1)
        office = LaundryOffice.objects.create(
            name="Expired Pro Office",
            subscription_tier="pro",
            subscription_expires_at=expired_date
        )
        self.assertEqual(office.effective_tier, "free")

        # Current user endpoint returns effective tier as free
        from rest_framework.test import APIClient
        api_client = APIClient()
        user = User.objects.create_user(
            username='expired_owner@example.com',
            email='expired_owner@example.com',
            password='Password123!',
            office=office,
            is_office_admin=True
        )
        api_client.force_authenticate(user=user)
        response = api_client.get(reverse('current-user-detail'))
        self.assertEqual(response.status_code, 200)
        user_data = response.json()
        self.assertEqual(user_data['subscription_tier'], 'free')
        self.assertEqual(user_data['effective_subscription_tier'], 'free')
        self.assertEqual(user_data['raw_subscription_tier'], 'pro')

    def test_welcome_email_content_contains_pro_trial(self):
        from unittest.mock import patch
        from api.emails import send_welcome_registration
        from django.utils import timezone
        import datetime

        expiry = timezone.now() + datetime.timedelta(days=30)
        with patch('api.emails._send_html_email') as mock_send:
            mock_send.return_value = True
            result = send_welcome_registration('trialuser@example.com', 'Elite Wash', expires_at=expiry)
            self.assertTrue(result)
            self.assertTrue(mock_send.called)

            args, kwargs = mock_send.call_args
            subject = args[0]
            to_email = args[1]
            html_content = args[2]
            text_content = args[3]

            self.assertIn("1-Month Free Pro Access", subject)
            self.assertEqual(to_email, 'trialuser@example.com')
            self.assertIn("30-Day Pro Access", html_content)
            self.assertIn("Free plan", html_content)
            self.assertIn("Up to 500 orders", html_content)
            self.assertIn("30-day trial", text_content)




