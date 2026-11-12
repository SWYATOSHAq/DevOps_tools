import grpc
from django.http import JsonResponse
from django.shortcuts import render
from .api.client import roll_die

ICONS = ["—", "⚀", "⚁", "⚂", "⚃", "⚄", "⚅"]

def index(request):
    values = [0, 0]
    errors = []
    if request.method == "POST":
        for i, address in enumerate(("127.0.0.1:8443", "127.0.0.1:9448")):
            try:
                values[i] = roll_die(address)
            except grpc.RpcError as error:
                errors.append(f"{address}: {error.code().name}")
    a, b = values
    return render(request, "index.html", {"a": a, "b": b,
        "icon_a": ICONS[a], "icon_b": ICONS[b], "errors": errors,
        "sign": "=" if a == b else "<" if a < b else ">"}, status=502 if errors else 200)

def result(address):
    try:
        return JsonResponse({"value": roll_die(address), "endpoint": address})
    except grpc.RpcError as error:
        return JsonResponse({"error": error.code().name}, status=502)

def direct(request):
    return result("127.0.0.1:8443")

def proxy(request):
    return result("127.0.0.1:9448")
