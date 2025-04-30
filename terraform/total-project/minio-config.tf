resource "null_resource" "wait_for_url" {
  provisioner "local-exec" {
    command = <<EOT
      for i in $(seq 1 60); do
        echo "Checking https://${var.minio_console_domain} (attempt $i)..."
        if curl -s --head --fail https://${var.minio_console_domain} >/dev/null; then
          echo "URL is available!"
          exit 0
        fi
        sleep 5
      done
      echo "Timeout: URL is still not available."
      exit 1
    EOT
  }
  depends_on = [cloudflare_dns_record.cname_record_api]
}

resource "minio_s3_bucket" "my_bucket" {
  bucket = var.bucket_name
  depends_on = [null_resource.wait_for_url]
}

resource "minio_iam_user" "my_user" {
  name = var.minio_velero_username
  secret = var.minio_velero_password
  depends_on = [null_resource.wait_for_url]
}

resource "minio_iam_policy" "my_policy" {
  name = var.policy_name
  depends_on = [null_resource.wait_for_url]

  # Assuming you can define preferences directly in the policy property
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:GetObject",
        "s3:DeleteObject",
        "s3:ListBucket",
        "s3:ListBucketMultipartUploads",
        "s3:GetBucketLocation"
      ],
      "Resource": [
        "arn:aws:s3:::${var.bucket_name}",
        "arn:aws:s3:::${var.bucket_name}/*"
      ]
    }
  ]
}
EOF
}

resource "minio_iam_user_policy_attachment" "backup" {
  depends_on  = [minio_iam_user.my_user,minio_iam_policy.my_policy]
  user_name   = minio_iam_user.my_user.id
  policy_name = minio_iam_policy.my_policy.id
}