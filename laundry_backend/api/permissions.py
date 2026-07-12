from rest_framework import permissions

class IsOfficeAdmin(permissions.IsAuthenticated):
    """
    Allows access only to users who are marked as office admins.
    """
    def has_permission(self, request, view):
        is_authenticated = super().has_permission(request, view)
        return is_authenticated and getattr(request.user, 'is_office_admin', False)

class TierLimitPermission(permissions.BasePermission):
    """
    Enforces subscription tier limits on specific resources (e.g., max users and monthly orders).
    """
    message = "Subscription tier limit reached. Please upgrade to add more."

    def has_permission(self, request, view):
        # We only want to restrict creation (POST)
        if request.method != 'POST':
            return True
            
        user = request.user
        if not user or not user.office:
            return True
            
        tier = user.office.subscription_tier
        
        # 1. Enforce staff user limit on SubUserListCreateView
        if view.__class__.__name__ == 'SubUserListCreateView':
            # Count only active non-admin staff users
            current_staff = user.office.users.filter(is_office_admin=False).count()
            if tier == 'free' and current_staff >= 1:
                self.message = "Free tier allows a maximum of 1 staff account. Please upgrade to Starter, Pro, or Premium."
                return False
            elif tier == 'starter' and current_staff >= 3:
                self.message = "Starter tier allows a maximum of 3 staff accounts. Please upgrade to Pro or Premium."
                return False
            elif tier == 'pro' and current_staff >= 10:
                self.message = "Pro tier allows a maximum of 10 staff accounts. Please upgrade to Premium."
                return False
                
        # 2. Enforce monthly order creation limit on OrderListCreateView and SyncAPIView
        if view.__class__.__name__ in ['OrderListCreateView', 'SyncAPIView']:
            from django.utils import timezone
            now = timezone.now()
            current_month_orders = user.office.orders.filter(
                created_at__year=now.year,
                created_at__month=now.month
            ).count()
            
            if tier == 'free' and current_month_orders >= 50:
                self.message = "Free tier allows a maximum of 50 orders per month. Please upgrade to Starter, Pro, or Premium."
                return False
            elif tier == 'starter' and current_month_orders >= 500:
                self.message = "Starter tier allows a maximum of 500 orders per month. Please upgrade to Pro or Premium."
                return False
                
        return True
