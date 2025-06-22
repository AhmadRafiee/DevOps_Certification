output "cloudflare_dns_record_api" {
  value = cloudflare_dns_record.cname_record_api.name
}

output "cloudflare_dns_record_console" {
  value = cloudflare_dns_record.cname_record_panel.name
}

output "bucket_name" {
  value = minio_s3_bucket.my_bucket.id
}

output "username" {
  value = minio_iam_user.my_user.name
}

output "user_status" {
  value = minio_iam_user.my_user.status
}

output "policy_id" {
  value = minio_iam_policy.my_policy.id
}

output "policy_attachment" {
  value = minio_iam_user_policy_attachment.backup.id
}

output "minio_namespace" {
  value = kubernetes_namespace.minio_namespace.id
}

output "minio_deployment" {
  value = helm_release.minio.id
}

output "velero_namespace" {
  value = kubernetes_namespace.velero_namespace.id
}

output "velero_deployment" {
  value = helm_release.velero.id
}
