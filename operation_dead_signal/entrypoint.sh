#!/bin/bash

SEED_DONE_FILE="/var/opt/gitlab/.seed_done"

# Run seeding in the background — waits for GitLab to be healthy first
if [ ! -f "$SEED_DONE_FILE" ]; then
  (
    echo "[*] Seeder waiting for GitLab to become healthy..."
    until curl -sf http://localhost:3000/-/health > /dev/null 2>&1; do
      sleep 10
    done
    echo "[*] GitLab is up — seeding challenge data..."
    /assets/seed_repo.sh && touch "$SEED_DONE_FILE"
    echo "[*] Seed complete."
  ) &
else
  echo "[*] Already seeded, skipping."
fi

# Run GitLab as PID 1 — this keeps the container alive with proper signal handling
exec /assets/wrapper
