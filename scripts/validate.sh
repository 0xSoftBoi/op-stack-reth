#!/usr/bin/env bash
# Static validation of the deployment: script syntax, YAML, JSON, and (if Docker is present)
# `docker compose config`. Runs without Docker for the syntax/parse checks.
set -uo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/.."
fail=0

echo "== shell script syntax (bash -n) =="
for s in scripts/*.sh; do
  if bash -n "$s"; then echo "  ok   $s"; else echo "  FAIL $s"; fail=1; fi
done

echo "== YAML parses =="
for y in docker-compose.yml prometheus.yml devnet/simple-devnet.yaml .github/workflows/*.yml; do
  [ -f "$y" ] || continue
  if python3 -c "import yaml,sys; yaml.safe_load(open(sys.argv[1]))" "$y" 2>/dev/null; then
    echo "  ok   $y"; else echo "  FAIL $y"; fail=1; fi
done

echo "== JSON parses =="
for j in safe/addresses.json; do
  [ -f "$j" ] || continue
  if python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$j" 2>/dev/null; then
    echo "  ok   $j"; else echo "  FAIL $j"; fail=1; fi
done
for t in templates/*.template; do
  [ -f "$t" ] || continue
  if python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$t" 2>/dev/null; then
    echo "  ok   $t (valid JSON)"; else echo "  warn $t (template placeholders — not strict JSON)"; fi
done

echo "== docker compose config =="
if command -v docker >/dev/null 2>&1; then
  if docker compose config -q 2>/dev/null; then echo "  ok   docker compose config"; else echo "  FAIL docker compose config"; fail=1; fi
else
  echo "  skip docker not installed (CI runs this on GitHub)"
fi

echo
if [ "$fail" -eq 0 ]; then echo "VALIDATION OK"; else echo "VALIDATION FAILED"; fi
exit $fail
