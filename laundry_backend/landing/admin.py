from django.contrib import admin
from .models import WaitlistEntry

@admin.register(WaitlistEntry)
class WaitlistEntryAdmin(admin.ModelAdmin):
    list_display = ('email', 'created_at', 'is_notified')
    list_filter = ('is_notified', 'created_at')
    search_fields = ('email',)
    ordering = ('-created_at',)
