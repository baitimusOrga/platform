# platform

Shared pieces of the homelab app platform. Design and decisions: `docs/app-platform.md` in the homelab docs repo.

| Path | What | Used by |
|---|---|---|
| `.github/workflows/docker-app.yml` | reusable build + promote pipeline | every app repo (caller below) |
| `deploy-sync/` | pull-based deploy script + systemd timer | `apps-staging` (4020), `apps-prod` (3020) |
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
