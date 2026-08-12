from django.contrib import admin
from django.db.models import Count

from .models import OfficeImage, PasswordResetOTP, LaundryOffice, User


class OfficeUserInline(admin.TabularInline):
	model = User
	fk_name = 'office'
	extra = 0
	fields = ('username', 'email', 'is_office_admin', 'is_active')
	readonly_fields = ('username', 'email', 'is_office_admin', 'is_active')
	can_delete = False


@admin.register(LaundryOffice)
class LaundryOfficeAdmin(admin.ModelAdmin):
	list_display = ('name', 'subscription_tier', 'subscription_expires_at', 'contact_info', 'user_count', 'created_at', 'updated_at')
	list_filter = ('subscription_tier', 'subscription_expires_at', 'is_deleted', 'created_at')
	search_fields = ('name', 'contact_info')
	ordering = ('-created_at',)
	inlines = [OfficeUserInline]
	actions = [
		'set_subscription_free',
		'set_subscription_starter',
		'set_subscription_pro',
		'set_subscription_premium',
	]

	@admin.display(ordering='users__count', description='Users')
	def user_count(self, obj):
		return getattr(obj, 'users__count', obj.users.count())

	def get_queryset(self, request):
		queryset = super().get_queryset(request)
		return queryset.annotate(users__count=Count('users'))

	@admin.action(description='Set selected offices to Free')
	def set_subscription_free(self, request, queryset):
		queryset.update(subscription_tier='free')

	@admin.action(description='Set selected offices to Starter (30 Days Expiry)')
	def set_subscription_starter(self, request, queryset):
		for office in queryset:
			office.subscription_tier = 'starter'
			office.extend_subscription(days=30)
			office.save()

	@admin.action(description='Set selected offices to Pro (30 Days Expiry)')
	def set_subscription_pro(self, request, queryset):
		for office in queryset:
			office.subscription_tier = 'pro'
			office.extend_subscription(days=30)
			office.save()

	@admin.action(description='Set selected offices to Premium (30 Days Expiry)')
	def set_subscription_premium(self, request, queryset):
		for office in queryset:
			office.subscription_tier = 'premium'
			office.extend_subscription(days=30)
			office.save()


@admin.register(User)
class OfficeUserAdmin(admin.ModelAdmin):
	list_display = ('username', 'email', 'office', 'is_office_admin', 'is_active', 'date_joined')
	list_filter = ('is_office_admin', 'is_active', 'office', 'office__subscription_tier')
	search_fields = ('username', 'email', 'office__name')
	ordering = ('-date_joined',)
	autocomplete_fields = ('office',)


@admin.register(OfficeImage)
class OfficeImageAdmin(admin.ModelAdmin):
	list_display = ('office', 'description', 'created_at')
	search_fields = ('office__name', 'description')
	list_filter = ('created_at',)


@admin.register(PasswordResetOTP)
class PasswordResetOTPAdmin(admin.ModelAdmin):
	list_display = ('email', 'otp', 'is_used', 'expires_at', 'created_at')
	list_filter = ('is_used', 'created_at', 'expires_at')
	search_fields = ('email', 'otp')
	ordering = ('-created_at',)
