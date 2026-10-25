#!/usr/bin/env bash
# Creates the Grafana admin secret out-of-band (never committed to Git).
# Run once on the cluster host before / right after Argo CD syncs this stack.
# Idempotent: an existing secret is left untouched.
set -euo pipefail
SECRETS_DIR="${SECRETS_DIR:-/root/homelab-secrets}"
PW_FILE="$SECRETS_DIR/grafana-admin.txt"
NS=monitoring

install -d -m 0700 "$SECRETS_DIR"
kubectl get ns "$NS" >/dev/null 2>&1 || kubectl create ns "$NS"

if kubectl -n "$NS" get secret grafana-admin >/dev/null 2>&1; then
  echo "secret $NS/grafana-admin already exists - leaving it alone"
  exit 0
fi
if [[ ! -s "$PW_FILE" ]]; then
  ( umask 077; python3 -c 'import secrets; print(secrets.token_urlsafe(24))' > "$PW_FILE" )
fi
chmod 600 "$PW_FILE"
kubectl -n "$NS" create secret generic grafana-admin \
  --from-literal=admin-user=admin \
  --from-file=admin-password=<(tr -d '\n' < "$PW_FILE")
echo "created $NS/grafana-admin (password stored in $PW_FILE)"
