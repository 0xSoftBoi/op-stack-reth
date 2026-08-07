# Suwappu ML-DSA-65 OP-Reth profile

This directory is the chain-side implementation and conformance surface for Suwappu's
post-quantum bridge authentication. It contains a pinned native OP-Reth delta plus independent
RPC probes.

## Consensus profile

Suwappu uses one ML-DSA parameter set for this devnet profile:

- FIPS 204 ML-DSA-65 (NIST security category 3)
- 1952-byte encoded public key
- 3309-byte encoded signature
- calldata: `public_key || signature || raw_message`
- return: exactly one 32-byte word; integer `1` is valid and `0` is invalid
- empty FIPS 204 context
- chain-local address: `0x0000000000000000000000000000000000008355`
- activation: Fjord and every later OP spec
- gas: `9000 + 6 * ceil(message_bytes / 32)`

Malformed keys/signatures and cryptographic failures return the 32-byte zero word. They do not
revert or halt execution. Insufficient gas is the only verifier-level halt.

The address and gas schedule are consensus rules for this Suwappu profile. They intentionally do
not use the draft EIP-8355 `0x12`/`0x13`/`0x14` range because those assignments remain
unsettled. If the final standard differs, Suwappu must migrate at an explicit hardfork rather
than silently changing a running chain.

ML-KEM-768 remains an off-chain Lattice Bridge confidentiality primitive and is not part of this
precompile input.

## Native OP-Reth delta

`pq/op-reth/optimism-eip8355-mldsa65.patch` applies to the maintained Optimism monorepo at:

```text
ethereum-optimism/optimism
67be0c76d80d7bb09e6e984a37e1950b5ca49465
```

The patch extends `rust/op-revm`, the precompile provider consumed by OP-Reth. It:

1. pins RustCrypto `ml-dsa = 0.1.1` with only its `alloc` feature;
2. adds the Suwappu ML-DSA-65 precompile and exact call/return semantics;
3. activates it in the Fjord precompile set so Granite and later specs inherit it;
4. tests valid, tampered, short-input, gas-rounding, and out-of-gas behavior; and
5. carries the resulting `rust/Cargo.lock` delta so builds can use `--locked`.

The `0.1.1` pin is deliberate: it is newer than the RustCrypto releases affected by the
2026 duplicate-hint signature-malleability advisory.

Because this is a consensus change, a stock OP-Reth node is not a compatible Suwappu verifier
once the chain reaches Fjord. Sequencers, replicas that validate blocks, archive nodes, and any
fault-proof execution environment must use an execution stack containing the same rule.

## Build and run

The custom image is built from the exact source commit above:

```bash
make pq-build
make pq-up-replica
# or:
make pq-up-sequencer
```

The compose override is `docker-compose.pq.yml`; it changes only the `op-reth` service and
leaves the rest of the deployment file intact.

To stop that stack:

```bash
make pq-down
```

## Independent ML-DSA-65 bridge probe

The bridge probe uses `pqcrypto==0.4.0`, independently of the Rust client verifier. It generates
a fresh ML-DSA-65 key/signature over a domain-separated cross-chain authorization message, verifies
it locally, and then sends valid, tampered-signature, and too-short cases through `eth_call`.

```bash
python3 -m pip install pqcrypto==0.4.0
make pq-check
```

For local cryptographic timing only:

```bash
make eip8355-benchmark
```

The reported draft-formula gas is a formula check, not a native gas benchmark.

## Draft-vector probe

`pr12048-mldsa44-vectors.json` is retained as provenance for the EIP-8355 draft call/return
contract. Those fixtures are ML-DSA-44, while Suwappu's native profile intentionally implements
only ML-DSA-65. Do not treat an ML-DSA-44 run as Suwappu chain conformance.

The generic probe remains available for a client that explicitly implements that parameter set:

```bash
make eip8355-check EIP8355_ADDRESS=<that-client-address>
```

## CI gate

`.github/workflows/pq-native.yml` reproduces the client delta without modifying upstream:

1. checks out the exact Optimism commit;
2. initializes its pinned `superchain-registry` submodule;
3. runs `git apply --check` and applies the local patch;
4. runs the filtered `op-revm` ML-DSA-65 tests;
5. fails if Cargo changes `rust/Cargo.lock`; and
6. runs `cargo check --locked -p op-reth --bin op-reth`.

That gate proves the patch still applies, the verifier behavior passes its native tests, dependency
resolution is locked, and the maintained OP-Reth binary type-checks with the consensus change.
A live L2 RPC probe still requires booting the resulting image with chain configuration.
