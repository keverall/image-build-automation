# Git Process — how we avoid rebase hell

> **Audience:** keverall (prod VDI, test server, this workspace).
> **Problem this solves:** `git pull` on the test server used to trigger long manual
> rebases / broken history when syncing Bitbucket/Stash ↔ GitHub. This doc makes
> pulls safe and gives a one-command recovery.

---

## TL;DR — the 4 golden rules

1. **Never commit on the test server.** It is a pure test checkout. Commit only on
   prod VDI (github). If you must hack there, throw it away — don't push it.
2. **Pulls never rebase.** Every checkout has `pull.ff only`, so `git pull` either
   fast-forwards or errors — it never starts a manual rebase.
3. **github is the source of truth.** Mirror to `gitstash` (Bitbucket) after each
   feature is finished.
4. **Divergence = one `reset --hard`, not a rebase.** When a pull errors, run the
   one-liner below. No manual conflict resolution.

---

## Remotes

| Name      | URL                                                        | Used by            |
|-----------|------------------------------------------------------------|--------------------|
| `github`  | `https://github.com/keverall/image-build-automation.git`   | prod VDI (source of truth) |
| `gitlab`  | `git@gitlab.com:keverall/image-build-automation.git`        | mirror / backup    |
| `gitstash`| internal Bitbucket/Stash (port 443, port 80 blocked)      | test server pulls from here |

The test server has no internet (port 80 blocked) — git was remapped to port 443
to reach `gitstash`. That's a network thing; it does not affect this process.

---

## One-time machine setup (prod VDI, test server, this workspace)

Run **once per checkout**:

```bash
git config pull.ff only
```

This makes `git pull <branch>` fail cleanly instead of rebasing when histories
diverge. Without it you get the long manual rebases.

(Optional, to apply everywhere on a machine: `git config --global pull.ff only`.)

---

## Daily work — on prod VDI (github)

```bash
git checkout feature/srvrid-parameter-rename      # or whatever branch
# ... edit files ...
git add -A
git commit -m "feat: short description"
git push github HEAD                               # normal push (fast-forward)
```

**If you rewrote history** (squashed / amended / rebase -i) the push is rejected.
Force-push *safely* (refuses if someone else moved the branch):

```bash
git push github --force-with-lease feature/srvrid-parameter-rename
```

> ⚠️ A force-push rewrites the branch. The test server must do the one-time
> recovery below afterwards. That is expected and cheap — it is NOT a rebase.

---

## Sync to the test server (mirror github → gitstash)

After you finish a feature (or any time you want the test server updated), push the
branch to Stash. Use `--force-with-lease` because Stash may hold older history:

```bash
git push gitstash feature/srvrid-parameter-rename --force-with-lease
```

To force-align **every** branch (deletes Stash branches that don't exist locally):

```bash
git push gitstash --mirror
```

Only use `--mirror` if you really want Stash to be an exact copy of your local refs.

---

## One-time recovery on the test server (after a sync / divergence)

When `git pull` errors with "diverging" / "non-fast-forward", do NOT rebase.
Discard the local divergence and re-align to the remote in one command:

```bash
git fetch
git reset --hard origin/feature/srvrid-parameter-rename
```

Replace the branch name with whatever you pulled. This is instant and never
requires manual conflict resolution.

> If you have **valuable unpushed commits** on the test server, use
> `git rebase origin/<branch>` instead — but the goal is to never be in that
> situation (see golden rule #1).

---

## `.md` / `.ps1` showing as modified for no reason?

That was Windows `core.autocrlf` flipping LF↔CRLF. Fixed repo-wide by
`.gitattributes` (all text normalised to LF on checkout). If files still look
modified after a sync, re-checkout cleanly:

```bash
git reset --hard        # re-checks-out everything as LF per .gitattributes
```

Do **not** commit those "changes" — they're line-ending noise, not real edits.

---

## Troubleshooting

| Symptom                                                  | Fix                                                        |
|----------------------------------------------------------|------------------------------------------------------------|
| `git pull` says "diverging" / "non-fast-forward"         | `git fetch && git reset --hard origin/<branch>`            |
| Force-push rejected "stale info"                         | `git fetch github` then retry the force-push               |
| Every `.md`/`.ps1` shows modified after a pull           | `git reset --hard` (line-ending normalisation)             |
| Test server history looks wrong / old                    | Re-mirror: `git push gitstash <branch> --force-with-lease`|
| `git pull` opens an editor / creates a merge commit      | `git config pull.ff only` was not set — set it and re-pull|

---

## Quick reference card

> Run the **prod VDI** block there; run the **test server** block there. The two
> remotes are: prod VDI has `github` + `gitstash`; the test server has `gitstash` only.

```bash
# ── ON PROD VDI (remotes: github + gitstash) ─────────────────────────────────
git config pull.ff only                              # one-time setup
git commit -am "msg" && git push github HEAD        # daily work (push to github)
git push gitstash feature/srvrid-parameter-rename --force-with-lease   # sync test server

# ── ON TEST SERVER (remote: gitstash only) ───────────────────────────────────
git config pull.ff only                              # one-time setup
git fetch && git reset --hard origin/feature/srvrid-parameter-rename   # when pull errors
```
