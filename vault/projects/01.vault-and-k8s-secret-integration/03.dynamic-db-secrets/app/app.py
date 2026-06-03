"""
Dynamic Database Credentials Demo
==================================
This app demonstrates Vault's Database Secrets Engine pattern:

  READ  operations  →  Vault issues a temporary PostgreSQL user with SELECT only
  WRITE operations  →  Vault issues a temporary PostgreSQL user with full CRUD

Key behaviour:
  - Reader credentials are cached in memory until 90% of their TTL expires.
  - Writer credentials are NEVER cached — each write operation gets fresh,
    short-lived credentials. When the operation finishes, the connection is
    closed and Vault will revoke the ephemeral user after TTL expires.

Endpoints:
  GET  /healthz           — liveness probe
  GET  /items             — list all rows  (reader credentials)
  POST /items             — insert a row   (writer credentials)
  DELETE /items/<id>      — delete a row   (writer credentials)
  GET  /vault/status      — show current vault token + credential cache info
"""

import os
import time
import logging
import requests
import psycopg2
import psycopg2.extras
from flask import Flask, jsonify, request, abort

app = Flask(__name__)
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s  %(levelname)-7s  %(message)s",
    datefmt="%H:%M:%S",
)
log = logging.getLogger(__name__)

# ── Config from environment ────────────────────────────────────────────────────
VAULT_ADDR   = os.environ.get("VAULT_ADDR",   "http://172.20.0.4:8200")
VAULT_ROLE   = os.environ.get("VAULT_ROLE",   "dynamic-db-app")
DB_HOST      = os.environ.get("DB_HOST",      "postgres.default.svc.cluster.local")
DB_PORT      = int(os.environ.get("DB_PORT",  "5432"))
DB_NAME      = os.environ.get("DB_NAME",      "appdb")
SA_TOKEN_PATH = "/var/run/secrets/kubernetes.io/serviceaccount/token"

# ── In-memory token + credential cache ────────────────────────────────────────
_vault_token         = None
_vault_token_expiry  = 0.0

_reader_creds        = None   # (username, password)
_reader_creds_expiry = 0.0


def _vault_login() -> str:
    """Authenticate with Vault using the pod's Kubernetes ServiceAccount JWT."""
    global _vault_token, _vault_token_expiry

    with open(SA_TOKEN_PATH) as fh:
        jwt = fh.read().strip()

    resp = requests.post(
        f"{VAULT_ADDR}/v1/auth/kubernetes/login",
        json={"role": VAULT_ROLE, "jwt": jwt},
        timeout=5,
    )
    resp.raise_for_status()
    auth = resp.json()["auth"]

    _vault_token        = auth["client_token"]
    _vault_token_expiry = time.time() + auth["lease_duration"]
    log.info("Vault login OK  token_ttl=%ds", auth["lease_duration"])
    return _vault_token


def _get_vault_token() -> str:
    """Return the cached Vault token, refreshing if it's within 60 s of expiry."""
    if _vault_token and time.time() < _vault_token_expiry - 60:
        return _vault_token
    return _vault_login()


def _fetch_db_creds(vault_role: str) -> tuple[str, str, int]:
    """Ask Vault for a fresh ephemeral DB user.  Returns (username, password, ttl)."""
    resp = requests.get(
        f"{VAULT_ADDR}/v1/database/creds/{vault_role}",
        headers={"X-Vault-Token": _get_vault_token()},
        timeout=5,
    )
    resp.raise_for_status()
    body     = resp.json()
    username = body["data"]["username"]
    password = body["data"]["password"]
    ttl      = body["lease_duration"]
    log.info(
        "Vault issued  role=%-12s  user=%-30s  ttl=%ds",
        vault_role, username, ttl,
    )
    return username, password, ttl


def _get_reader_creds() -> tuple[str, str]:
    """Return cached reader credentials, fetching fresh ones when near expiry."""
    global _reader_creds, _reader_creds_expiry

    if _reader_creds and time.time() < _reader_creds_expiry:
        log.info("Reader creds from cache  user=%s", _reader_creds[0])
        return _reader_creds

    username, password, ttl = _fetch_db_creds("app-reader")
    _reader_creds        = (username, password)
    # Renew when 90% of TTL has elapsed so we never use an almost-expired credential
    _reader_creds_expiry = time.time() + ttl * 0.9
    return _reader_creds


def _get_writer_creds() -> tuple[str, str]:
    """Always fetch fresh writer credentials — never cached.

    Write credentials are intentionally short-lived (15 min TTL).  Not caching
    them means each write operation proves it has current authorisation from
    Vault and limits exposure if a credential leaks.
    """
    username, password, _ = _fetch_db_creds("app-writer")
    return username, password


def _db_connect(write: bool = False):
    """Open a new PostgreSQL connection with the appropriate credentials."""
    user, pwd = _get_writer_creds() if write else _get_reader_creds()
    return psycopg2.connect(
        host=DB_HOST, port=DB_PORT, dbname=DB_NAME,
        user=user, password=pwd,
        connect_timeout=5,
    )


# ── Routes ─────────────────────────────────────────────────────────────────────

@app.route("/healthz")
def healthz():
    return jsonify({"status": "ok"})


@app.route("/vault/status")
def vault_status():
    """Show the current Vault token TTL and reader-cred cache state."""
    return jsonify({
        "vault_addr":         VAULT_ADDR,
        "vault_role":         VAULT_ROLE,
        "token_valid":        bool(_vault_token and time.time() < _vault_token_expiry),
        "token_expires_in":   max(0, int(_vault_token_expiry - time.time())),
        "reader_cache_valid": bool(_reader_creds and time.time() < _reader_creds_expiry),
        "reader_expires_in":  max(0, int(_reader_creds_expiry - time.time())),
        "reader_user":        _reader_creds[0] if _reader_creds else None,
    })


@app.route("/items", methods=["GET"])
def list_items():
    """
    SELECT all rows using read-only credentials.
    The ephemeral PostgreSQL user can only run SELECT statements.
    Any attempt to write inside this connection would raise a permissions error.
    """
    try:
        conn = _db_connect(write=False)
        with conn, conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            cur.execute("SELECT id, name, value, created_at FROM items ORDER BY id")
            rows = [dict(r) for r in cur.fetchall()]
        log.info("GET /items  rows=%d", len(rows))
        return jsonify({"access": "read-only", "count": len(rows), "items": rows})
    except Exception as exc:
        log.error("GET /items failed: %s", exc)
        abort(500, str(exc))


@app.route("/items", methods=["POST"])
def create_item():
    """
    INSERT a row using write credentials.
    Each POST call to this endpoint triggers a Vault credential request:
    a new ephemeral PostgreSQL user is created, used for the INSERT, then
    the connection is closed.  Vault revokes the user when the TTL expires.
    """
    body = request.get_json(silent=True) or {}
    if not body.get("name"):
        abort(400, "'name' field required")

    try:
        conn = _db_connect(write=True)
        with conn, conn.cursor() as cur:
            cur.execute(
                "INSERT INTO items (name, value) VALUES (%s, %s) RETURNING id, created_at",
                (body["name"], body.get("value", "")),
            )
            row = cur.fetchone()
        log.info("POST /items  id=%d", row[0])
        return jsonify({
            "access":     "read-write",
            "id":         row[0],
            "name":       body["name"],
            "value":      body.get("value", ""),
            "created_at": str(row[1]),
        }), 201
    except Exception as exc:
        log.error("POST /items failed: %s", exc)
        abort(500, str(exc))


@app.route("/items/<int:item_id>", methods=["DELETE"])
def delete_item(item_id: int):
    """
    DELETE a row using write credentials.
    Same pattern as POST: fresh credentials from Vault for every call.
    """
    try:
        conn = _db_connect(write=True)
        with conn, conn.cursor() as cur:
            cur.execute("DELETE FROM items WHERE id = %s RETURNING id", (item_id,))
            deleted = cur.fetchone()
        if not deleted:
            abort(404, f"item {item_id} not found")
        log.info("DELETE /items/%d  ok", item_id)
        return jsonify({"access": "read-write", "deleted_id": item_id})
    except Exception as exc:
        log.error("DELETE /items/%d failed: %s", item_id, exc)
        abort(500, str(exc))


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080, debug=False)
