FROM myoung34/github-runner:2.338.0-ubuntu-noble

# pnpm preinstalled: pnpm/action-setup costs 6-8 s per frontend job. pnpm switches itself to the
# version a repo pins in packageManager and keeps it in the pnpm volume (compose.yml).
ARG PNPM_VERSION=12.11.2
RUN mkdir /opt/pnpm \
 && curl -fsSL https://github.com/pnpm/pnpm/releases/download/v${PNPM_VERSION}/pnpm-linux-x64.tar.gz | tar xz -C /opt/pnpm \
 && ln -s /opt/pnpm/pnpm /usr/local/bin/pnpm \
 && pnpm config set --global store-dir /root/.local/share/pnpm/store
