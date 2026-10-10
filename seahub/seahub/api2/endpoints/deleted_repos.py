import logging

from django.conf import settings
from rest_framework.authentication import SessionAuthentication
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework import status
from seahub.organizations.models import DISABLE_ORG_USER_CLEAN_TRASH, OrgAdminSettings
from seahub.utils import is_org_context
from seaserv import seafile_api

from seahub.signals import repo_restored
from seahub.api2.throttling import UserRateThrottle
from seahub.api2.authentication import TokenAuthentication
from seahub.api2.base import APIView
from seahub.api2.utils import api_error
from seahub.base.templatetags.seahub_tags import email2nickname, \
        email2contact_email
from seahub.utils.timeutils import timestamp_to_isoformat_timestr
from constance import config

logger = logging.getLogger(__name__)


def can_user_clean_deleted_repos(request):
    if not config.ENABLE_USER_CLEAN_TRASH:
        return False

    if is_org_context(request):
        org_id = request.user.org.org_id
        if org_id and org_id > 0:
            disable_clean_trash = OrgAdminSettings.objects.filter(
                org_id=org_id, key=DISABLE_ORG_USER_CLEAN_TRASH
            ).first()
            if disable_clean_trash is not None and int(disable_clean_trash.value):
                return False

    return True


class DeletedRepos(APIView):
    authentication_classes = (TokenAuthentication, SessionAuthentication)
    permission_classes = (IsAuthenticated,)
    throttle_classes = (UserRateThrottle,)

    def get(self, request):
        """
        get the deleted-repos of owner
        """
        trashs_json = []
        email = request.user.username

        trash_repos = seafile_api.get_trash_repos_by_owner(email)
        for r in trash_repos:
            trash = {
                    "repo_id": r.repo_id,
                    "owner_email": email,
                    "owner_name": email2nickname(email),
                    "owner_contact_email": email2contact_email(email),
                    "repo_name": r.repo_name,
                    "org_id": r.org_id,
                    "head_commit_id": r.head_id,
                    "encrypted": r.encrypted,
                    "del_time": timestamp_to_isoformat_timestr(r.del_time),
                    "size": r.size,
            }
            trashs_json.append(trash)
        return Response(trashs_json)

    def post(self, request):
        """
        restore deleted-repo
            return:
                return True if success, otherwise api_error
        """
        post_data = request.POST
        repo_id = post_data.get('repo_id', '')
        username = request.user.username
        if not repo_id:
            error_msg = "repo_id can not be empty."
            return api_error(status.HTTP_400_BAD_REQUEST, error_msg)
        owner = seafile_api.get_trash_repo_owner(repo_id)
        if owner is None:
            error_msg = "Library does not exist in trash."
            return api_error(status.HTTP_400_BAD_REQUEST, error_msg)
        if owner != username:
            return api_error(status.HTTP_403_FORBIDDEN, 'Permission denied.')

        try:
            seafile_api.restore_repo_from_trash(repo_id)
            repo_restored.send(sender=None, repo_id=repo_id, operator=username)
        except Exception as e:
            logger.error(e)
            error_msg = "Internal Server Error"
            return api_error(status.HTTP_500_INTERNAL_SERVER_ERROR, error_msg)

        return Response({"success": True})

    def delete(self, request):
        """
        clean all deleted-repos
            return:
                return True if success, otherwise api_error
        """
        if not can_user_clean_deleted_repos(request):
            return api_error(status.HTTP_403_FORBIDDEN, 'Permission denied.')

        username = request.user.username

        try:
            seafile_api.empty_repo_trash_by_owner(username)
        except Exception as e:
            logger.error(e)
            error_msg = "Internal Server Error"
            return api_error(status.HTTP_500_INTERNAL_SERVER_ERROR, error_msg)

        return Response({"success": True})


class DeletedRepo(APIView):
    authentication_classes = (TokenAuthentication, SessionAuthentication)
    permission_classes = (IsAuthenticated,)
    throttle_classes = (UserRateThrottle,)

    def delete(self, request, repo_id):
        """
        permanently delete deleted-repo
            return:
                return True if success, otherwise api_error
        """
        if not can_user_clean_deleted_repos(request):
            return api_error(status.HTTP_403_FORBIDDEN, 'Permission denied.')

        owner = seafile_api.get_trash_repo_owner(repo_id)
        username = request.user.username
        if owner is None:
            error_msg = "Library does not exist in trash."
            return api_error(status.HTTP_404_NOT_FOUND, error_msg)
        if owner != username:
            return api_error(status.HTTP_403_FORBIDDEN, 'Permission denied.')

        try:
            seafile_api.del_repo_from_trash(repo_id)
        except Exception as e:
            logger.error(e)
            error_msg = "Internal Server Error"
            return api_error(status.HTTP_500_INTERNAL_SERVER_ERROR, error_msg)

        return Response({"success": True})
