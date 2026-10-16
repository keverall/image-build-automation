That explains the discrepancy. The AIB servers use Bitbucket through a remote named `gitstash`, while this working copy only has `github` and `gitlab` configured.

The important point is: both servers must push the **same local commit** to the **same Bitbucket repository and same branch**. Force-pushing different local `HEAD` commits will still produce different SHAs.

## On an AIB server, capture the authoritative Bitbucket URL

```powershell
git remote -v
git remote get-url gitstash
git branch -avv
git rev-parse HEAD
git ls-remote gitstash refs/heads/main
```

Also determine whether the Bitbucket branch is actually `main`, `master`, or another branch:

```powershell
git ls-remote --heads gitstash
```

## Configure this working copy with the same `gitstash` remote

Use the exact URL returned by the AIB server:

```powershell
git remote add gitstash <exact-bitbucket-url>
```

If a stale `gitstash` remote already exists:

```powershell
git remote set-url gitstash <exact-bitbucket-url>
```

Verify:

```powershell
git remote -v
git ls-remote gitstash refs/heads/main
```

## Make Bitbucket contain this exact commit

This working copy currently has:

```text
HEAD:       0a0e3289
github/main 0a0e3289
```

After verifying that `main` is the correct Bitbucket branch:

```powershell
git fetch gitstash --prune
git push gitstash HEAD:refs/heads/main --force-with-lease
```

Then verify the remote:

```powershell
git ls-remote gitstash refs/heads/main
```

It should report the full SHA beginning with:

```text
0a0e3289
```

## Synchronize another AIB server to that same Bitbucket commit

On the other AIB server:

```powershell
git status --short
git stash push -u -m "before synchronizing from gitstash"

git fetch gitstash --prune
git switch main
git reset --hard gitstash/main
```

Verify:

```powershell
git rev-parse HEAD
git rev-parse gitstash/main
git log -1 --oneline
```

All three should identify the same commit.

## Most likely explanation

One of these is occurring:

1. The two servers’ `gitstash` remotes point to different Bitbucket repositories.
2. One server pushed `main`, while the other pushed `master` or another branch.
3. Each server force-pushed its own different local `HEAD`.
4. One server had uncommitted or unpushed commits when it performed the push.
5. The remote-tracking refs were stale because `git fetch gitstash` was not run first.

The decisive comparison is:

```powershell
git remote get-url gitstash
git ls-remote gitstash --heads
git rev-parse HEAD
```

Run those on both AIB servers. The remote URL, branch ref, and full SHA must match.