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
  ''${NEXUS_URL}'service/rest/v1/security/realms/active' \
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

# create docker proxy repository: 
# 1
curl -k -X 'POST' \
  ''${NEXUS_URL}'/service/rest/v1/repositories/docker/proxy' \
  -u "${ADMIN_USERNAME}:${ADMIN_PASSWORD}" \
  -H 'accept: application/json' \
  -H 'Content-Type: application/json' \
  -d '{
  "name": "docker-images",
  "online": true,
  "storage": {
    "blobStoreName": "'${DOCKER_BLOB_STORE_NAME}'",
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
    "autoBlock": false,
    "authentication": {
    "type": "username",
    "username": "mojtabaa1994",
    "password": "Mm3494621Mm",
    "ntlmHost": "string",
    "ntlmDomain": "string"
    }
  },
  "routingRule": "string",
  "docker": {
    "v1Enabled": true,
    "forceBasicAuth": false,
    "httpPort": 8082
  },
  "dockerProxy": {
    "indexType": "REGISTRY"
  }
}'

# 2
curl -k -X 'POST' \
  ''${NEXUS_URL}'/service/rest/v1/repositories/docker/proxy' \
  -u "${ADMIN_USERNAME}:${ADMIN_PASSWORD}" \
  -H 'accept: application/json' \
  -H 'Content-Type: application/json' \
  -d '{
  "name": "ghcr-iamges",
  "online": true,
  "storage": {
    "blobStoreName": "'${DOCKER_BLOB_STORE_NAME}'",
    "strictContentTypeValidation": true
  },
  "cleanup": {
    "policyNames": [
      "string"
    ]
  },
  "proxy": {
    "remoteUrl": "https://ghcr.io",
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
    "httpPort": 8086
  },
  "dockerProxy": {
    "indexType": "REGISTRY"
  }
}'

# 3
curl -k -X 'POST' \
  ''${NEXUS_URL}'/service/rest/v1/repositories/docker/proxy' \
  -u "${ADMIN_USERNAME}:${ADMIN_PASSWORD}" \
  -H 'accept: application/json' \
  -H 'Content-Type: application/json' \
  -d '{
  "name": "quay-images",
  "online": true,
  "storage": {
    "blobStoreName": "'${DOCKER_BLOB_STORE_NAME}'",
    "strictContentTypeValidation": true
  },
  "cleanup": {
    "policyNames": [
      "string"
    ]
  },
  "proxy": {
    "remoteUrl": "https://quay.io",
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
    "httpPort": 8084
  },
  "dockerProxy": {
    "indexType": "REGISTRY"
  }
}'

# 4
curl -k -X 'POST' \
  ''${NEXUS_URL}'/service/rest/v1/repositories/docker/proxy' \
  -u "${ADMIN_USERNAME}:${ADMIN_PASSWORD}" \
  -H 'accept: application/json' \
  -H 'Content-Type: application/json' \
  -d '{
  "name": "k8s-images",
  "online": true,
  "storage": {
    "blobStoreName": "'${DOCKER_BLOB_STORE_NAME}'",
    "strictContentTypeValidation": true
  },
  "cleanup": {
    "policyNames": [
      "string"
    ]
  },
  "proxy": {
    "remoteUrl": "https://registry.k8s.io/",
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
    "httpPort": 8085
  },
  "dockerProxy": {
    "indexType": "REGISTRY"
  }
}'

# 5
curl -k -X 'POST' \
  ''${NEXUS_URL}'/service/rest/v1/repositories/docker/proxy' \
  -u "${ADMIN_USERNAME}:${ADMIN_PASSWORD}" \
  -H 'accept: application/json' \
  -H 'Content-Type: application/json' \
  -d '{
  "name": "hub-images",
  "online": true,
  "storage": {
    "blobStoreName": "'${DOCKER_BLOB_STORE_NAME}'",
    "strictContentTypeValidation": true
  },
  "cleanup": {
    "policyNames": [
      "string"
    ]
  },
  "proxy": {
    "remoteUrl": "https://index.docker.io/",
    "contentMaxAge": 1440,
    "metadataMaxAge": 1440
  },
  "negativeCache": {
    "enabled": true,
    "timeToLive": 1440
  },
  "httpClient": {
    "blocked": false,
    "autoBlock": false,
    "authentication": {
    "type": "username",
    "username": "mojtabaa1994",
    "password": "Mm3494621Mm",
    "ntlmHost": "string",
    "ntlmDomain": "string"
    }
  },
  "routingRule": "string",
  "docker": {
    "v1Enabled": true,
    "forceBasicAuth": false,
    "httpPort": 8087
  },
  "dockerProxy": {
    "indexType": "REGISTRY"
  }
}'

# APT repository
# 1
curl -X 'POST' \
  ''${NEXUS_URL}'/service/rest/v1/repositories/apt/proxy' \
  -u "${ADMIN_USERNAME}:${ADMIN_PASSWORD}" \
  -H 'accept: application/json' \
  -H 'Content-Type: application/json' \
  -d '{
  "name": "debian",
  "online": true,
  "storage": {
    "blobStoreName": "'${APT_BLOB_STORE_NAME}'",
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
    "autoBlock": true
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

# 2
curl -X 'POST' \
  ''${NEXUS_URL}'/service/rest/v1/repositories/apt/proxy' \
  -u "${ADMIN_USERNAME}:${ADMIN_PASSWORD}" \
  -H 'accept: application/json' \
  -H 'Content-Type: application/json' \
  -d '{
  "name": "debian-security",
  "online": true,
  "storage": {
    "blobStoreName": "'${APT_BLOB_STORE_NAME}'",
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
    "autoBlock": true
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

# 3
curl -X 'POST' \
  ''${NEXUS_URL}'/service/rest/v1/repositories/apt/proxy' \
  -u "${ADMIN_USERNAME}:${ADMIN_PASSWORD}" \
  -H 'accept: application/json' \
  -H 'Content-Type: application/json' \
  -d '{
  "name": "ubuntu",
  "online": true,
  "storage": {
    "blobStoreName": "'${APT_BLOB_STORE_NAME}'",
    "strictContentTypeValidation": true
  },
  "cleanup": {
    "policyNames": [
      "string"
    ]
  },
  "proxy": {
    "remoteUrl": "http://us.archive.ubuntu.com/ubuntu/",
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
  "replication": {
    "preemptivePullEnabled": false,
    "assetPathRegex": "string"
  },
  "apt": {
    "distribution": "jammy,jammy-updates",
    "flat": false
  }
}'

# 4
curl -X 'POST' \
  ''${NEXUS_URL}'/service/rest/v1/repositories/apt/proxy' \
  -u "${ADMIN_USERNAME}:${ADMIN_PASSWORD}" \
  -H 'accept: application/json' \
  -H 'Content-Type: application/json' \
  -d '{
  "name": "ubuntu-security",
  "online": true,
  "storage": {
    "blobStoreName": "'${APT_BLOB_STORE_NAME}'",
    "strictContentTypeValidation": true
  },
  "cleanup": {
    "policyNames": [
      "string"
    ]
  },
  "proxy": {
    "remoteUrl": "http://security.ubuntu.com/ubuntu",
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
  "replication": {
    "preemptivePullEnabled": false,
    "assetPathRegex": "string"
  },
  "apt": {
    "distribution": "jammy-security",
    "flat": false
  }
}'

# 5
curl -X 'POST' \
  ''${NEXUS_URL}'/service/rest/v1/repositories/apt/proxy' \
  -u "${ADMIN_USERNAME}:${ADMIN_PASSWORD}" \
  -H 'accept: application/json' \
  -H 'Content-Type: application/json' \
  -d '{
  "name": "k8s-package",
  "online": true,
  "storage": {
    "blobStoreName": "'${APT_BLOB_STORE_NAME}'",
    "strictContentTypeValidation": true
  },
  "cleanup": {
    "policyNames": [
      "string"
    ]
  },
  "proxy": {
    "remoteUrl": "http://pkgs.k8s.io/core:/stable:/v1.32/deb/",
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
  "replication": {
    "preemptivePullEnabled": false,
    "assetPathRegex": "string"
  },
  "apt": {
    "distribution": "/",
    "flat": false
  }
}'

# 6
curl -X 'POST' \
  ''${NEXUS_URL}'/service/rest/v1/repositories/apt/proxy' \
  -u "${ADMIN_USERNAME}:${ADMIN_PASSWORD}" \
  -H 'accept: application/json' \
  -H 'Content-Type: application/json' \
  -d '{
  "name": "docker-package",
  "online": true,
  "storage": {
    "blobStoreName": "'${APT_BLOB_STORE_NAME}'",
    "strictContentTypeValidation": true
  },
  "cleanup": {
    "policyNames": [
      "string"
    ]
  },
  "proxy": {
    "remoteUrl": "http://download.docker.com/linux/debian",
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
  "replication": {
    "preemptivePullEnabled": false,
    "assetPathRegex": "string"
  },
  "apt": {
    "distribution": "bookworm",
    "flat": false
  }
}'

# Raws proxies
# 1
curl -X 'POST' \
  ''${NEXUS_URL}'/service/rest/v1/repositories/raw/proxy' \
  -u "${ADMIN_USERNAME}:${ADMIN_PASSWORD}" \
  -H 'accept: application/json' \
  -H 'Content-Type: application/json' \
  -d '{
  "name": "raw-docker",
  "online": true,
  "storage": {
    "blobStoreName": "'${APT_BLOB_STORE_NAME}'",
    "strictContentTypeValidation": true
  },
  "cleanup": {
    "policyNames": [
      "string"
    ]
  },
  "proxy": {
    "remoteUrl": "https://registry-1.docker.io/",
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
  "replication": {
    "preemptivePullEnabled": false,
    "assetPathRegex": "string"
  },
  "raw": {
    "contentDisposition": "ATTACHMENT"
  }
}'

# 2
curl -X 'POST' \
  ''${NEXUS_URL}'/service/rest/v1/repositories/raw/proxy' \
  -u "${ADMIN_USERNAME}:${ADMIN_PASSWORD}" \
  -H 'accept: application/json' \
  -H 'Content-Type: application/json' \
  -d '{
  "name": "raw-github",
  "online": true,
  "storage": {
    "blobStoreName": "'${APT_BLOB_STORE_NAME}'",
    "strictContentTypeValidation": true
  },
  "cleanup": {
    "policyNames": [
      "string"
    ]
  },
  "proxy": {
    "remoteUrl": "https://github.com/",
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
  "replication": {
    "preemptivePullEnabled": false,
    "assetPathRegex": "string"
  },
  "raw": {
    "contentDisposition": "ATTACHMENT"
  }
}'

# 3
curl -X 'POST' \
  ''${NEXUS_URL}'/service/rest/v1/repositories/raw/proxy' \
  -u "${ADMIN_USERNAME}:${ADMIN_PASSWORD}" \
  -H 'accept: application/json' \
  -H 'Content-Type: application/json' \
  -d '{
  "name": "raw-helm",
  "online": true,
  "storage": {
    "blobStoreName": "'${APT_BLOB_STORE_NAME}'",
    "strictContentTypeValidation": true
  },
  "cleanup": {
    "policyNames": [
      "string"
    ]
  },
  "proxy": {
    "remoteUrl": "https://get.helm.sh",
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
  "replication": {
    "preemptivePullEnabled": false,
    "assetPathRegex": "string"
  },
  "raw": {
    "contentDisposition": "ATTACHMENT"
  }
}'

# 4
curl -X 'POST' \
  ''${NEXUS_URL}'/service/rest/v1/repositories/raw/proxy' \
  -u "${ADMIN_USERNAME}:${ADMIN_PASSWORD}" \
  -H 'accept: application/json' \
  -H 'Content-Type: application/json' \
  -d '{
  "name": "raw-k8s",
  "online": true,
  "storage": {
    "blobStoreName": "'${APT_BLOB_STORE_NAME}'",
    "strictContentTypeValidation": true
  },
  "cleanup": {
    "policyNames": [
      "string"
    ]
  },
  "proxy": {
    "remoteUrl": "https://dl.k8s.io/",
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
  "replication": {
    "preemptivePullEnabled": false,
    "assetPathRegex": "string"
  },
  "raw": {
    "contentDisposition": "ATTACHMENT"
  }
}'

# Group raws
curl -X 'POST' \
  ''${NEXUS_URL}'/service/rest/v1/repositories/raw/group' \
  -u "${ADMIN_USERNAME}:${ADMIN_PASSWORD}" \
  -H 'accept: application/json' \
  -H 'Content-Type: application/json' \
  -d '{
  "name": "raw-group",
  "online": true,
  "storage": {
    "blobStoreName": "'${APT_BLOB_STORE_NAME}'",
    "strictContentTypeValidation": true
  },
  "group": {
    "memberNames": [
      "raw-docker",
      "raw-helm",
      "raw-k8s",
      "raw-github"
    ]
  },
  "raw": {
    "contentDisposition": "ATTACHMENT"
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