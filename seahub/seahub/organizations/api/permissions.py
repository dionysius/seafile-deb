from rest_framework.permissions import BasePermission

class IsOrgAdmin(BasePermission):
    """
    Check whether user is org admin.
    """

    def has_permission(self, request, *args, **kwargs):
        org = getattr(request.user, 'org', None)
        if org and org.is_staff:
            return True
        return False
