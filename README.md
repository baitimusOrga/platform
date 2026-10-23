# platform

Shared pieces of the homelab app platform. Design and decisions: `docs/app-platform.md` in the homelab docs repo.

| Path | What | Used by |
|---|---|---|
| `.github/workflows/docker-app.yml` | reusable build + promote pipeline | every app repo (caller below) |
| `.github/workflows/env-sync.yml` | reusable: repo secrets/variables → age-encrypted `.env` in `deployments` | apps that keep their settings in GitHub |
| `deploy-sync/` | pull-based deploy script + systemd timer (decrypts `.env.age`) | `apps-staging` (4020), `apps-prod` (3020) |
| `runners/` | ephemeral org runners (copy of what runs on VM 4010) | `ci-runner-01` |
| `db-dump/` | nightly dumps (01:30) of every container labelled `backup.dump: mongo\|mysql\|postgres` into `/srv/apps/<app>/dumps/`, keeps 7 | app hosts |

## Using the pipeline in an app repo

```yaml
# .github/workflows/deploy.yml
name: deploy
on:
  push:
    branches: [main]
    tags: ['v*']
  workflow_dispatch:
    inputs:
      promote: { description: "existing tag to put on :prod (rollback)", required: false, default: "" }
jobs:
  app:
    uses: baitimusOrga/platform/.github/workflows/docker-app.yml@v1
    with:
      image: myapp
      promote: ${{ inputs.promote || '' }}
    secrets: inherit
```

The repo needs the secrets `REGISTRY_USER` and `REGISTRY_PASSWORD` (per repo: org secrets don't reach private repos on the free plan).

- push to `main` → `registry.srv.home.arpa/myapp:sha-<commit>` + `:staging` → `apps-staging` runs it within a minute
- `git tag v1.0.0 && git push --tags` → the same image becomes `:prod` + `:v1.0.0` → `apps-prod` runs it within a minute
- rollback: *Actions → deploy → Run workflow*, promote = `v0.9.0`

## Secrets from GitHub (env-sync)

Instead of editing `/srv/apps/<app>/.env` on each host by hand, an app can keep its settings as repo secrets and variables with an environment prefix:

```bash
gh secret set STAGING_JWT_SECRET --repo baitimusOrga/myapp          # value from stdin, never on screen
gh variable set PROD_APP_URL --repo baitimusOrga/myapp --body https://myapp.example.ch
```

and add a job to its `deploy.yml`:

```yaml
  env:
    uses: baitimusOrga/platform/.github/workflows/env-sync.yml@v1
    with:
      app: myapp                       # folder name in deployments
      environment: ${{ github.ref_type == 'tag' && 'prod' || 'staging' }}
    secrets: inherit
```

1. Every `STAGING_*` (or `PROD_*`) secret **and** variable becomes one line of the `.env`, prefix stripped, value in single quotes (values must not contain `'` or newlines).
2. The file is encrypted with [age](https://age-encryption.org) to the host's public key in `deployments/apps-<env>/.age-recipients` and committed as `apps-<env>/<app>/.env.age` (+ `.env.sha256`, a fingerprint so unchanged values don't produce a commit).
3. `deploy-sync` decrypts it with `/etc/deploy-sync/age.key` into `/srv/apps/<app>/.env` (mode 600). Compose recreates the containers whose environment changed. A file that doesn't decrypt keeps the last good `.env` and sends one ntfy message.

Needs the repo secret `DEPLOYMENTS_DEPLOY_KEY`: the private half of the **write** deploy key `env-sync` on `deployments`. Once an app has `.env.age`, its host `.env` is owned by GitHub: manual edits there are overwritten on the next change.

GitHub doesn't run a workflow when a secret changes. After `gh secret set`, run the app's deploy workflow by hand with `sync` = `staging` or `prod` (or push / tag).

Host rebuilt or key lost: `sh deploy-sync/install.sh` creates a new key and prints its public key; put it into `deployments/apps-<env>/.age-recipients` and run env-sync again for every app.

## Releasing a change to this repo

Callers pin `@v1`. After a compatible change: `git tag -f v1 && git push -f origin v1`. Breaking change → `v2`.

## Database dumps

Mark the database container in its compose file, nothing else to set up:

```yaml
  db:
    image: postgres:17
    labels:
      backup.dump: postgres      # or mongo / mysql
```

`db-dump` (timer 01:30) writes `/srv/apps/<app>/dumps/<service>-<date>.<ext>` and keeps the newest 7. The nightly PBS job (02:00) backs up the whole VM including these files. Credentials are read inside the container from its own env (`MONGO_INITDB_ROOT_*`, `MYSQL_USER`/`MYSQL_PASSWORD`/`MYSQL_DATABASE`, `POSTGRES_USER`).

## Release info in the app

On every run `deploy-sync` writes `/srv/apps/<app>/release.env` (via `deploy-release`) and passes it to compose as a second `--env-file`:

| Variable | Value | From |
|---|---|---|
| `APP_RELEASE` | `v1.0.1` (highest `v*` tag on the same image), otherwise the tag in use (`staging`, `prod`) | registry |
| `APP_REVISION` | short commit | image label `org.opencontainers.image.revision` |
| `APP_BUILD_TIME` | build time (UTC) | image label `org.opencontainers.image.created` (set by `docker-app.yml`) |

An app opts in by using them in its compose file, e.g. `APP_RELEASE: ${APP_RELEASE:-}` in `environment:`. Apps that don't reference them are unaffected.
