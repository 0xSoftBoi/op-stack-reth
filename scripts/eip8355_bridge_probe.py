#!/usr/bin/env python3
"""Exercise a draft EIP-8355 ML-DSA-65 precompile over JSON-RPC.

This is a conformance probe, not an implementation of the precompile. It uses
pqcrypto's real FIPS 204 ML-DSA-65 implementation to create a fresh positive
vector for every run, then checks positive, tampered, and short-input cases.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
import statistics
import sys
import time
import urllib.error
import urllib.request


DOMAIN_MESSAGE = (
    b"GSX-SUWAPPU:EIP-8355:bridge-vector:v1\x00"
    b"source=eip155:1;destination=eip155:10;nonce=42;"
    b"payload=USDC:100000000:0x1111111111111111111111111111111111111111"
)
SUCCESS_WORD = "0x" + ("00" * 31) + "01"
FAILURE_WORD = "0x" + ("00" * 32)


def normalize_address(value: str) -> str:
    if not value.startswith("0x"):
        raise ValueError("precompile address must be hex (for example 0x13)")
    number = int(value, 16)
    if number < 0 or number >= 2**160:
        raise ValueError("precompile address is outside the 160-bit address space")
    return f"0x{number:040x}"


def rpc_call(rpc_url: str, to: str, data: bytes, request_id: int) -> str:
    payload = json.dumps(
        {
            "jsonrpc": "2.0",
            "id": request_id,
            "method": "eth_call",
            "params": [{"to": to, "data": "0x" + data.hex()}, "latest"],
        }
    ).encode()
    request = urllib.request.Request(
        rpc_url,
        data=payload,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(request, timeout=20) as response:
        body = json.loads(response.read())
    if "error" in body:
        raise RuntimeError(f"JSON-RPC error: {body['error']}")
    result = body.get("result")
    if not isinstance(result, str):
        raise RuntimeError(f"JSON-RPC response has no hex result: {body!r}")
    return result.lower()


def sha256_hex(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--rpc-url",
        default=os.environ.get("SUWAPPU_RPC_URL", "http://localhost:8545"),
        help="execution JSON-RPC URL (default: SUWAPPU_RPC_URL or localhost:8545)",
    )
    parser.add_argument(
        "--precompile",
        default=os.environ.get("MLDSA65_PRECOMPILE_ADDRESS"),
        help="draft ML-DSA-65 precompile address; required because the EIP is not final",
    )
    parser.add_argument(
        "--benchmark-iterations",
        type=int,
        default=1000,
        help="local real-backend verification samples to collect (default: 1000)",
    )
    parser.add_argument(
        "--local-only",
        action="store_true",
        help="generate/verify/benchmark with pqcrypto without making JSON-RPC calls",
    )
    args = parser.parse_args()

    if not args.local_only and not args.precompile:
        parser.error("set --precompile or MLDSA65_PRECOMPILE_ADDRESS")
    precompile = None
    if args.precompile:
        try:
            precompile = normalize_address(args.precompile)
        except ValueError as exc:
            parser.error(str(exc))

    try:
        from pqcrypto.sign import ml_dsa_65
    except ImportError:
        print(
            "ERROR: pqcrypto is required; install the pinned probe dependency with "
            "`python3 -m pip install pqcrypto==0.4.0`.",
            file=sys.stderr,
        )
        return 2

    public_key, secret_key = ml_dsa_65.generate_keypair()
    signature = ml_dsa_65.sign(secret_key, DOMAIN_MESSAGE)
    if not ml_dsa_65.verify(public_key, DOMAIN_MESSAGE, signature):
        print("ERROR: local ML-DSA-65 verification failed", file=sys.stderr)
        return 2

    samples_us: list[float] = []
    for _ in range(max(0, args.benchmark_iterations)):
        started = time.perf_counter_ns()
        if not ml_dsa_65.verify(public_key, DOMAIN_MESSAGE, signature):
            print("ERROR: local ML-DSA-65 benchmark verification failed", file=sys.stderr)
            return 2
        samples_us.append((time.perf_counter_ns() - started) / 1000.0)

    positive_input = public_key + signature + DOMAIN_MESSAGE
    tampered_signature = bytearray(signature)
    tampered_signature[0] ^= 0x01
    negative_input = public_key + bytes(tampered_signature) + DOMAIN_MESSAGE
    short_input = b"This is invalid input"

    report: dict[str, object] = {
        "backend": "pqcrypto-0.4.0/ml_dsa_65",
        "draft": "EIP-8355",
        "message_len": len(DOMAIN_MESSAGE),
        "public_key_len": len(public_key),
        "signature_len": len(signature),
        "input_len": len(positive_input),
        "draft_formula_gas": 9000 + 6 * math.ceil(len(DOMAIN_MESSAGE) / 32),
        "message_sha256": sha256_hex(DOMAIN_MESSAGE),
        "eip8355_input_sha256": sha256_hex(positive_input),
    }
    if samples_us:
        ordered = sorted(samples_us)
        report["local_verify_us"] = {
            "iterations": len(ordered),
            "median": round(statistics.median(ordered), 3),
            "p95": round(ordered[max(0, math.ceil(len(ordered) * 0.95) - 1)], 3),
        }
    if args.local_only:
        report["checks"] = {"local_fips204_verify": True}
        print(json.dumps(report, indent=2, sort_keys=True))
        return 0

    try:
        assert precompile is not None
        positive_result = rpc_call(args.rpc_url, precompile, positive_input, 1)
        negative_result = rpc_call(args.rpc_url, precompile, negative_input, 2)
        short_result = rpc_call(args.rpc_url, precompile, short_input, 3)
    except (OSError, urllib.error.URLError, RuntimeError, json.JSONDecodeError) as exc:
        print(f"ERROR: RPC conformance probe failed: {exc}", file=sys.stderr)
        return 1

    checks = {
        "positive": positive_result == SUCCESS_WORD,
        "tampered_signature": negative_result == FAILURE_WORD,
        "short_input": short_result == FAILURE_WORD,
    }
    report["precompile"] = precompile
    report["checks"] = checks
    print(json.dumps(report, indent=2, sort_keys=True))
    return 0 if all(checks.values()) else 1


if __name__ == "__main__":
    raise SystemExit(main())
