from pathlib import Path
import grpc
from . import api_pb2, api_pb2_grpc

CERTS = Path(__file__).resolve().parents[2] / "certs"

def roll_die(address: str, authenticated: bool = True) -> int:
    credentials = grpc.ssl_channel_credentials(
        root_certificates=(CERTS / "ca.pem").read_bytes(),
        private_key=(CERTS / "client-key.pem").read_bytes() if authenticated else None,
        certificate_chain=(CERTS / "client.pem").read_bytes() if authenticated else None,
    )
    with grpc.secure_channel(address, credentials) as channel:
        response = api_pb2_grpc.DiceServiceStub(channel).RollDie(
            api_pb2.RollDieRequest(), timeout=5)
    if not 1 <= response.value <= 6:
        raise ValueError("Server returned a value outside 1..6")
    return response.value
