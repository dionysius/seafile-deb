# Seahub Django settings. Reference:
# https://manual.seafile.com/13.0/config/seahub_settings_py/
#
# Database, cache and the public address (SERVICE_URL/FILE_SERVER_ROOT) are taken
# from the environment via seafile.env; avoid duplicating them here.

# Django secret key. Generated on first install; keep it stable and private.
SECRET_KEY = ""

# User-uploaded content (avatars, thumbnails).
MEDIA_ROOT = '/var/lib/seafile/seahub-data/'

# Collected static files. seahub derives STATIC_ROOT from MEDIA_ROOT before this file
# loads, so it points into the read-only install tree; redirect it to a writable path
# where seafile-migrate runs collectstatic (which also builds the staticfiles manifest).
STATIC_ROOT = '/var/lib/seafile/seahub-data/assets/'

# Optional cache (redis/memcached) configured via environment; left at the local
# default here.
