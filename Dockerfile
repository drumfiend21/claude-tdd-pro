# claude-tdd-pro — container image for CI gates and devcontainer parity.
# Per docs/SCALE_TARGET.md Tier 3: single deployable artifact.

FROM debian:bookworm-slim

LABEL org.opencontainers.image.title="claude-tdd-pro"
LABEL org.opencontainers.image.description="Rubric runner + drift gates + fitness functions for AI-assisted code review."
LABEL org.opencontainers.image.source="https://github.com/drumfiend21/claude-tdd-pro"
LABEL org.opencontainers.image.licenses="Apache-2.0"
LABEL org.opencontainers.image.version="0.4.0"

# Toolchain: bash, node, ruby, git per preflight in scripts/install.sh.
RUN apt-get update && apt-get install -y --no-install-recommends \
      bash \
      ca-certificates \
      curl \
      git \
      nodejs \
      npm \
      ruby \
      && rm -rf /var/lib/apt/lists/*

# Plugin layout — mounted or COPY'd at build/runtime.
WORKDIR /opt/claude-tdd-pro
ENV CLAUDE_PLUGIN_ROOT=/opt/claude-tdd-pro

# Copy plugin source. (For published images, COPY all needed paths.
# For sidecar use, mount the host directory over /opt/claude-tdd-pro.)
COPY . /opt/claude-tdd-pro

# Smoke verify the runner works.
RUN bash /opt/claude-tdd-pro/evals/runner.sh --filter cl414-Q-1 || true

# Default: run the full suite. Override with bash for interactive use.
CMD ["bash", "/opt/claude-tdd-pro/evals/runner.sh"]
