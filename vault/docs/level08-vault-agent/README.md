# Level 8 — Vault Agent

### Requirements:
  - **Vault Service is Running** from level 0
  - **Vault Address:** `https://vault.lab.mecan.ir`
  - **Auth:** Root token `myroot` (dev mode only)
  - **Tools:** install `jq` command

---

## Overview

Vault Agent is a daemon that runs alongside your application and handles
everything Vault-related on its behalf:

- **Auto-auth:** authenticates with Vault automatically (AppRole, Kubernetes, etc.)
- **Token renewal:** keeps the token alive without any app code
- **Template rendering:** writes secrets to files that the app reads — no Vault SDK needed
- **Hot-reload:** re-renders files when secrets change in Vault

The application never calls Vault directly. It just reads files.

```
                     ┌──────────────────┐
                     │   Vault Agent    │
                     │                  │
CI/CD ─ secret_id ─► |  auto_auth       │──── token ───► Vault
                     │  (AppRole)       │◄─── secrets ──
                     │                  │
                     │  templates       │──► /etc/app/db.env   ◄── App reads
                     │                  │──► /etc/app/db.url   ◄── App reads
                     └──────────────────┘
```

The app has zero Vault code. It reads plain files.

---

## 8.1 Why Vault Agent?

| Without Agent                        | With Agent                             |
|--------------------------------------|----------------------------------------|
| App imports Vault SDK                | App reads plain files                  |
| App manages token renewal            | Agent renews automatically             |
| Secret rotation needs app restart    | Agent re-renders files on change       |
| Every service re-implements auth     | Auth logic lives in agent config only  |
| Secret in environment variable       | Secret in file with `0600` permissions |

---

## 8.2 Agent Configuration File

The agent is configured in a single HCL file.

```hcl
vault {
  address = "http://127.0.0.1:8200"
}

auto_auth {
  method "approle" {
    config = {
      role_id_file_path                = "/tmp/agent/role_id"
      secret_id_file_path              = "/tmp/agent/secret_id"
      remove_secret_id_file_after_reading = false
    }
  }

  sink "file" {
    config = {
      path = "/tmp/agent/vault-token"
    }
  }
}

template_config {
  static_secret_render_interval = "10s"   # poll KV secrets every 10s
}

template {
  contents    = "{{ with secret \"secret/data/myapp/database\" }}db_host={{ .Data.data.host }}\ndb_user={{ .Data.data.username }}\ndb_pass={{ .Data.data.password }}\n{{ end }}"
  destination = "/tmp/agent/app.env"
  perms       = "0600"
}

template {
  contents    = "{{ with secret \"secret/data/myapp/database\" }}postgresql://{{ .Data.data.username }}:{{ .Data.data.password }}@{{ .Data.data.host }}:{{ .Data.data.port }}/appdb{{ end }}"
  destination = "/tmp/agent/db.url"
  perms       = "0600"
}
```

### Section breakdown

**`vault {}`** — which Vault server to talk to.

**`auto_auth {}`** — how the agent authenticates.
- `method "approle"` — uses `role_id` + `secret_id` from files
- `sink "file"` — writes the obtained token to a file for other tools to use

**`template_config {}`**
- `static_secret_render_interval` — how often to re-read KV v2 secrets.
  KV v2 has no lease, so the agent must poll. Dynamic secrets (database, PKI)
  are re-fetched automatically when the lease expires.

**`template {}`** — Go template that renders a file.
- `contents` — inline template using Consul Template syntax
- `destination` — output file path
- `perms` — file permissions (`0600` = owner read/write only)

---

## 8.3 Consul Template Syntax

Vault Agent templates use Consul Template syntax:

```
{{ with secret "secret/data/myapp/database" }}
  {{ .Data.data.password }}
{{ end }}
```

For KV v2, the path is `.Data.data.<key>` (two levels of `data`).
For KV v1, it would be `.Data.<key>`.

Common functions:

```
{{ .Data.data.host }}           → value of a key
{{ .Data.metadata.version }}    → KV version number
{{ env "SOME_ENV_VAR" }}        → read an environment variable
{{ timestamp }}                 → current Unix timestamp
```

---

## 8.4 Running the Agent

### Prerequisite: write credentials to files

```bash
# role_id stays constant — baked into the image or config
echo "fe538af3-a240-5f4e-9819-873c63e8d18d" > /tmp/agent/role_id

# secret_id is injected per-deploy by CI/CD
SECRET_ID=$(curl -s -X POST https://vault.lab.mecan.ir/v1/auth/approle/role/backend-service/secret-id \
  -H "X-Vault-Token: myroot" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['secret_id'])")
echo "$SECRET_ID" > /tmp/agent/secret_id
```

### Start the agent

```bash
vault agent -config=/tmp/agent/agent.hcl
```

On startup the agent logs:

```
[INFO]  agent.auth.handler: authenticating
[INFO]  agent.auth.handler: authentication successful, sending token to sinks
[INFO]  agent.auth.handler: starting renewal process
[INFO]  agent.sink.file: token written: path=/tmp/agent/vault-token
[INFO]  agent: (runner) rendered "(dynamic)" => "/tmp/agent/app.env"
[INFO]  agent: (runner) rendered "(dynamic)" => "/tmp/agent/db.url"
```

### Rendered output files

`/tmp/agent/app.env`:
```
db_host=db.internal
db_user=appuser
db_pass=super-secret-pass
```

`/tmp/agent/db.url`:
```
postgresql://appuser:super-secret-pass@db.internal:5432/appdb
```

---

## 8.5 Hot-Reload: Secret Rotation Without Restart

### Scenario
The database password is rotated in Vault. The application should pick up
the new password without restarting. The agent polls Vault every 10 seconds
and re-renders any template whose upstream secret has changed.

**Step 1:** Agent renders initial files with old password.

**Step 2:** Admin rotates the secret:

```bash
curl -X POST https://vault.lab.mecan.ir/v1/secret/data/myapp/database \
  -H "X-Vault-Token: myroot" \
  -H "Content-Type: application/json" \
  -d '{"data": {"host": "db-replica.internal", "password": "brand-new-pass-v4", ...}}'
```

**Step 3:** Within `static_secret_render_interval` (10s), the agent polls,
detects the change, and re-renders:

```
[INFO]  agent: (runner) rendered "(dynamic)" => "/tmp/agent/app.env"
[INFO]  agent: (runner) rendered "(dynamic)" => "/tmp/agent/db.url"
```

**Step 4:** The file now contains the new password. The app reads it on next
access — no restart, no redeploy.

```
db_host=db-replica.internal
db_user=appuser
db_pass=brand-new-pass-v4
```

---

## 8.6 In Production: Agent as a Sidecar

In Kubernetes, Vault Agent runs as an init container + sidecar:

```yaml
initContainers:
  - name: vault-agent-init
    image: hashicorp/vault:2.0
    args: ["agent", "-config=/vault/config/agent.hcl", "-exit-after-auth"]
    # writes secrets to shared volume before app starts

containers:
  - name: vault-agent
    image: hashicorp/vault:2.0
    args: ["agent", "-config=/vault/config/agent.hcl"]
    # keeps running, renews token, re-renders on secret change

  - name: app
    image: myapp:latest
    # reads /vault/secrets/app.env — no Vault SDK, no tokens
```

The init container runs once and exits after auth (secrets written before app
starts). The sidecar runs continuously for renewal and hot-reload.

---

## Key Behaviours Summary

| Behaviour                       | How                                              |
|---------------------------------|--------------------------------------------------|
| First auth on startup           | `auto_auth` with AppRole                         |
| Token written to disk           | `sink "file"` — other tools can use it           |
| Token renewal                   | Automatic — agent manages the renewal loop       |
| KV v2 change detection          | `static_secret_render_interval` polling          |
| Dynamic secret refresh          | Automatic — re-fetched when lease expires        |
| File permissions                | Set per template with `perms`                    |
| Agent crash recovery            | Re-reads credential files and re-authenticates   |

---

## API / CLI Reference

```bash
# Run agent (foreground)
vault agent -config=agent.hcl

# Run agent and exit after first auth + render (useful for init containers)
vault agent -config=agent.hcl -exit-after-auth

# Validate config without running
vault agent -config=agent.hcl -test
```
