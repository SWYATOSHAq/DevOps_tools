from pathlib import Path
import os
BASE_DIR = Path(__file__).resolve().parent.parent
SECRET_KEY = os.environ.get("DJANGO_SECRET_KEY", "local-coursework-only-do-not-deploy")
DEBUG = False
ALLOWED_HOSTS = ["127.0.0.1", "localhost", "testserver"]
ROOT_URLCONF = "client.urls"
MIDDLEWARE = ["django.middleware.csrf.CsrfViewMiddleware"]
INSTALLED_APPS = []
TEMPLATES = [{"BACKEND": "django.template.backends.django.DjangoTemplates", "DIRS": [BASE_DIR / "client/templates"], "APP_DIRS": True}]
