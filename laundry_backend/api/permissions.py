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
    Enforces subscription tier limits on specific resources (e.g., max users).
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
        
        # Example: Enforce user limit on SubUserListCreateView
        if view.__class__.__name__ == 'SubUserListCreateView':
            current_users = user.office.users.count()
            if tier == 'free' and current_users >= 3:
                self.message = "Free tier allows a maximum of 3 users. Please upgrade to Basic or Premium."
                return False
            elif tier == 'basic' and current_users >= 10:
                self.message = "Basic tier allows a maximum of 10 users. Please upgrade to Premium."
                return False
                
        return True
