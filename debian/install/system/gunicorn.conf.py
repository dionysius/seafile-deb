# gunicorn configuration for seahub. Reference:
# https://gunicorn.org/reference/settings/

daemon = False
workers = 5
threads = 4

# Listen locally; the reverse proxy in front routes clients here.
bind = '127.0.0.1:8000'

# Long timeout for uploads/downloads proxied through seahub.
timeout = 1200
limit_request_line = 8190

# Proxy headers passed through into WSGI vars; REMOTE_USER enables proxy-based SSO.
forwarder_headers = 'SCRIPT_NAME,PATH_INFO,REMOTE_USER'

# Log to stdout/stderr so journald captures it.
accesslog = '-'
errorlog = '-'
