# Secrets and personal-information review (OP#85)

- **Ticket:** OP#85 — Review repository for secrets or other personal information
- **Repository:** `310networks/local-matrix-stack` (public; the old `Kookster310/...` URL redirects here)
- **Reviewed revision:** `main` at `d0df2499e088e39dd830ffe7d83a92ffc3bd1d58`
- **Scope:** every file ever committed, every object in the local Git object database,
  the full commit/diff stream, commit author/committer metadata, refs, and the GitHub
  repository metadata readable with the workflow token.
- **Outcome:** **No credential, token, API key, private key, generated secret, or non-public
  personal information is present in repository content or committed history.** The only personal
  information found is the commit-author identity, which is inherent to public Git history.
  Several latent practices could cause a future leak; they are documented below and are left for
  separate tickets.

This ticket is information gathering only. The only repository change is this report; no
application code, container configuration, schema, API contract, or test is changed.

## Method

1. Enumerated every path ever committed (`git log --all --pretty=format: --name-only | sort -u`).
2. Enumerated every object in the local object database
   (`git cat-file --batch-all-objects --batch-check`). At review time this was 14 blobs
   (including drafts of this report from earlier runs), 18 trees, and 8 commits (4 reachable
   from `main`, 4 unreachable drafts).
3. Scanned every blob and the full `git log --all -p` stream for:
   - private-key blocks (`-----BEGIN ... PRIVATE KEY-----`)
   - provider token prefixes (`ghp_`, `github_pat_`, `gho_`, `AKIA`/`ASIA`, `sk-`, `xox[bap]-`)
   - Matrix access tokens (`syt_`, `MDAx`), JWTs, and bearer headers
   - password/secret/token/key assignments, email addresses, phone numbers, and IP addresses
4. Calculated Shannon entropy for every 24+ character `[A-Za-z0-9+/=_-]` string in every blob and
   reviewed every high-entropy match manually.
5. Checked every commit for ignored-but-committed material: `.env`, `*.key`, `*.pem`, `*.p12`,
   `*.pfx`, `*.db`, `*.sqlite*`.
6. Checked branches, tags, stashes, Git notes, reflog, unreachable objects, and remote refs.
7. Queried the GitHub API for repository metadata, branches, tags, releases, forks, issues, pull
   requests, workflows, deploy keys, and hooks where the token permitted it.
8. Reproduced `setup.sh` in throwaway copies (`git archive HEAD`) with dummy values only, to see
   where generated secrets are written and how special characters are handled. No real secret was
   used anywhere in this review.

## Findings

| # | Finding | Severity | Status |
|---|---------|----------|--------|
| F1 | No credential, token, private key, or generated secret exists in any committed file or in any commit diff. `.env` has never been tracked. | — | **Pass** |
| F2 | Commit metadata exposes the public GitHub login `Kookster310`, a display name, and two `@310networks.com` work email addresses on all four commits. The exact values are visible in `git log` and through the GitHub API; they are not repeated here to avoid unnecessary reproduction. The repository is public. | Low / informational | Reported |
| F3 | `setup.sh` writes real secrets into **tracked** template files (`synapse/data/homeserver.yaml`, `livekit/livekit.yaml`) via `sed -i`. Those paths are not covered by `.gitignore`, so after setup `git status` shows them modified and a later `git add -A && git commit` would publish live secrets. | High (latent) | Reported, not fixed |
| F4 | `setup.sh` reuses `POSTGRES_PASSWORD` for the database password **and** for `registration_shared_secret`, `macaroon_secret_key`, and `form_secret`. One leaked database password therefore compromises all Synapse secret material. | Medium (latent) | Reported, not fixed |
| F5 | `setup.sh` uses `source .env` plus unescaped `sed` substitution. Shell syntax in a value is executed; `/` breaks `sed`; `&` in a replacement inserts the matched placeholder; `$` can silently expand or truncate. A failed run can leave placeholders behind. | Medium (latent) | Reported, not fixed |
| F6 | No automated secret scanning: no CI workflow, no pre-commit hook, no `gitleaks`/`trufflehog` configuration. Nothing prevents F3 from becoming a real leak. | Low (latent) | Reported, not fixed |
| F7 | `.gitignore` covers `.env` but not common variants such as `.env.local`, `.env.prod`, or `.env.bak`. | Low (latent) | Reported, not fixed |
| F8 | The Synapse signing-key identifier `a_iKyM` is hardcoded in `setup.sh`. It is a public key ID, not secret material, but it is identical for every deployment. | Informational | Reported, not fixed |

### Evidence for F3 and F5

Reproduction in a throwaway copy with dummy values (`git archive HEAD`):

```text
# normal run
$ bash setup.sh            # POSTGRES_PASSWORD=dummy-pg-pass LIVEKIT_SECRET=dummy-lk-secret
rc=0
synapse/data/homeserver.yaml:21:registration_shared_secret: "dummy-pg-pass"
synapse/data/homeserver.yaml:26:macaroon_secret_key: "dummy-pg-pass"
synapse/data/homeserver.yaml:27:form_secret: "dummy-pg-pass"
livekit/livekit.yaml:22:  matrix: dummy-lk-secret

# secret containing '/'
$ bash setup.sh            # POSTGRES_PASSWORD=abc/defghijklmnop
rc=1
sed: -e expression #1, char 37: unknown option to `s'
synapse/data/homeserver.yaml:21:registration_shared_secret: "REPLACE_WITH_GENERATED_SECRET"

# quoted '&' is inserted as the sed replacement's "whole match" token
$ bash setup.sh            # POSTGRES_PASSWORD='abc&defghijklmnop'
rc=0
synapse/data/homeserver.yaml:21:registration_shared_secret: "abcREPLACE_WITH_GENERATED_SECRETdefghijklmnop"

# unquoted '&' is shell syntax; setup aborts
$ bash setup.sh            # POSTGRES_PASSWORD=abc&defghijklmnop
rc=127
.env: line 3: defghijklmnop: command not found

# unquoted '$' is expanded by source; here the variable name becomes HOMEdefghijklmnop
$ bash setup.sh            # POSTGRES_PASSWORD=abc$HOMEdefghijklmnop
rc=0
synapse/data/homeserver.yaml:21:registration_shared_secret: "abc"

# shell command substitution in .env is executed by source (harmless marker used)
$ bash setup.sh            # POSTGRES_PASSWORD=$(touch /tmp/op85-cmdexec)
command substitution executed: yes
```

Both target files are tracked (`git ls-files -s` lists them), and
`git check-ignore synapse/data/homeserver.yaml livekit/livekit.yaml .env.local` matches nothing.

## Verified absent

- `.env` was never tracked. No `*.key`, `*.pem`, `*.p12`, `*.pfx`, `*.db`, or `*.sqlite*` file
  exists in any commit.
- No private-key blocks, provider token prefixes (`ghp_`, `github_pat_`, `AKIA`, `sk-`,
  `xox[bap]-`), Matrix access tokens (`syt_`, `MDAx`), JWTs, or genuine high-entropy secret-like
  strings in any blob. The only high-entropy matches were ordinary text and the dummy values used
  in this report.
- No secret-shaped values in `homeserver.yaml`, `livekit.yaml`, `docker-compose.yaml`,
  `log.config`, `README.md`, `.env.example`, `.gitignore`, or `setup.sh`; every secret slot is a
  placeholder (`REPLACE_WITH_GENERATED_SECRET`, `YOUR_MATRIX_DOMAIN`, `YOUR_PUBLIC_IP`,
  `YOUR_USERNAME`, `matrix.example.com`, `livekit.example.com`) or an empty value in
  `.env.example`.
- `docker-compose.yaml` contains only `LIVEKIT_KEY=matrix` (a public key identifier), no secret;
  real values come from `${VAR}` environment substitution.
- No tags, stashes, Git notes, extra local branches, or submodules. The only unreachable objects
  are earlier drafts of this report from previous runs; they contain only dummy reproduction values.
- The remote has a single branch, `main`; 0 forks, 0 pull requests, 0 releases, no GitHub Actions
  workflows, and no Git LFS objects.
- No real hostnames, public IP addresses, street addresses, or phone numbers in file content. Host
  references are `example.com`, `matrix.org`, `localhost`, `0.0.0.0`, loopback and RFC 1918 ranges.
  `192.168.1.100` in `.env.example` / `README.md` is a documented example, not a real host.

## Recommendations (separate tickets; out of scope here)

1. Render runtime configuration into gitignored paths (or at container start from environment
   variables) so `setup.sh` never writes secrets into tracked files, and make the script refuse to
   run when its output paths are tracked.
2. Generate independent values for `registration_shared_secret`, `macaroon_secret_key`, and
   `form_secret` instead of reusing `POSTGRES_PASSWORD`.
3. Stop using `source .env` and unescaped `sed`; parse `.env` safely and escape replacement values
   (or template with `envsubst`/Python) so `/`, `&`, `$`, and newlines are handled.
4. Add a secret scanner (gitleaks or trufflehog) as a pre-commit hook and CI job.
5. Extend `.gitignore` to `.env.*`/`*.env` with an exception for `.env.example`.
6. Decide whether the author email addresses in public history should be replaced with GitHub
   `noreply` addresses. That requires a history rewrite, force-push, and GitHub cache purge; it is
   not authorized by this ticket and gives limited benefit for a public account.

## Known limitations / not verified

- GitHub repository settings were only partially inspected. Repository hooks, deploy keys,
  collaborators, Actions secrets/variables, and secret-scanning/code-scanning alerts returned
  HTTP 403 for the workflow token.
- Repository wiki content and GitHub issue/PR discussion text were not reviewed.
- Only the local clone was available; commits removed from the remote before this clone (for
  example by a force-push) would not be visible.
- The live deployment, server `~/.ssh`/`.env` files, and any secrets stored outside the repository
  were not examined.
- This review cannot prove the absence of secrets in future commits; F3–F7 are the missing
  preventive controls.

## Operational note (not a repository leak)

The local clone's `.git/config` remote URL embeds an automation credential injected by the
workflow harness. It is local Git configuration, not repository content or history, and its value
is not reproduced here. Workspace copies containing it should not be shared or archived, and the
credential should be rotated if the workspace is exposed.
