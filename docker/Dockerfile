# ──────────────────────────────────────────────────────────────────────────────
# Stage 1 — builder
# Installs all Python dependencies into a virtual environment.
# The build tools (gcc, libpq-dev, etc.) stay in this stage and are never
# copied to the runtime image — keeps the final image lean and reduces the
# attack surface Trivy scans in Phase 6.
# ──────────────────────────────────────────────────────────────────────────────
FROM python:3.13-slim AS builder

# Build-time dependencies needed to compile psycopg and other C extensions
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libpq-dev \
    curl \
 && rm -rf /var/lib/apt/lists/*

# Create the virtual environment in a fixed, predictable path.
# Using /opt/venv so the runtime stage can copy it without worrying about
# the system Python's site-packages layout.
ENV VIRTUAL_ENV=/opt/venv
RUN python -m venv $VIRTUAL_ENV
ENV PATH="$VIRTUAL_ENV/bin:$PATH"

# Copy only requirements first so Docker layer caching skips reinstallation
# when only application code changes (the most common build scenario).
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip \
 && pip install --no-cache-dir -r requirements.txt

# ──────────────────────────────────────────────────────────────────────────────
# Stage 2 — runtime
# Copies the venv and app code, runs as a non-root user.
# ──────────────────────────────────────────────────────────────────────────────
FROM python:3.13-slim AS runtime

# Runtime system dependencies only — no compilers, no build headers
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq5 \
    curl \
    gettext \
 && rm -rf /var/lib/apt/lists/*

# Non-root user for running the application.
# UID/GID 1000 is conventional; pick a fixed value so K8s SecurityContext
# can pin to it with runAsUser/runAsGroup in Phase 4.
RUN groupadd --gid 1000 appgroup \
 && useradd --uid 1000 --gid 1000 --no-create-home --shell /bin/bash appuser

# Copy the virtual environment from the builder stage
COPY --from=builder /opt/venv /opt/venv
ENV VIRTUAL_ENV=/opt/venv
ENV PATH="$VIRTUAL_ENV/bin:$PATH"

# Application code
WORKDIR /app
COPY --chown=appuser:appgroup . .

# Static files directory — written to by collectstatic at startup
RUN mkdir -p /app/staticfiles /app/media \
 && chown -R appuser:appgroup /app/staticfiles /app/media

# Entrypoint handles migrations, collectstatic, then exec gunicorn
COPY --chmod=755 entrypoint.sh /entrypoint.sh

# Switch to non-root before defining the entrypoint
USER appuser

# Expose Gunicorn's port (Nginx container will proxy to this)
EXPOSE 8000

# Health check — Kubernetes/Docker Compose uses this to determine readiness.
# /health/ requires django-health-check in INSTALLED_APPS (see requirements.txt).
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8000/health/ || exit 1

ENTRYPOINT ["/entrypoint.sh"]
