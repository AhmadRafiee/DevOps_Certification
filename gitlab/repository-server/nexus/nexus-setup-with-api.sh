#!/bin/bash

# Variable section
ADMIN_USERNAME="admin"
ADMIN_PASSWORD="<NEXUS_ADMIN_PASSWORD>"
NEXUS_URL="https://repo.mecan.ir"

# New user information
REPO_USERNAME="repo"
REPO_PASSWORD="<NEXUS_REPO_PASSWORD>"
REPO_EMAIL="ahmad@MeCan.ir"

# Minio information
MINIO_ACCESS_KEY=<MINIO_ACCESS_KEY>
MINIO_SECRET_KEY=<MINIO_SECRET_KEY>
MINIO_ENDPOINT_URL=https://io.repository.mecan.ir
MINIO_DOCKER_BLOBSTORE_BUCKET_NAME=nexus-docker-blob
MINIO_APT_BLOBSTORE_BUCKET_NAME=nexus-apt-blob

# blob store name
DOCKER_BLOB_STORE_NAME=docker
APT_BLOB_STORE_NAME=apt
# -----------------------------------------------------
# writable state
curl -k -X 'GET' \
  ''${NEXUS_URL}'/service/rest/v1/status/writable' \
  -H 'accept: application/json'


Nexus_Health=$(curl -k -X 'GET' ''${NEXUS_URL}'/service/rest/v1/status/writable' -H 'accept: application/json' 2>/dev/null)
echo ${Nexus_Health}

until [ -z "$Nexus_Health" ]
do
    Nexus_Health=$(curl -k -X 'GET' ''${NEXUS_URL}'/service/rest/v1/status/writable' -H 'accept: application/json' 2>/dev/null)
    echo ${Nexus_Health}
    echo "Waiting for nexus starting..."
    echo ${TIME}
    TIME=$((TIME+1))
    echo
    sleep 1
done
echo "nexus writable state is ok"

# get bootstrap password
BOOTSTRAP_ADMIN_PASSWORD=$(docker exec -i nexus cat /nexus-data/admin.password)
echo ${BOOTSTRAP_ADMIN_PASSWORD}

# change password
curl -k -X 'PUT' \
  ''${NEXUS_URL}'/service/rest/v1/security/users/admin/change-password' \
  -u "admin:${BOOTSTRAP_ADMIN_PASSWORD}" \
  -H 'accept: application/json' \
  -H 'Content-Type: text/plain' \
  -d ''${ADMIN_PASSWORD}''

# delete default repository
curl -k -X 'DELETE' \
  ''${NEXUS_URL}'/service/rest/v1/repositories/maven-releases' \
  -u "${ADMIN_USERNAME}:${ADMIN_PASSWORD}" \
  -H 'accept: application/json'

curl -k -X 'DELETE' \
  ''${NEXUS_URL}'/service/rest/v1/repositories/maven-snapshots' \
  -u "${ADMIN_USERNAME}:${ADMIN_PASSWORD}" \
  -H 'accept: application/json'

curl -k -X 'DELETE' \
  ''${NEXUS_URL}'/service/rest/v1/repositories/maven-central' \
  -u "${ADMIN_USERNAME}:${ADMIN_PASSWORD}" \
  -H 'accept: application/json'

curl -k -X 'DELETE' \
  ''${NEXUS_URL}'/service/rest/v1/repositories/maven-public' \
  -u "${ADMIN_USERNAME}:${ADMIN_PASSWORD}" \
  -H 'accept: application/json'

curl -k -X 'DELETE' \
  ''${NEXUS_URL}'/service/rest/v1/repositories/nuget.org-proxy' \
  -u "${ADMIN_USERNAME}:${ADMIN_PASSWORD}" \
  -H 'accept: application/json'

curl -k -X 'DELETE' \
  ''${NEXUS_URL}'/service/rest/v1/repositories/nuget-group' \
  -u "${ADMIN_USERNAME}:${ADMIN_PASSWORD}" \
  -H 'accept: application/json'

curl -k -X 'DELETE' \
  ''${NEXUS_URL}'/service/rest/v1/repositories/nuget-hosted' \
  -u "${ADMIN_USERNAME}:${ADMIN_PASSWORD}" \
  -H 'accept: application/json'

# enable anonymous access
curl -k -X 'PUT' \
  ''${NEXUS_URL}'/service/rest/v1/security/anonymous' \
  -u "${ADMIN_USERNAME}:${ADMIN_PASSWORD}" \
  -H 'accept: application/json' \
  -H 'Content-Type: application/json' \
  -d '{
  "enabled": true
}'

# activate realms
curl -k -X 'PUT' \
  ''${NEXUS_URL}'/service/rest/v1/security/realms/active' \
  -u "${ADMIN_USERNAME}:${ADMIN_PASSWORD}" \
  -H 'accept: application/json' \
  -H 'Content-Type: application/json' \
  -d '[
  "DockerToken",
  "NexusAuthenticatingRealm",
  "NexusAuthorizingRealm"
]'

# create role
curl -k -X 'POST' \
  ''${NEXUS_URL}'/service/rest/v1/security/roles' \
  -u "${ADMIN_USERNAME}:${ADMIN_PASSWORD}" \
  -H 'accept: application/json' \
  -H 'Content-Type: application/json' \
  -d '{
  "id": "repo-admin",
  "name": "repo-admin",
  "description": "all repository admin",
  "privileges": [
    "nx-repository-admin-*-*-*"
  ]
}'

# create user
curl -k -X 'POST' \
  ''${NEXUS_URL}'/service/rest/v1/security/users' \
  -u "${ADMIN_USERNAME}:${ADMIN_PASSWORD}" \
  -H 'accept: application/json' \
  -H 'Content-Type: application/json' \
  -d '{
  "userId": "'${REPO_USERNAME}'",
  "firstName": "'${REPO_USERNAME}'",
  "lastName": "afranet",
  "emailAddress": "'${REPO_EMAIL}'",
  "password": "'${REPO_PASSWORD}'",
  "status": "active",
  "roles": [
    "repo-admin",
    "nx-anonymous"
  ]
}'

# Create blob store with s3 backend
curl -X 'POST' \
  ''${NEXUS_URL}'/service/rest/v1/blobstores/s3' \
  -u "${ADMIN_USERNAME}:${ADMIN_PASSWORD}" \
  -H 'accept: application/json' \
  -H 'Content-Type: application/json' \
  -H 'NX-ANTI-CSRF-TOKEN: 0.4675223549012617' \
  -H 'X-Nexus-UI: true' \
  -d '{
  "name": "'${DOCKER_BLOB_STORE_NAME}'",
  "softQuota": {
    "type": "spaceRemainingQuota",
    "limit": 10
  },
  "bucketConfiguration": {
    "bucket": {
      "region": "DEFAULT",
      "name": "'${MINIO_DOCKER_BLOBSTORE_BUCKET_NAME}'",
      "prefix": "",
      "expiration": 3
    },
    "bucketSecurity": {
      "accessKeyId": "'${MINIO_ACCESS_KEY}'",
      "secretAccessKey": "'${MINIO_SECRET_KEY}'"
    },
    "advancedBucketConnection": {
      "endpoint": "'${MINIO_ENDPOINT_URL}'",
      "forcePathStyle": true,
      "maxConnectionPoolSize": 0
    }
  }
}'

curl -X 'POST' \
  ''${NEXUS_URL}'/service/rest/v1/blobstores/s3' \
  -u "${ADMIN_USERNAME}:${ADMIN_PASSWORD}" \
  -H 'accept: application/json' \
  -H 'Content-Type: application/json' \
  -H 'NX-ANTI-CSRF-TOKEN: 0.4675223549012617' \
  -H 'X-Nexus-UI: true' \
  -d '{
  "name": "'${APT_BLOB_STORE_NAME}'",
  "softQuota": {
    "type": "spaceRemainingQuota",
    "limit": 10
  },
  "bucketConfiguration": {
    "bucket": {
      "region": "DEFAULT",
      "name": "'${MINIO_APT_BLOBSTORE_BUCKET_NAME}'",
      "prefix": "",
      "expiration": 3
    },
    "bucketSecurity": {
      "accessKeyId": "'${MINIO_ACCESS_KEY}'",
      "secretAccessKey": "'${MINIO_SECRET_KEY}'"
    },
    "advancedBucketConnection": {
      "endpoint": "'${MINIO_ENDPOINT_URL}'",
      "forcePathStyle": true,
      "maxConnectionPoolSize": 0
    }
  }
}'

# create docker proxy repository
curl -k -X 'POST' \
  ''${NEXUS_URL}'/service/rest/v1/repositories/docker/proxy' \
  -u "${ADMIN_USERNAME}:${ADMIN_PASSWORD}" \
  -H 'accept: application/json' \
  -H 'Content-Type: application/json' \
  -d '{
  "name": "hub",
  "online": true,
  "storage": {
    "blobStoreName": "'${BLOB_STORE_NAME}'",
    "strictContentTypeValidation": true
  },
  "cleanup": {
    "policyNames": [
      "string"
    ]
  },
  "proxy": {
    "remoteUrl": "https://registry-1.docker.io",
    "contentMaxAge": 1440,
    "metadataMaxAge": 1440
  },
  "negativeCache": {
    "enabled": true,
    "timeToLive": 1440
  },
  "httpClient": {
    "blocked": false,
    "autoBlock": true
  },
  "routingRule": "string",
  "docker": {
    "v1Enabled": true,
    "forceBasicAuth": false,
    "httpPort": 8090
  },
  "dockerProxy": {
    "indexType": "HUB"
  }
}'

curl -X 'POST' \
  ''${NEXUS_URL}'/service/rest/v1/repositories/apt/proxy' \
  -u "${ADMIN_USERNAME}:${ADMIN_PASSWORD}" \
  -H 'accept: application/json' \
  -H 'Content-Type: application/json' \
  -d '{
  "name": "debian",
  "online": true,
  "storage": {
    "blobStoreName": "apt",
    "strictContentTypeValidation": true
  },
  "cleanup": {
    "policyNames": [
      "string"
    ]
  },
  "proxy": {
    "remoteUrl": "http://deb.debian.org/debian",
    "contentMaxAge": 1440,
    "metadataMaxAge": 1440
  },
  "negativeCache": {
    "enabled": true,
    "timeToLive": 1440
  },
  "httpClient": {
    "blocked": false,
    "autoBlock": true,
    "connection": {
      "retries": 0,
      "userAgentSuffix": "string",
      "timeout": 60,
      "enableCircularRedirects": false,
      "enableCookies": false,
      "useTrustStore": false
    },
    "authentication": {
      "type": "username",
      "username": "string",
      "password": "string",
      "ntlmHost": "string",
      "ntlmDomain": "string"
    }
  },
  "routingRule": "string",
  "replication": {
    "preemptivePullEnabled": false,
    "assetPathRegex": "string"
  },
  "apt": {
    "distribution": "bookworm,bookworm-updates,bookworm-backports",
    "flat": false
  }
}'

curl -X 'POST' \
  ''${NEXUS_URL}'/service/rest/v1/repositories/apt/proxy' \
  -u "${ADMIN_USERNAME}:${ADMIN_PASSWORD}" \
  -H 'accept: application/json' \
  -H 'Content-Type: application/json' \
  -d '{
  "name": "debian-security",
  "online": true,
  "storage": {
    "blobStoreName": "apt",
    "strictContentTypeValidation": true
  },
  "cleanup": {
    "policyNames": [
      "string"
    ]
  },
  "proxy": {
    "remoteUrl": "http://security.debian.org/",
    "contentMaxAge": 1440,
    "metadataMaxAge": 1440
  },
  "negativeCache": {
    "enabled": true,
    "timeToLive": 1440
  },
  "httpClient": {
    "blocked": false,
    "autoBlock": true,
    "connection": {
      "retries": 0,
      "userAgentSuffix": "string",
      "timeout": 60,
      "enableCircularRedirects": false,
      "enableCookies": false,
      "useTrustStore": false
    },
    "authentication": {
      "type": "username",
      "username": "string",
      "password": "string",
      "ntlmHost": "string",
      "ntlmDomain": "string"
    }
  },
  "routingRule": "string",
  "replication": {
    "preemptivePullEnabled": false,
    "assetPathRegex": "string"
  },
  "apt": {
    "distribution": "bookworm-security",
    "flat": false
  }
}'

# check all repositories
curl -k -X 'GET' \
  ''${NEXUS_URL}'/service/rest/v1/repositories' \
  -u "${ADMIN_USERNAME}:${ADMIN_PASSWORD}" \
  -H 'accept: application/json'

# check all blobstore
curl -k -X 'GET' \
  ''${NEXUS_URL}'/service/rest/v1/blobstores' \
  -u "${ADMIN_USERNAME}:${ADMIN_PASSWORD}" \
  -H 'accept: application/json'

# check all users and roles
curl -k -X 'GET' \
  ''${NEXUS_URL}'/service/rest/v1/security/users' \
  -u "${ADMIN_USERNAME}:${ADMIN_PASSWORD}" \
  -H 'accept: application/json'

curl -k -X 'GET' \
  ''${NEXUS_URL}'/service/rest/v1/security/roles' \
  -u "${ADMIN_USERNAME}:${ADMIN_PASSWORD}" \
  -H 'accept: application/json'