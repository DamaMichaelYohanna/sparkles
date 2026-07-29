from django.test import TestCase, Client
from django.urls import reverse
from offices.models import User
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
