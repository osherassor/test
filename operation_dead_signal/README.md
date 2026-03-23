# Operation Dead Signal

**Category:** OSINT / Web
**Difficulty:** Medium
**Flags:** 2
**Flag format:** `CF2026{...}`

---

## Story

MDF intelligence intercepted network traffic pointing to an exposed internal GitLab instance run by a low-ranking IRIAN operator. The instance appears to contain operational configuration repositories. Analysts believe sensitive credentials and internal identifiers were carelessly committed and never fully purged.

Your mission: infiltrate the GitLab instance, recover both flags, and document the access path.

---

## Prerequisites

| Tool | Version |
|------|---------|
| Docker | 24+ |
| Docker Compose | v2+ |

No other dependencies required.

---

## Installation

### 1. Clone / copy the challenge directory

```bash
cp -r operation_dead_signal/ /your/target/path/
cd operation_dead_signal/
```

### 2. Build the image

> This step runs GitLab internally and seeds all challenge data into the image.
> **It takes 8–12 minutes.** This only happens once.

```bash
docker build -t operation_dead_signal .
```

You should see output like:

```
[build] Waiting for GitLab to become healthy (~5 min)...
[build] GitLab healthy — seeding challenge data...
[seed] Creating users...
[seed] Creating public repo...
...
[seed] === SEED COMPLETE ===
[build] Stopping GitLab...
[build] Image ready.
```

### 3. Run the challenge

```bash
docker compose up -d
```

GitLab will be available at **http://localhost:3000** within ~2 minutes.

> No re-seeding happens at runtime — all data is already baked into the image.

### 4. Verify it's up

```bash
curl -s http://localhost:3000/-/health
# Expected: {"status":"ok"}
```

Or open **http://localhost:3000** in a browser.

---

## Teardown

```bash
# Stop the container
docker compose down

# Full reset (removes container, re-run brings it back clean)
docker compose up -d
```

> Since there are no volumes, every `docker compose up` starts from a clean state.

---

## Challenge Access

Participants connect to `http://<host-ip>:3000` with **no credentials provided**.

They must discover everything through enumeration.

---

## Flag Locations (Author Reference — DO NOT SHARE)

| Flag | Location | How to reach |
|------|----------|--------------|
| Flag 1 | Commit history of public repo `phobos-relay-config` | Unauthenticated GitLab API enumeration |
| Flag 2 | `public_email` field of user `sable_rin` | Authenticated API — requires creds found in Flag 1's commit |

**Credentials hidden in commit history:**
`dax_mercer` / `D@xM3rc3r!Wn59kFuV`

---

## Intended Solution Path

```
1. Discover GitLab on port 3000
2. GET /api/v4/projects?visibility=public        ← unauthenticated
3. GET /api/v4/projects/1/repository/commits     ← find 5 commits
4. GET /api/v4/projects/1/repository/commits/<hash>/diff  ← read each diff
5. Find commit 2: config/ops-credentials.cfg contains FLAG 1 + dax_mercer creds
6. POST /oauth/token  (login as dax_mercer)
7. GET /api/v4/users/:id  (enumerate users 1–10)
8. Find sable_rin (user 7): public_email contains FLAG 2
```

---

## Deployment Notes

- Port `3000` → GitLab web + API
- Port `2222` → GitLab SSH (not required for this challenge)
- Platform: `linux/amd64` — on Apple Silicon, runs via Rosetta (slower boot)
- For CTFd: push image to `registry.ctfd.io/learninglab/operation-dead-signal`
