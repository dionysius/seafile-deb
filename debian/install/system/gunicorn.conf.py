# gunicorn configuration for seahub. Reference:
# https://manual.seafile.com/13.0/config/gunicorn/
import os

daemon = False
workers = int(os.environ.get('SEAHUB_WORKERS', '3'))

# Listen locally; put a reverse proxy (nginx) in front for TLS and static files.
bind = '127.0.0.1:8000'

# Long timeout for uploads/downloads proxied through seahub.
timeout = 1200
limit_request_line = 8190

# Log to stdout/stderr so journald captures it.
accesslog = '-'
errorlog = '-'
