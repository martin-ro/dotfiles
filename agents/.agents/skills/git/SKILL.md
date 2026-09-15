---
name: git
description: "Commit, and optionally push, open a PR, and request review, for the current working-tree changes. Commits as the BeeCodeBot bot (via the gh-app wrapper) in repos opted in with `git config author.mode bot`, otherwise as the user with plain git/gh (safe default: repos that are not the user's never get bot attribution). Use when the user asks to commit, 'commit and push', 'push my changes', 'open a PR', 'ship this', or 'PR and request review'; or to reply to / address a reviewer's comments on a PR (posted as the bot in bot repos, never as the user); or to check a PR's CI / review status ('is it green?', 'did CI pass?', 'any changes requested?'); or to OPEN A GITHUB ISSUE ('open an issue', 'file a bug', 'create a tracking issue': created as the bot in bot repos, never silently as the user); or to FOLLOW UP on open PRs ('/git followup', 'merge the approved PRs', 'address the review feedback'): merges what's approved and green, reworks, resolves conflicts, fixes CI. NOT for general git questions or read-only git."
---

# git - commit / push / PR / review, as the bot or as you

Runs the git workflow to whatever level the user asked for, committing either as the **BeeCodeBot bot** or as **you**, decided per-repo. It never invents branches and never mislabels authorship.

## Step 1 - Resolve the author mode (always do this first)

```bash
mode="$(git config --get author.mode || echo me)"
```

- `bot` → commits are stamped as `beecodebot[bot]`; push and PR go through the `gh-app` wrapper (GitHub App token).
- anything else, **including unset → `me`** → plain `git`/`gh` as the user. This is the safe default: a repo that has not opted in (e.g. a client repo like `journey`) is NEVER committed as the bot.

Honor an explicit override in the request: "as me" forces `me`, "as bot" forces `bot`.

**Announce the mode before touching anything**, so a wrong mode is caught before a commit is written:
- bot: `Committing as beecodebot[bot] (bot mode).`
- me:  `Committing as <git config user.name> (your own identity).`

**The bot commit itself needs no wrapper** - the `-c` stamp in Step 3 is plain git, and the authorship is baked into the commit, so it shows as `beecodebot[bot]` on GitHub no matter who pushes. The `gh-app` wrapper is only needed to perform the *push / PR as the App*. So in `bot` mode, check what's available and **degrade gracefully - never hard-block a push over authorship, because authorship is already correct**:

- `gh-app` present **and working for THIS repo** (`gh-app token >/dev/null` succeeds, run *inside the repo*) → full bot flow: commit stamped as the bot, push/PR via `gh-app` (Steps 4–5, **bot** paths). The probe must be `gh-app token`, not `gh-app whoami`: `token` resolves the App installation for this repo's owner, so it also catches "App not installed on this repo's account". `whoami` only proves the key works and passes even where the App can't touch the repo.
- `gh-app` missing, or the probe fails (`no config at ~/.config/beebot/config`, or `the app is not installed on '<owner>'`) → **do not stop.** Still commit stamped as `beecodebot[bot]`, then push/PR with **plain `git`/`gh`** (Steps 4–5, **me** paths). The commit is bot-authored either way; only the push/PR *actor* differs. Announce it plainly, quoting the probe's reason:
  > gh-app can't act on this repo (<reason>): the commit is authored as **beecodebot[bot]** (correct on GitHub), but pushing/opening the PR happens **as you** (martin-ro). Fix: `gh-app setup`, or install the App on this account.

## Step 2 - Determine the level

From the invocation text (levels are cumulative):

| the user said… | level |
|---|---|
| commit | **commit** |
| commit + push / push / "push my changes" | **push** |
| open a PR / "pr" / "pull request" | **pr** (opened, no review requested) |
| PR + request review / "pr and review" / "ship for review" | **review** |
| "followup" / "follow up on the PRs" / "merge the approved PRs" | not a level: the **Followup sweep** below |
| "open an issue" / "file a bug" / "create a tracking issue" | not a level: **Opening an issue** below |

If it is unclear how far to go, ask.

## Step 3 - Commit (all levels)

- Stay on the CURRENT branch. Do **NOT** `git checkout -b` or create a branch unless the user explicitly asked for one - the branch/worktree already provides isolation.
- Stage what the user meant: default `git add -A`, or the specific paths they named.
- Write the message from the staged diff (`git diff --staged`): imperative subject line, a body explaining the *why*, **no emojis**, following the repo's `AGENTS.md`/`CLAUDE.md`/conventions.

**bot mode:**
```bash
git -c user.name="beecodebot[bot]" \
    -c user.email="298793856+beecodebot[bot]@users.noreply.github.com" \
    commit -m "<subject>" -m "<body>"
```

**me mode:**
```bash
git commit -m "<subject>" -m "<body>"
```

`-c` stamps only this one commit - the repo's default identity stays the human. (The bot identity is authoritative from `gh-app whoami` if ever in doubt.)

Stop here if the level is **commit**.

## Step 4 - Push (levels push / pr / review)

- **bot:** `gh-app push "HEAD:$(git branch --show-current)"` - the wrapper already targets `origin` as the tokenized remote and passes any extra args to git as **refspecs**, so pushing the current branch is a refspec, *not* `-u origin HEAD` (that makes git read `origin` as a refspec → "src refspec origin does not match any").
- **me:**  `git push -u origin HEAD`

If mode is `bot` but `gh-app` is unavailable (see Step 1), use the **me** path here - the commit stays bot-authored, only the push is as you.

Stop here if the level is **push**.

## Step 5 - Open the PR (levels pr / review)

Derive the PR title + body from the commits/diff, same style rules as the commit message.

- **bot, level `pr` (no review):** `gh-app gh -- pr create --title "<title>" --body "<body>"`
  (the raw `gh` path deliberately bypasses gh-app's auto-reviewer)
- **bot, level `review`:** `gh-app pr create --fill`  - or `gh-app pr create --title "<title>" --body "<body>" --reviewer martin-ro`. `gh-app pr create` auto-requests the configured reviewer `martin-ro`.
- **me, level `pr`:** `gh pr create --title "<title>" --body "<body>"`  (as you, no reviewer).
- **me, level `review`:** `gh pr create --title "<title>" --body "<body>"`, then ASK the user which GitHub username to request review from and add it: `gh pr edit <number> --add-reviewer <user>`. Never auto-add `martin-ro` or the bot in me mode.

If mode is `bot` but `gh-app` is unavailable (see Step 1), open the PR via the **me** path - it's opened by you, but the commits inside stay bot-authored. For `review`, since `martin-ro` (you) can't review your own PR, skip the auto-reviewer and just note the PR is up.

## Step 6 - Report

State the mode used, the commit SHA, and the PR URL (when one was opened). After a push or PR, also run the status check below and fold its result into the report.

## Replying to review comments (standalone action)

Use this whenever the user asks to **reply to**, **respond to**, or **address** a reviewer's comments on a PR. It is NOT a cumulative level - it is its own action, but it obeys the **same author mode**: in a `bot` repo the reply is posted as `beecodebot[bot]`, **never as you**. (Posting a review reply with plain `gh` is the exact bug this guards against - plain `gh` always authors as the user.)

Unlike a commit, a comment's author **is** the `gh` token - there is no `-c` stamp to fall back on. So in a `bot` repo, if `gh-app` is unavailable (missing/unconfigured), **do not silently post as you**: stop and tell the user the reply can only go out as them until `gh-app setup` is run, and let them choose.

Resolve the mode as in Step 1 and announce it (`Replying as beecodebot[bot] (bot mode).`). Then locate the PR and the comment(s):

```bash
mode="$(git config --get author.mode || echo me)"
repo="$(gh repo view --json nameWithOwner --jq .nameWithOwner)"
pr="$(gh pr view --json number --jq .number)"          # PR for the current branch
# list the open inline review comments to reply to (id, file, author, body):
gh api "/repos/$repo/pulls/$pr/comments" --jq '.[] | {id, path, line, user: .user.login, body}'
```

**Reply to a specific inline review comment** (threaded under that comment):
- **bot:** `gh-app gh -- api --method POST "/repos/$repo/pulls/$pr/comments/<comment_id>/replies" -f body="<reply>"`
- **me:**  `gh api --method POST "/repos/$repo/pulls/$pr/comments/<comment_id>/replies" -f body="<reply>"`

**Post a general (non-inline) comment on the PR:**
- **bot:** `gh-app gh -- pr comment "$pr" --body "<reply>"`
- **me:**  `gh pr comment "$pr" --body "<reply>"`

If the user also wants code changes for the feedback, make them and commit via Steps 3–4 **first**, then reply - so the fix and the reply come from the same identity. Reads used to gather context (listing comments, `gh pr view`) are fine as plain `gh`; only the write must go through `gh-app` in bot mode.

## Opening an issue (standalone action)

Use whenever the user asks to **open**, **file**, or **create** an issue ("open an issue for this", "file a bug", "report this as an issue", "create a tracking issue"). Like a review reply, an issue's author **is** the `gh` token: there is no `-c` stamp to fall back on. The same rule applies: in a `bot` repo where `gh-app` is unavailable, do not silently create the issue as the user; stop, explain, and let them choose.

Resolve the mode as in Step 1 and announce it (`Opening the issue as beecodebot[bot] (bot mode).` / `Opening the issue as you.`).

Before creating, guard against duplicates (a read, plain `gh`):

```bash
gh issue list --state open --search "<key words from the intended title>" --json number,title,url
```

If a likely duplicate shows up, stop and show it instead of filing a second one; offer to comment on the existing issue instead.

Write the issue from what the user described (or from the findings of the current conversation, e.g. a bug just diagnosed):

- **Title:** one specific line stating the problem or ask, not a vague label ("Login 500s when the session cookie is expired", not "Auth bug").
- **Body:** context, reproduction steps or the offending code path (`file:line`), expected vs actual behavior, and any known constraints or leads. If `.github/ISSUE_TEMPLATE/` exists, read the matching template and fill its sections instead of freeforming.
- Same style rules as commit messages: no emojis, no self-attribution.

**Label by default.** Run `gh label list` and pick the existing label(s) that fit the issue's nature (e.g. `bug` for a defect, `enhancement` for a feature ask, plus any obvious area label the repo uses). Never create a new label and never guess a name that isn't in the list; if nothing fits, file unlabeled and say so in the report. The user naming labels overrides your pick.

Assignees and milestones only when the user asked for them. "Assign it to me" means the user: `--assignee @me` in me mode, `--assignee <user's login>` in bot mode; never assign the bot.

- **bot:** `gh-app gh -- issue create --title "<title>" --body "<body>" [--label <label>] [--assignee <login>]`
- **me:**  `gh issue create --title "<title>" --body "<body>" [--label <label>] [--assignee @me]`

Report the issue URL and the labels applied (or that none fit). If it relates to the current branch's PR, cross-reference by number in the body ("Related: #<pr>"); use closing keywords ("Fixes #<n>") only in a PR that actually resolves the issue, never in the issue itself.

## Checking CI + review status (standalone, and auto after push/PR)

Runs **after** any push/pr/review level (fold the result into the Step 6 report), and standalone whenever the user asks "is it green?", "did CI pass?", "check CI", "did the review pass?", or "any changes requested?".

These are **reads** - use plain `gh` (as the user) in BOTH modes. Reads never need the bot token, so this works even where the BeeCodeBot App lacks Actions permission. Find the PR for the current branch first; if there's none, say so and stop:

```bash
pr="$(gh pr view --json number --jq .number 2>/dev/null)"
[ -z "$pr" ] && { echo "No PR open for this branch yet."; }
```

**CI / checks - poll until they finish** (bounded so it never hangs):

```bash
timeout 180 gh pr checks "$pr" --watch --interval 15
```
- `--watch` blocks until every check completes; the `timeout` caps the wait at ~3 min. If it trips, checks are still running - report a snapshot (`gh pr checks "$pr"`), note which are pending, and let the user re-ask.
- Poll like this by default after a push/PR, or on an explicit "wait for green". For a quick "status right now?", run `gh pr checks "$pr"` once, no `--watch`.
- Exit status: `0` = all passed · `8` = some still pending · non-zero otherwise = at least one failed. Read the output and name the **failing** checks (with their link) so the user can open the log.

**Review decision:**

```bash
gh pr view "$pr" --json reviewDecision,latestReviews \
  --jq '"decision=\(.reviewDecision)  " + ([.latestReviews[] | "\(.author.login):\(.state)"] | join(", "))'
```
- `APPROVED` · `CHANGES_REQUESTED` · `REVIEW_REQUIRED`/empty (still pending). Name who approved or requested changes.

**Report one line**, e.g. `CI: 3/4 passed, 1 failed (build) - <link>; review: CHANGES_REQUESTED by martin-ro`. If CI failed or changes were requested, offer the next step: fix + recommit (Steps 3–4), or address the comments via the reply flow above.

## Followup sweep (standalone action): merge what's approved, rework the rest

Use when the user says `/git followup`, "follow up on the PRs", "merge the approved PRs", "address the review feedback", or "fix the conflicted PRs". `followup` alone sweeps every open PR in the repo; `followup 11 16` only the named ones. It never merges anything a human has not approved, never approves or reviews a PR itself, and never force-pushes.

It obeys the **same author mode** (Step 1, announce it). In `bot` mode every write (merge, push, comment reply, review re-request) goes through `gh-app`. Merges and replies act as whoever owns the token, with no `-c` stamp to fall back on: if the `gh-app token` probe fails, do not silently perform them as the user; state the problem once and ask.

### Inventory and classify (reads, plain `gh`)

```bash
repo="$(gh repo view --json nameWithOwner --jq .nameWithOwner)"
method="$(gh repo view --json viewerDefaultMergeMethod --jq .viewerDefaultMergeMethod)"  # MERGE | SQUASH | REBASE
gh pr list --state open \
  --json number,title,headRefName,baseRefName,author,isDraft,reviewDecision,mergeable,url
```

Default scope: open PRs authored by `beecodebot[bot]` or the user; leave other people's PRs alone unless explicitly named. Skip drafts (report them). Check CI with `gh pr checks <n>` where it matters, then classify:

| reviewDecision | mergeable | checks | action |
|---|---|---|---|
| `APPROVED` | `MERGEABLE` | passing or none | **merge** |
| `APPROVED` | `CONFLICTING` | any | **resolve conflicts**, then re-check the approval |
| `CHANGES_REQUESTED` | any | any | **rework** (resolve conflicts first if `CONFLICTING`) |
| pending / `REVIEW_REQUIRED` | `MERGEABLE` | passing | **wait**: report only |
| any | any | failing | **fix CI** before anything else on that PR |

**Announce the full classification table before acting.** Work merges first (oldest number first), then conflict resolutions, then reworks. Merging moves the base branch, so after each merge re-fetch `mergeable` for the remaining PRs (GitHub recomputes it asynchronously; poll briefly on `UNKNOWN`); a PR that just turned `CONFLICTING` joins the resolve queue.

### Merge (APPROVED, green, mergeable)

Use the repo's default method from the inventory (`--merge` / `--squash` / `--rebase`) unless the user asked for a specific one.

- **bot:** `gh-app gh -- pr merge <n> --merge`
- **me:**  `gh pr merge <n> --merge`

After a successful merge, delete the **remote** branch (skip if the user said to keep branches). Never delete local branches or worktrees; treeupdown worktrees may still sit on them.

- **bot:** `gh-app gh -- api -X DELETE "/repos/$repo/git/refs/heads/<headRefName>"`
- **me:**  `gh api -X DELETE "/repos/$repo/git/refs/heads/<headRefName>"`

### Rework (CHANGES_REQUESTED)

1. Gather the feedback: review bodies via `gh pr view <n> --json reviews`, inline comments as in the reply flow above.
2. Get the branch without disturbing anything: if `git worktree list` already has it checked out, work there; otherwise `git fetch origin <branch>` and `git worktree add` a temporary worktree, removed when the PR is done. Never switch branches in a dirty checkout.
3. Implement the requested changes and run the repo's tests/formatters per its conventions. If a request is ambiguous or seems wrong, implement what is clear and ask about the rest by replying on that comment; flag it in the report.
4. Commit and push per Steps 3–4 (bot stamp + `gh-app push "HEAD:<branch>"` in bot mode). If the branch is behind its base, merge the base in (next section); never rebase.
5. Reply to each addressed inline comment via the reply flow above, stating what changed.
6. Re-request review from whoever requested the changes:
   - **bot:** `gh-app gh -- api -X POST "/repos/$repo/pulls/<n>/requested_reviewers" -f "reviewers[]=<login>"`
   - **me:** ask the user whom to request, as in Step 5.

Do **not** merge after a rework, even if an old approval still shows: the human asked for changes and gets to look again.

### Resolve merge conflicts (mergeable == CONFLICTING)

Never rebase, never force-push. In the PR branch's worktree:

```bash
git fetch origin
git merge origin/<baseRefName>
# resolve conflicts, run the tests, then commit the merge (Step 3 stamp) and push (Step 4)
```

Preserve both sides' intent; when a conflict is semantic and the right resolution is unclear, keep the base branch's current behavior and say so in a PR comment. If the PR was `APPROVED` before, re-check `reviewDecision` after pushing: if the resolution dismissed the approval, re-request review instead of merging.

### Fix failing CI

`gh pr checks <n>` names the failing check; read its log (`gh run view <run_id> --log-failed`). A real code failure goes through the rework flow (steps 2–4). Flaky infrastructure gets reported for the user to decide; do not burn the sweep on rerun loops.

### Report

One table: PR, action taken, result. E.g. `#19 merged (a1b2c3d), remote branch deleted` / `#16 reworked, replied to 3 comments, review re-requested` / `#11 conflicts resolved, approval dismissed, review re-requested` / `#13 blocked: feedback ambiguous, question posted`. End with what is now waiting on the user (re-reviews, open questions). Never close a PR.
