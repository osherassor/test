# CTFd Configuration — Operation Dead Signal

## Challenge Metadata

| Field | Value |
|-------|-------|
| **Name** | Operation Dead Signal |
| **Category** | OSINT |
| **Difficulty** | Medium |
| **Points** | 300 (Flag 1) + 200 (Flag 2) |
| **Flag 1** | `CF2026{g1t_h1st0ry_n3v3r_l13s_4nd_n3v3r_f0rg3ts}` |
| **Flag 2** | `CF2026{3xp0s3d_pr0f1l3_d4t4_1s_4ls0_s3ns1t1v3}` |
| **Connection** | http://\<host\>:3000 |

---

## CTFd Description

Paste this into the CTFd description field (HTML rendered):

```
**INTEL REPORT — PRIORITY ALPHA**<br><br>MDF signals intelligence has triangulated an exposed IRIAN version control server codenamed <strong>Erebus Ledger</strong>. The operator running it apparently confused "deleted" with "gone" — a distinction our analysts find professionally offensive.<br><br>Infiltrate the system, recover the classified deployment token buried in its history, then pivot deeper to extract the operator identifier hidden in the personnel registry. Git never forgets. Neither do we.
```

---

## Hints

### Hint 1 — Flag 1 path (unlock cost: 50 pts)
> Public repositories on GitLab expose their full commit history through the API — no authentication required. Every change ever made, including deletions, is part of that history.

### Hint 2 — Flag 1 specific (unlock cost: 100 pts)
> Look at the commit that came *just before* the one titled "remove credentials from version control". Somebody tried to close the barn door. Check what was inside first.

### Hint 3 — Flag 2 path (unlock cost: 75 pts)
> The credentials you found belong to a real account. Log in and explore what an authenticated user can see that an unauthenticated one cannot. GitLab exposes more than just repositories.

### Hint 4 — Flag 2 specific (unlock cost: 125 pts)
> The user list endpoint (`/api/v4/users`) doesn't tell the full story. Query individual user profiles — some fields are only populated on direct lookups.

---

## Flag Unlock Order

Flag 1 must be found before Flag 2 is reachable (Flag 2 requires credentials recovered from Flag 1's commit). Consider configuring CTFd prerequisites accordingly:

- **Flag 2** requires **Flag 1** to be solved first (`prerequisites: [flag1_challenge_id]`)
