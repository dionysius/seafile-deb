# Seahub Django settings. Reference:
# https://manual.seafile.com/13.0/config/seahub_settings_py/
#
# Database, cache and the public address (SERVICE_URL/FILE_SERVER_ROOT) are taken
# from the environment via seafile.env; avoid duplicating them here.
#
# Many of these can also be changed in the admin web UI (System Admin > Settings),
# which stores them in the database and overrides this file.

# Django secret key. Generate one, e.g. `openssl rand -hex 32`; keep it stable
# and private.
SECRET_KEY = ""

# User-uploaded content (avatars, thumbnails).
MEDIA_ROOT = '/var/lib/seafile/seahub-data/'

# Collected static files. seahub derives STATIC_ROOT from MEDIA_ROOT before this file
# loads, so it points into the read-only install tree; redirect it to a writable path
# where seafile-migrate runs collectstatic (which also builds the staticfiles manifest).
STATIC_ROOT = '/var/lib/seafile/seahub-data/assets/'

### Site ###
#SITE_NAME = 'Seafile'
#SITE_TITLE = 'Private Seafile'
# Django timezone for displayed times.
#TIME_ZONE = 'UTC'

### Outgoing email ###
# Required for password reset, notifications and invitations; unconfigured,
# seahub cannot send mail. Example:
#EMAIL_USE_TLS = True
#EMAIL_HOST = 'smtp.example.com'
#EMAIL_HOST_USER = 'seafile@example.com'
#EMAIL_HOST_PASSWORD = ''
#EMAIL_PORT = 587
#DEFAULT_FROM_EMAIL = EMAIL_HOST_USER
#SERVER_EMAIL = EMAIL_HOST_USER

### User accounts ###
# Open self-registration.
#ENABLE_SIGNUP = False
# Newly registered users are active immediately; set False to require admin activation.
#ACTIVATE_AFTER_REGISTRATION = True
# Notify admins by mail when a user registers (used with admin activation).
#REGISTRATION_SEND_MAIL = False
#ENABLE_CHANGE_PASSWORD = True
#ENABLE_UPDATE_USER_INFO = True
#ENABLE_DELETE_ACCOUNT = True
# Force a password change after an admin adds or resets a user.
#FORCE_PASSWORD_CHANGE = True
# Require strong passwords (upper/lower/digit/symbol) instead of only a minimum length.
#USER_STRONG_PASSWORD_REQUIRED = False

### Login and sessions ###
# Failed attempts before the captcha appears.
#LOGIN_ATTEMPT_LIMIT = 5
# Deactivate the account when the attempt limit is exceeded.
#FREEZE_USER_ON_LOGIN_FAILED = False
# Session lifetime in seconds.
#SESSION_COOKIE_AGE = 86400
# Days "remember me" keeps the login.
#LOGIN_REMEMBER_DAYS = 7
#ENABLE_TWO_FACTOR_AUTH = False

### Libraries and files ###
#ENABLE_ENCRYPTED_LIBRARY = True
#REPO_PASSWORD_MIN_LENGTH = 8
# Let users change per-library history retention.
#ENABLE_REPO_HISTORY_SETTING = True
# Let users empty their own trash.
#ENABLE_USER_CLEAN_TRASH = True
# Only allow syncing whole libraries, not arbitrary subfolders.
#DISABLE_SYNC_WITH_ANY_FOLDER = False
# Maximum number of files selectable in one web upload.
#MAX_NUMBER_OF_FILES_FOR_FILEUPLOAD = 1000
#ENABLE_WIKI = True

### Share links ###
# Allowed/preselected expiry in days (0 = no limit/none).
#SHARE_LINK_EXPIRE_DAYS_MIN = 0
#SHARE_LINK_EXPIRE_DAYS_MAX = 0
#SHARE_LINK_EXPIRE_DAYS_DEFAULT = 0
# Require a login to open share links.
#SHARE_LINK_LOGIN_REQUIRED = False
#SHARE_LINK_FORCE_USE_PASSWORD = False
#SHARE_LINK_PASSWORD_MIN_LENGTH = 10
#ENABLE_SHARE_TO_ALL_GROUPS = False

### Rarely needed ###
# Terms shown and required on first login.
#ENABLE_TERMS_AND_CONDITIONS = False
# Disable the web UI settings storage so only this file applies.
#ENABLE_SETTINGS_VIA_WEB = True
# Thumbnail sizes in px / source size limits in MB.
#THUMBNAIL_DEFAULT_SIZE = 256
#THUMBNAIL_SIZE_FOR_GRID = 512
#THUMBNAIL_IMAGE_SIZE_LIMIT = 30
