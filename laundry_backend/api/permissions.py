from rest_framework import permissions

class IsOfficeAdmin(permissions.IsAuthenticated):
    """
    Allows access only to users who are marked as office admins.
    """
    def has_permission(self, request, view):
        is_authenticated = super().has_permission(request, view)
        return is_authenticated and getattr(request.user, 'is_office_admin', False)
