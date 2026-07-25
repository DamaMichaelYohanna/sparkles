import os
import logging
from django.core.wsgi import get_wsgi_application

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
application = get_wsgi_application()

# Auto-apply database migrations on deployment / cold start if database is accessible
try:
    from django.core.management import call_command
    call_command('migrate', interactive=False)
except Exception as e:
    logging.warning("[WSGI] Auto-migration check: %s", e)

app = application

