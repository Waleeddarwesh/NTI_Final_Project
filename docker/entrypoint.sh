#!/bin/bash
# entrypoint.sh
# Runs inside the application container on every startup.
# Handles pre-flight checks, migrations, static collection, then hands off
# to Gunicorn. Uses exec at the end so Gunicorn receives signals (SIGTERM,
# SIGINT) directly from Docker/Kubernetes rather than through a shell wrapper
# that might swallow them.

set -euo pipefail

# ── Configuration ─────────────────────────────────────────────────────────────
DJANGO_SETTINGS_MODULE="${DJANGO_SETTINGS_MODULE:-config.settings.production}"
GUNICORN_WORKERS="${GUNICORN_WORKERS:-}"       # empty = auto-sized below
GUNICORN_THREADS="${GUNICORN_THREADS:-2}"
GUNICORN_TIMEOUT="${GUNICORN_TIMEOUT:-120}"
GUNICORN_BIND="${GUNICORN_BIND:-0.0.0.0:8000}"
WSGI_APP="${WSGI_APP:-config.wsgi:application}"

log() { echo "[entrypoint] $(date -u +%FT%TZ) $*"; }

# ── Wait for PostgreSQL ───────────────────────────────────────────────────────
# Retries for up to 60 seconds before giving up. Without this, Django's
# migrate command fails immediately when the container starts before Postgres
# is ready (common in docker-compose up when all services start in parallel).
log "Waiting for PostgreSQL..."
DB_HOST="${DB_HOST:-postgres}"
DB_PORT="${DB_PORT:-5432}"
RETRIES=30
until python -c "
import socket, sys
try:
    s = socket.create_connection(('${DB_HOST}', ${DB_PORT}), timeout=2)
    s.close()
    sys.exit(0)
except Exception:
    sys.exit(1)
" 2>/dev/null; do
    RETRIES=$((RETRIES - 1))
    if [ "$RETRIES" -le 0 ]; then
        log "ERROR: PostgreSQL at ${DB_HOST}:${DB_PORT} did not become reachable in 60s"
        exit 1
    fi
    log "  PostgreSQL not ready — retrying in 2s (${RETRIES} retries left)"
    sleep 2
done
log "PostgreSQL is reachable."

# ── Wait for Redis ────────────────────────────────────────────────────────────
log "Waiting for Redis..."
REDIS_HOST="${REDIS_HOST:-redis}"
REDIS_PORT="${REDIS_PORT:-6379}"
RETRIES=15
until python -c "
import socket, sys
try:
    s = socket.create_connection(('${REDIS_HOST}', ${REDIS_PORT}), timeout=2)
    s.close()
    sys.exit(0)
except Exception:
    sys.exit(1)
" 2>/dev/null; do
    RETRIES=$((RETRIES - 1))
    if [ "$RETRIES" -le 0 ]; then
        log "ERROR: Redis at ${REDIS_HOST}:${REDIS_PORT} did not become reachable in 30s"
        exit 1
    fi
    log "  Redis not ready — retrying in 2s (${RETRIES} retries left)"
    sleep 2
done
log "Redis is reachable."

# ── Django management commands ────────────────────────────────────────────────
log "Running database migrations..."
python manage.py migrate --noinput

log "Collecting static files..."
python manage.py collectstatic --noinput --clear

# ── Gunicorn worker count ─────────────────────────────────────────────────────
# Formula: 2 * nCPU + 1  (Gunicorn docs recommendation for CPU-bound apps).
# In a container, nproc gives the number of CPUs *allocated to the container*
# (via --cpus or cgroups), not the host CPU count — which is the correct
# number to scale against.
if [ -z "$GUNICORN_WORKERS" ]; then
    NCPUS=$(nproc 2>/dev/null || echo 1)
    GUNICORN_WORKERS=$(( 2 * NCPUS + 1 ))
    log "Auto-sized Gunicorn workers: ${GUNICORN_WORKERS} (nCPU=${NCPUS})"
fi

# ── Start Gunicorn ────────────────────────────────────────────────────────────
log "Starting Gunicorn: ${GUNICORN_WORKERS} workers, ${GUNICORN_THREADS} threads, bind=${GUNICORN_BIND}"

exec gunicorn "${WSGI_APP}" \
    --bind "${GUNICORN_BIND}" \
    --workers "${GUNICORN_WORKERS}" \
    --threads "${GUNICORN_THREADS}" \
    --timeout "${GUNICORN_TIMEOUT}" \
    --worker-class gthread \
    --worker-tmp-dir /dev/shm \
    --access-logfile - \
    --error-logfile - \
    --log-level info \
    --capture-output \
    --forwarded-allow-ips='*'
