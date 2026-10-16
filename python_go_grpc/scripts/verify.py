"""Real integration checks against the running Go server and nginx."""
import concurrent.futures
import json
import urllib.request
import grpc
from client.api.client import roll_die

for address in ("127.0.0.1:8443", "127.0.0.1:9448"):
    with concurrent.futures.ThreadPoolExecutor(max_workers=8) as executor:
        values = list(executor.map(lambda _: roll_die(address), range(24)))
    assert all(1 <= value <= 6 for value in values)
    print(f"PASS {address}: 24 concurrent mTLS rolls, values={sorted(set(values))}")
    try:
        roll_die(address, authenticated=False)
    except grpc.RpcError as error:
        print(f"PASS {address}: client without certificate rejected ({error.code().name})")
    else:
        raise AssertionError("Unauthenticated request accepted")
for port in (8000, 8001, 8002):
    for route in ("grpc", "nginx"):
        with urllib.request.urlopen(f"http://127.0.0.1:{port}/{route}", timeout=10) as response:
            result=json.load(response)
        assert 1 <= result["value"] <= 6
        print(f"PASS Django :{port}/{route}: {result}")
print("ALL INTEGRATION CHECKS PASSED")
