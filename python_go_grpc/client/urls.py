from django.urls import path
from . import views
urlpatterns = [path("", views.index), path("grpc", views.direct), path("nginx", views.proxy)]
