resource "minio_s3_bucket" "my_bucket" {
  bucket = var.bucket_name
}

resource "minio_iam_user" "my_user" {
  name = var.user_name
  secret = var.user_password
}

resource "minio_iam_policy" "my_policy" {
  name = var.policy_name

  # Assuming you can define preferences directly in the policy property
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:PutObject"
      ],
      "Resource": [
        "arn:aws:s3:::${var.bucket_name}/*",
        "arn:aws:s3:::${var.bucket_name}"
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

resource "minio_s3_object" "my_file" {
  depends_on  = [minio_s3_bucket.my_bucket]
  bucket_name = minio_s3_bucket.my_bucket.bucket
  object_name = "text.txt"
  content     = "for test"
}
