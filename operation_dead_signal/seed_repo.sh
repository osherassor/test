#!/bin/bash
# Full challenge seed script — reproduces all state on cold boot.
# Called by entrypoint.sh after GitLab is healthy.
set -e

GITLAB_URL="http://localhost:3000"
ADMIN_USER="root"
ADMIN_PASS="Ph0b0s!Relay#xZ9qW2"
FLAG1="${BUILD_FLAG1:-CF2026{g1t_h1st0ry_n3v3r_l13s_4nd_n3v3r_f0rg3ts}}"
FLAG2="${BUILD_FLAG2:-CF2026{3xp0s3d_pr0f1l3_d4t4_1s_4ls0_s3ns1t1v3}}"

log() { echo "[seed] $*"; }

# ── Wait for API to be fully ready (not just nginx health) ───────────────────
log "Waiting for GitLab API to be fully ready..."
until curl -sf "${GITLAB_URL}/api/v4/version" > /dev/null 2>&1; do
  sleep 10
done
log "API is ready."

# ── Get admin token ──────────────────────────────────────────────────────────
log "Obtaining admin API token..."
TOKEN=""
until [ -n "$TOKEN" ]; do
  TOKEN=$(curl -sf --request POST "${GITLAB_URL}/oauth/token" \
    --data "grant_type=password&username=${ADMIN_USER}&password=${ADMIN_PASS}" \
    | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('access_token',''))" 2>/dev/null || true)
  [ -z "$TOKEN" ] && sleep 5
done

api_post() {
  curl -sf --request POST "${GITLAB_URL}${1}" \
    --header "Authorization: Bearer ${TOKEN}" \
    "${@:2}"
}

api_commit() {
  local result=""
  until echo "$result" | python3 -c "import sys,json; json.load(sys.stdin)" > /dev/null 2>&1; do
    result=$(curl -sf --request POST "${GITLAB_URL}/api/v4/projects/${PUBLIC_PROJECT_ID}/repository/commits" \
      --header "Authorization: Bearer ${TOKEN}" \
      --header "Content-Type: application/json" \
      --data "$1" 2>/dev/null || true)
    [ -z "$result" ] && sleep 3
  done
  echo "$result" | python3 -c "import sys,json; d=json.load(sys.stdin); print('  commit:', d['id'][:12], '|', d['title'])"
}

# ── Create 8 users ───────────────────────────────────────────────────────────
log "Creating users..."
declare -a USERS=(
  "nova_chen|NovaChen|nova.chen@mdf.local|N0v@Ch3n!#Kx92mPqZ"
  "zara_voss|ZaraVoss|zara.voss@mdf.local|Z@r4V0ss\$Lp37nQwR"
  "rex_kaito|RexKaito|rex.kaito@mdf.local|R3xK@1t0!Ym84vBjX"
  "lyra_oban|LyraOban|lyra.oban@mdf.local|Lyr@0b@n#Tz61cDsE"
  "dax_mercer|DaxMercer|dax.mercer@mdf.local|D@xM3rc3r!Wn59kFuV"
  "sable_rin|SableRin|sable.rin@mdf.local|S@bl3R1n\$Hq28xGpA"
  "orion_tark|OrionTark|orion.tark@mdf.local|0r10nT@rk!Jd75yMcN"
  "vex_halo|VexHalo|vex.halo@mdf.local|V3xH@l0#Cb46wSiU"
)

for entry in "${USERS[@]}"; do
  IFS='|' read -r username fullname email password <<< "$entry"
  api_post "/api/v4/users" \
    --data-urlencode "name=${fullname}" \
    --data-urlencode "username=${username}" \
    --data-urlencode "email=${email}" \
    --data-urlencode "password=${password}" \
    --data "skip_confirmation=true" > /dev/null
  log "  created: ${username}"
done

# ── Create public repo ───────────────────────────────────────────────────────
log "Creating public repo..."
PUBLIC_PROJECT_ID=$(api_post "/api/v4/projects" \
  --data "name=phobos-relay-config&visibility=public&initialize_with_readme=false&description=MDF+Phobos+Relay+Station+—+Operations+Configuration" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")
log "  public project ID: ${PUBLIC_PROJECT_ID}"

# Commit 1 — scaffold
log "Commit 1: initial scaffold..."
api_commit '{
  "branch": "main",
  "commit_message": "chore: initial repository scaffold",
  "actions": [
    {"action":"create","file_path":"README.md","content":"# Phobos Relay Config\n\nOperational configuration for MDF Phobos Relay Station.\nClassification: UNCLASSIFIED//FOUO\n"},
    {"action":"create","file_path":".gitignore","content":"*.log\n*.tmp\n.env\nsecrets/\n"},
    {"action":"create","file_path":"config/network.yml","content":"gateway: 10.88.0.1\ndns_primary: 10.88.0.53\ndns_secondary: 10.88.0.54\nvlan_id: 420\n"}
  ]
}'

# Commit 2 — FLAG1 + dax_mercer creds planted
log "Commit 2: planting flag + credentials..."
curl -sf --request POST "${GITLAB_URL}/api/v4/projects/${PUBLIC_PROJECT_ID}/repository/commits" \
  --header "Authorization: Bearer ${TOKEN}" \
  --header "Content-Type: application/json" \
  --data "$(python3 -c "
import json
flag1 = '${FLAG1}'
payload = {
  'branch': 'main',
  'commit_message': 'feat: add ops service account for automated relay sync',
  'actions': [{
    'action': 'create',
    'file_path': 'config/ops-credentials.cfg',
    'content': (
      '# MDF Phobos Relay — Ops Service Account\n'
      '# Created: 2026-01-09T02:41:17Z | Author: SIGINT-7\n'
      '# WARNING: Rotate credentials after initial deployment\n\n'
      '[service_account]\n'
      'username = dax_mercer\n'
      'password = D@xM3rc3r!Wn59kFuV\n'
      'role     = ops-relay-sync\n\n'
      '[deployment]\n'
      'api_token = ' + flag1 + '\n'
      'target    = phobos-relay-03.mdf.local\n'
      'region    = mars-north\n'
    )
  }]
}
print(json.dumps(payload))
")" | python3 -c "import sys,json; d=json.load(sys.stdin); print('  commit:', d['id'][:12], '|', d['title'])"

# Commit 3 — remove creds
log "Commit 3: removing credentials..."
api_commit '{
  "branch": "main",
  "commit_message": "fix: remove credentials from version control — security finding #MDF-4421",
  "actions": [{"action":"delete","file_path":"config/ops-credentials.cfg"}]
}'

# Commit 4 — CI noise
log "Commit 4: CI pipeline..."
api_commit '{
  "branch": "main",
  "commit_message": "ci: add automated relay sync pipeline",
  "actions": [
    {"action":"create","file_path":".gitlab-ci.yml","content":"stages:\n  - sync\n\nrelay-sync:\n  stage: sync\n  script:\n    - ./scripts/sync.sh\n  only:\n    - main\n"},
    {"action":"create","file_path":"scripts/sync.sh","content":"#!/bin/bash\necho \"Syncing Phobos relay configuration...\"\n"}
  ]
}'

# Commit 5 — more noise
log "Commit 5: network update..."
api_commit '{
  "branch": "main",
  "commit_message": "chore: update network topology Q1-2026",
  "actions": [
    {"action":"update","file_path":"config/network.yml","content":"gateway: 10.88.0.1\ndns_primary: 10.88.0.53\ndns_secondary: 10.88.0.54\nvlan_id: 421\nbgp_peer: 10.88.254.1\n"}
  ]
}'

# ── Create private repo and add all users ────────────────────────────────────
log "Creating private repo..."
PRIVATE_PROJECT_ID=$(api_post "/api/v4/projects" \
  --data "name=mdf-ops-internal&visibility=private&initialize_with_readme=true&description=MDF+Internal+Operations+—+Restricted" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")
log "  private project ID: ${PRIVATE_PROJECT_ID}"

log "Adding all users as members (Reporter = read-only)..."
for GUSER_ID in 2 3 4 5 6 7 8 9; do
  api_post "/api/v4/projects/${PRIVATE_PROJECT_ID}/members" \
    --data "user_id=${GUSER_ID}&access_level=20" > /dev/null
  log "  added user ID: ${GUSER_ID}"
done

# ── Set FLAG2 on sable_rin via rails runner (bypasses email format validation)
log "Setting FLAG2 on sable_rin via rails runner..."
gitlab-rails runner "
u = User.find_by(username: 'sable_rin')
u.update_column(:public_email, '${FLAG2}@mdf.local')
u.update_column(:note, 'op-token: ${FLAG2}')
puts '[seed] sable_rin public_email: ' + u.reload.public_email.to_s
"

log "======================================"
log "Challenge seeded successfully."
log "  Flag 1 : commit 2 of phobos-relay-config"
log "  Flag 2 : sable_rin public_email + bio"
log "  Player creds: dax_mercer / D@xM3rc3r!Wn59kFuV"
log "======================================"
