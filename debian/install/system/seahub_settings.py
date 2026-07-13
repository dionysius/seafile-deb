# Seahub Django settings. Reference:
# https://manual.seafile.com/13.0/config/seahub_settings_py/
#
# Connection secrets (database, cache) are taken from the environment via
# seafile.env; avoid duplicating them here.
import os

# Django secret key. Generated on first install; keep it stable and private.
SECRET_KEY = ""

# Database backend. Default is SQLite (seahub.db under the data directory). For the
# MySQL/MariaDB backend switch ENGINE to django.db.backends.mysql and fill in the
# connection from the SEAFILE_MYSQL_DB_* environment variables.
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.sqlite3',
        'NAME': '/var/lib/seafile/seahub.db',
    }
}

# Public address clients use to reach the server.
_proto = os.environ.get('SEAFILE_SERVER_PROTOCOL', 'http')
_host = os.environ.get('SEAFILE_SERVER_HOSTNAME', 'localhost')
SERVICE_URL = '%s://%s' % (_proto, _host)
FILE_SERVER_ROOT = SERVICE_URL + '/seafhttp'

# User-uploaded content (avatars, thumbnails).
MEDIA_ROOT = '/var/lib/seafile/seahub-data/'

# Collected static files. seahub derives STATIC_ROOT from MEDIA_ROOT before this file
# loads, so it points into the read-only install tree; redirect it to a writable path
# where seafile-migrate runs collectstatic (which also builds the staticfiles manifest).
STATIC_ROOT = '/var/lib/seafile/seahub-data/assets/'

# WhiteNoise serves the collected static assets (/media/assets/) from within gunicorn
# with immutable caching and gzip/brotli precompression, so the default needs no web
# server for static. Dynamic media (avatars, custom logos) stays on seahub's built-in
# SERVE_STATIC. EXTRA_ prefix because seahub's settings loader only appends lists; this
# lands WhiteNoise where the static_view it supersedes already sat.
EXTRA_MIDDLEWARE = ['whitenoise.middleware.WhiteNoiseMiddleware']

# Content-hashed names plus the precompressed variants WhiteNoise serves; subclass of
# the ManifestStaticFilesStorage seahub defaults to.
STORAGES = {
    'default': {'BACKEND': 'django.core.files.storage.FileSystemStorage'},
    'staticfiles': {'BACKEND': 'whitenoise.storage.CompressedManifestStaticFilesStorage'},
}

# Optional cache (redis/memcached) configured via environment; left at the local
# default here.
