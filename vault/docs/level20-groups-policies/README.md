# Level 20 — Groups & Policies (Identity Management)

### Requirements:
  - **Vault Service is Running** from level 15
  - **Vault Address:** `https://vault.lab.mecan.ir`
  - **Auth:** Root token `your-root-token-here` (dev mode only)
  - **Tools:** install `jq` command

---

## Overview

Vault's Identity system decouples **who someone is** from **how they logged in**.
An entity represents a user or service. Groups collect entities and apply policies
to all members at once. When a user logs in via any auth method, their entity's
group memberships determine which policies they get.

```
Entity (sara)
  ├── Alias: userpass/sara      ← login via username/password
  ├── Alias: jwt/alice@...      ← same person, different auth method
  └── Groups: [developers]      ← inherits group-developers policy

Group (developers)
  ├── Members: [sara, dani]
  └── Policies: [group-developers]   ← applied to all members on login
```

---

## 20.1 Core Concepts

| Concept | What it is |
|---|---|
| **Entity** | Vault's internal identity for a person or service |
| **Alias** | Link between an entity and an auth method account |
| **Internal Group** | Group managed entirely in Vault |
| **External Group** | Group synced from an external source (LDAP, OIDC) |
| **Identity Policy** | Policy applied via group membership, separate from token policies |

---

## 20.2 Get Auth Method Accessors

Each auth method has an **accessor** — needed when creating entity aliases.

```bash
curl https://vault.lab.mecan.ir/v1/sys/auth \
  -H "X-Vault-Token: your-root-token-here" \
  | python3 -c "
import sys,json
for k,v in json.load(sys.stdin)['data'].items():
    print(f'{v[\"type\"]:15} → {v[\"accessor\"]}')
"

# userpass       → auth_userpass_42a0ef8b
# jwt            → auth_jwt_0d2ae7f7
```

---

## 20.3 Create Entities

Each user gets one entity — their stable Vault identity.

```bash
curl -X POST https://vault.lab.mecan.ir/v1/identity/entity \
  -H "X-Vault-Token: your-root-token-here" \
  -d '{
    "name": "entity-sara",
    "metadata": {"team": "mecan", "user": "sara"}
  }' | jq
```

Response — save the entity `id`:
```json
{
  "data": {
    "id": "aee8c886-cc4f-75d1-4d00-291673c7454c",
    "name": "entity-sara"
  }
}
```

---

## 20.4 Create Entity Aliases

An alias links the entity to a specific login account in an auth method.
One entity can have multiple aliases (e.g., userpass + JWT).

```bash
curl -X POST https://vault.lab.mecan.ir/v1/identity/entity-alias \
  -H "X-Vault-Token: your-root-token-here" \
  -d '{
    "name":          "sara",
    "canonical_id":  "5ee4c065-acfd-fb86-9c80-8494474ebb35",
    "mount_accessor": "auth_userpass_42a0ef8b"
  }'
```

After this, when sara logs in via userpass, Vault recognizes her as entity `aee8c886...`
and applies all her group policies automatically.

---

## 20.5 Create Group Policies

Policies attached to groups, not to individual users.

`group-developers` — read all team secrets and shared resources:
```hcl
path "secret/data/team/*" {
  capabilities = ["read", "list"]
}
path "secret/data/shared/*" {
  capabilities = ["read", "list"]
}
```

`group-ops` — read and write all team secrets:
```hcl
path "secret/data/team/*" {
  capabilities = ["read", "create", "update", "list"]
}
path "secret/metadata/team/*" {
  capabilities = ["read", "list", "delete"]
}
path "secret/data/shared/*" {
  capabilities = ["read", "create", "update", "list"]
}
```

---

## 20.6 Create Groups

### Internal group with entity members

```bash
curl -X POST https://vault.lab.mecan.ir/v1/identity/group \
  -H "X-Vault-Token: your-root-token-here" \
  -d '{
    "name": "developers",
    "type": "internal",
    "policies": ["group-developers"],
    "member_entity_ids": [
      "aee8c886-cc4f-75d1-4d00-291673c7454c",
      "7c174fcc-4938-c95e-dd87-20ae5b89eaa4"
    ],
    "metadata": {"team": "engineering"}
  }'
```

### Parent group with sub-groups

```bash
curl -X POST https://vault.lab.mecan.ir/v1/identity/group \
  -H "X-Vault-Token: your-root-token-here" \
  -d '{
    "name": "all-staff",
    "type": "internal",
    "policies": ["default"],
    "member_group_ids": ["<developers-id>", "<ops-id>"]
  }'
```

All entities in `developers` and `ops` inherit `all-staff` policies too.

---

## 20.7 How Policies Stack on Login

When sara logs in:

```
sara's token policies:
  ├── [userpass user-level]  → frontend-dev, self-service    (set on the user account)
  └── [identity/group]       → group-developers, default     (from group membership)

Total effective policies:
  default + frontend-dev + self-service + group-developers
```

Vault shows both in the login response:
```json
{
  "auth": {
    "policies":          ["default", "frontend-dev", "group-developers", "self-service"],
    "identity_policies": ["default", "group-developers"],
    "entity_id":         "aee8c886-cc4f-75d1-4d00-291673c7454c"
  }
}
```

`identity_policies` are the group-sourced policies — separate from token policies.
Both are enforced. A user gets the union of all policies from all sources.

---

## 20.8 Dynamic Group Membership

Adding or removing an entity from a group takes effect on the **next login**.
Existing tokens are not updated until they renew or are re-issued.

```bash
# Add dani to ops group
OPS_GROUP_ID="baa7cb96-bb45-d032-7730-d560dbff555a"

curl -X POST https://vault.lab.mecan.ir/v1/identity/group/id/$OPS_GROUP_ID \
  -H "X-Vault-Token: your-root-token-here" \
  -d "{
    \"member_entity_ids\": [\"<lead-entity-id>\", \"<dani-entity-id>\"]
  }"
```

After dani logs in again:
```
identity_policies: [default, group-developers, group-ops]
```

---

## 20.9 Test Results

### Policy stacking

| User | Group | identity_policies | Write access |
|---|---|---|---|
| sara | developers | `group-developers` | ❌ read-only |
| dani | developers + ops | `group-developers`, `group-ops` | ✅ |
| lead | ops | `group-ops` | ✅ |

### Access test matrix

| User | `team/frontend` | `team/backend` | `shared/config` | Write `team/*` |
|---|---|---|---|---|
| sara | ✅ | ✅ (via group) | ✅ (via group) | ❌ |
| dani | ✅ | ✅ | ✅ | ✅ (via ops) |
| lead | ✅ | ✅ | ✅ | ✅ |

---

## 20.10 External Groups (Keycloak / LDAP)

For OIDC/JWT auth (Level 14), external groups map Keycloak group claims
directly to Vault group policies.

```bash
# Get JWT accessor
JWT_ACC="auth_jwt_0d2ae7f7"

# Create an external group
curl -X POST https://vault.lab.mecan.ir/v1/identity/group \
  -H "X-Vault-Token: your-root-token-here" \
  -d '{
    "name": "keycloak-developers",
    "type": "external",
    "policies": ["group-developers"]
  }'

# Create group alias — links Keycloak group name to Vault group
VAULT_GROUP_ID="<id from above>"
curl -X POST https://vault.lab.mecan.ir/v1/identity/group-alias \
  -H "X-Vault-Token: your-root-token-here" \
  -d "{
    \"name\": \"developers\",
    \"canonical_id\": \"$VAULT_GROUP_ID\",
    \"mount_accessor\": \"$JWT_ACC\"
  }"
```

When alice (Keycloak group `developers`) logs in via JWT, Vault automatically
maps her to the `keycloak-developers` Vault group and applies `group-developers` policy.

---

## API Reference

| Operation | Method | Path |
|---|---|---|
| Create entity | POST | `/v1/identity/entity` |
| Read entity by name | GET | `/v1/identity/entity/name/<name>` |
| Read entity by id | GET | `/v1/identity/entity/id/<id>` |
| List entities | LIST | `/v1/identity/entity/name` |
| Create alias | POST | `/v1/identity/entity-alias` |
| Create group | POST | `/v1/identity/group` |
| Read group by name | GET | `/v1/identity/group/name/<name>` |
| Update group | POST | `/v1/identity/group/id/<id>` |
| List groups | LIST | `/v1/identity/group/name` |
| Create group alias | POST | `/v1/identity/group-alias` |
