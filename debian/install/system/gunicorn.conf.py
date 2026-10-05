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

# The journal records the time and pid of every line.
access_log_format = '%(h)s %(l)s %(u)s "%(r)s" %(s)s %(b)s "%(f)s" "%(a)s"'
logconfig_dict = {
    'formatters': {
        'generic': {'format': '[%(levelname)s] %(message)s'},
        'access': {'format': '%(message)s'},
    },
    'handlers': {
        'console': {'class': 'logging.StreamHandler', 'formatter': 'access', 'stream': 'ext://sys.stdout'},
        'error_console': {'class': 'logging.StreamHandler', 'formatter': 'generic', 'stream': 'ext://sys.stderr'},
    },
    'root': {'level': 'INFO', 'handlers': ['error_console']},
    'loggers': {
        'gunicorn.error': {'level': 'INFO', 'handlers': ['error_console'], 'propagate': False, 'qualname': 'gunicorn.error'},
        'gunicorn.access': {'level': 'INFO', 'handlers': ['console'], 'propagate': False, 'qualname': 'gunicorn.access'},
    },
}
