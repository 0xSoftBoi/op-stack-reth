#!/usr/bin/env python3
"""Fail-closed JSON-RPC conformance probe for draft EIP-8355 vectors."""

from __future__ import annotations

import argparse
import json
import sys
import urllib.error
import urllib.request
from pathlib import Path


def normalize_address(value: str) -> str:
    if not value.startswith("0x"):
        raise ValueError("precompile address must be hex (for example 0x12)")
    number = int(value, 16)
    if number < 0 or number >= 2**160:
        raise ValueError("precompile address is outside the 160-bit address space")
    return f"0x{number:040x}"


def eth_call(rpc_url: str, address: str, data_hex: str, request_id: int) -> str:
    request_body = json.dumps(
        {
            "jsonrpc": "2.0",
            "id": request_id,
            "method": "eth_call",
            "params": [{"to": address, "data": "0x" + data_hex}, "latest"],
        }
    ).encode()
    request = urllib.request.Request(
        rpc_url,
        data=request_body,
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


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--rpc-url", required=True)
    parser.add_argument("--address", required=True, help="draft precompile address")
    parser.add_argument("--vectors", required=True, type=Path)
    args = parser.parse_args()

    try:
        address = normalize_address(args.address)
    except ValueError as exc:
        parser.error(str(exc))

    try:
        vectors = json.loads(args.vectors.read_text())
    except (OSError, json.JSONDecodeError) as exc:
        print(f"ERROR: cannot read vectors: {exc}", file=sys.stderr)
        return 2
    if not isinstance(vectors, list) or not vectors:
        print("ERROR: vector file must contain a non-empty JSON array", file=sys.stderr)
        return 2

    failures = 0
    for index, vector in enumerate(vectors, start=1):
        try:
            input_hex = vector["Input"].lower()
            expected = "0x" + vector["Expected"].lower()
            name = vector.get("Name", f"vector {index}")
            # Validate the fixture before involving a node.
            bytes.fromhex(input_hex)
            expected_bytes = bytes.fromhex(vector["Expected"])
            if len(expected_bytes) != 32:
                raise ValueError("Expected must be exactly 32 bytes")
            result = eth_call(args.rpc_url, address, input_hex, index)
            exact_word = result.startswith("0x") and len(result) == 66
            passed = exact_word and result == expected
        except (
            KeyError,
            ValueError,
            OSError,
            urllib.error.URLError,
            RuntimeError,
            json.JSONDecodeError,
        ) as exc:
            passed = False
            name = vector.get("Name", f"vector {index}") if isinstance(vector, dict) else f"vector {index}"
            result = f"error: {exc}"

        print(f"{'PASS' if passed else 'FAIL'}  {name}")
        if not passed:
            failures += 1
            print(f"      observed={result}")

    print(f"{len(vectors) - failures}/{len(vectors)} EIP-8355 vectors passed")
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
