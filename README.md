# platform

Shared pieces of the homelab app platform. Design and decisions: `docs/app-platform.md` in the homelab docs repo.

| Path | What | Used by |
|---|---|---|
| `.github/workflows/docker-app.yml` | reusable build + promote pipeline | every app repo (caller below) |
| `deploy-sync/` | pull-based deploy script + systemd timer | `apps-staging` (4020), `apps-prod` (3020) |
| `runners/` | ephemeral org runners (copy of what runs on VM 4010) | `ci-runner-01` |

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
