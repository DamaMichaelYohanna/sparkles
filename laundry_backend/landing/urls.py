from django.urls import path
from . import views

urlpatterns = [
    path('', views.landing_page, name='landing-page'),
    path('dashboard/', views.dashboard, name='dashboard'),
    path('dashboard/offices/', views.offices_list, name='offices_list'),
    path('dashboard/users/', views.users_list, name='users_list'),
    path('dashboard/settings/', views.settings_view, name='settings_view'),
    path('join-waitlist/', views.JoinWaitlistView.as_view(), name='api-waitlist'),
]
