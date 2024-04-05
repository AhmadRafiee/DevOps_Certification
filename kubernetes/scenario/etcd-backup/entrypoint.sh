#! /bin/bash
set -e -o pipefail

ENDPOINTS="$1"

echo $ENDPOINTS
NOW=$(date +%Y-%m-%d_%H:%M:%S)

mc alias set "$MINIO_ALIAS_NAME" "$MINIO_SERVER" "$MINIO_ACCESS_KEY" "$MINIO_SECRET_KEY" --api "$MINIO_API_VERSION" > /dev/null

echo "Check mc alias name"
mc alias list

echo "Check bucket list"
mc ls "$MINIO_ALIAS_NAME"

echo "Dumping etcd to $ARCHIVE"
echo "> ETCDCTL_API=3 etcdctl --endpoints=$ENDPOINTS --cacert=/certs/ca.crt --cert=/certs/healthcheck-client.crt --key=/certs/healthcheck-client.key snapshot save /tmp/etcd_backup_${NOW}"
etcdctl --endpoints=$ENDPOINTS --cacert=/certs/ca.crt --cert=/certs/healthcheck-client.crt --key=/certs/healthcheck-client.key snapshot save /tmp/etcd_backup_${NOW}

echo " coping etcd_backup_${NOW} to ${MINIO_ALIAS_NAME}/${MINIO_BUCKET} "
echo "> mc cp /tmp/etcd_backup_${NOW} ${MINIO_ALIAS_NAME}/${MINIO_BUCKET} --json "
mc cp /tmp/etcd_backup_${NOW} ${MINIO_ALIAS_NAME}/${MINIO_BUCKET}  || { echo "Backup failed"; mc rm "${MINIO_ALIAS_NAME}/$ARCHIVE"; exit 1; }

echo "size check"
ls -lah /tmp/etcd_backup_${NOW}
echo "Backup complete"