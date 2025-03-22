output "bucket_name" {
  value = minio_s3_bucket.my_bucket.id
}

output "username" {
  value = minio_iam_user.my_user.id
}

output "user_status" {
  value = minio_iam_user.my_user.status
}

output "user_secret" {
  value     = minio_iam_user.my_user.secret
  sensitive = true
}

output "policy_id" {
  value = minio_iam_policy.my_policy.id
}

output "policy_raw" {
  value = minio_iam_policy.my_policy.policy
}

output "policy_attachment" {
  value = minio_iam_user_policy_attachment.backup.id
}

output "object_id" {
  value = minio_s3_object.my_file.id
}

output "object_content" {
  value = minio_s3_object.my_file.content
}

