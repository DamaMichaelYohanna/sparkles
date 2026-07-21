from django.urls import path
from django.views.generic import TemplateView
from . import views

urlpatterns = [
    path('', views.landing_page, name='landing-page'),
    path('terms/', views.terms_of_service, name='terms-of-service'),
    path('privacy/', views.privacy_policy, name='privacy-policy'),
    path('dashboard/', views.dashboard, name='dashboard'),
    path('dashboard/offices/', views.offices_list, name='offices_list'),
    path('dashboard/users/', views.users_list, name='users_list'),
    path('dashboard/users/<uuid:pk>/toggle/', views.toggle_user_active, name='toggle_user_active'),
    path('dashboard/users/<uuid:pk>/delete/', views.delete_user, name='delete_user'),
    path('dashboard/subscriptions/', views.subscriptions_view, name='subscriptions_view'),
    path('dashboard/settings/', views.settings_view, name='settings_view'),
    path('dashboard/waitlist/', views.waitlist_dashboard, name='waitlist_dashboard'),
    path('dashboard/waitlist/send-email/', views.send_waitlist_email, name='send_waitlist_email'),
    path('dashboard/waitlist/<uuid:pk>/toggle/', views.toggle_waitlist_notified, name='toggle_waitlist'),
    path('dashboard/waitlist/<uuid:pk>/delete/', views.delete_waitlist_entry, name='delete_waitlist'),
    path('join-waitlist/', views.JoinWaitlistView.as_view(), name='api-waitlist'),
    path('sitemap.xml', views.sitemap_xml, name='sitemap-xml'),
    path('robots.txt', views.robots_txt, name='robots-txt'),
    path('r/latest/', views.public_latest_receipt_view, name='public-receipt-latest'),
    path('manifest.json', views.pwa_manifest_view, name='pwa-manifest'),
    path('sw.js', TemplateView.as_view(template_name='landing/sw.js', content_type='application/javascript'), name='pwa-service-worker'),
    path('r/<str:tracking_code>/', views.public_receipt_view, name='public-receipt-detail'),
]
