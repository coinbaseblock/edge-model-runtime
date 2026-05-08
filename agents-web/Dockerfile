# =============================================================================
# agents-web — terminal-in-browser for OpenCode and Claude Code
# =============================================================================
# Provides http://localhost:7681 → bash menu → pick OpenCode or Claude Code,
# both pre-installed inside the image. Persistent login state lives on the
# host under ${AI_DATA_ROOT}/agents-web/, so claude login survives rebuilds.
# =============================================================================

FROM node:20-slim

ARG TARGETARCH

ENV DEBIAN_FRONTEND=noninteractive \
    HOME=/root \
    PATH=/root/.opencode/bin:/usr/local/bin:/usr/bin:/bin

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      bash ca-certificates curl git python3 python3-pip jq tini unzip \
 && rm -rf /var/lib/apt/lists/*

# --- ttyd (terminal-in-browser) ---------------------------------------------
# Pinned release. https://github.com/tsl0922/ttyd/releases
ARG TTYD_VERSION=1.7.7
RUN set -eux; \
    case "${TARGETARCH:-amd64}" in \
      amd64) TTYD_ARCH=x86_64 ;; \
      arm64) TTYD_ARCH=aarch64 ;; \
      *) echo "unsupported arch: ${TARGETARCH}"; exit 1 ;; \
    esac; \
    curl -fsSL "https://github.com/tsl0922/ttyd/releases/download/${TTYD_VERSION}/ttyd.${TTYD_ARCH}" \
      -o /usr/local/bin/ttyd; \
    chmod 0755 /usr/local/bin/ttyd; \
    ttyd --version

# --- Claude Code CLI --------------------------------------------------------
RUN npm install -g --no-fund --no-audit @anthropic-ai/claude-code \
 && claude --version

# --- OpenCode CLI -----------------------------------------------------------
# Official one-line installer drops the binary into ~/.opencode/bin.
RUN curl -fsSL https://opencode.ai/install | bash \
 && ln -sf /root/.opencode/bin/opencode /usr/local/bin/opencode \
 && opencode --version || true

# --- Launcher + entrypoint --------------------------------------------------
COPY launcher.sh /usr/local/bin/edge-agent-menu
COPY entrypoint.sh /usr/local/bin/edge-agent-entrypoint
RUN chmod 0755 /usr/local/bin/edge-agent-menu /usr/local/bin/edge-agent-entrypoint

WORKDIR /workspace

EXPOSE 7681

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/edge-agent-entrypoint"]
