# Creates "AWS" resources inside LocalStack with OpenTofu. Nothing here touches real AWS.
# To use real AWS later: delete the `endpoints` block and the skip_* lines, and use real credentials.
terraform {
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

variable "endpoint" {
  type    = string
  default = "http://localhost:4566"
}

provider "aws" {
  region                      = "us-east-1"
  access_key                  = "test"
  secret_key                  = "test"
  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
  s3_use_path_style           = true
  endpoints {
    s3             = var.endpoint
    iam            = var.endpoint
    kms            = var.endpoint
    secretsmanager = var.endpoint
    sts            = var.endpoint
  }
}

# The lakehouse bucket. The name "warehouse" matches s3://warehouse/ used by Trino, Spark and the catalog.
resource "aws_s3_bucket" "warehouse" {
  bucket = "warehouse"
}

resource "aws_kms_key" "lakehouse" {
  description = "Lakehouse encryption key"
}
resource "aws_kms_alias" "lakehouse" {
  name          = "alias/lakehouse"
  target_key_id = aws_kms_key.lakehouse.key_id
}

resource "aws_secretsmanager_secret" "demo" {
  name = "lakehouse/demo-credentials"
}
resource "aws_secretsmanager_secret_version" "demo" {
  secret_id     = aws_secretsmanager_secret.demo.id
  secret_string = jsonencode({ user = "demo", password = "change-me" })
}

# A role like the one Pod Identity would give Spark on EKS (LocalStack does not enforce it).
data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}
resource "aws_iam_role" "spark" {
  name               = "lakehouse-spark"
  assume_role_policy = data.aws_iam_policy_document.assume.json
}
data "aws_iam_policy_document" "s3" {
  statement {
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket"]
    resources = [aws_s3_bucket.warehouse.arn, "${aws_s3_bucket.warehouse.arn}/*"]
  }
}
resource "aws_iam_role_policy" "spark_s3" {
  name   = "warehouse-access"
  role   = aws_iam_role.spark.id
  policy = data.aws_iam_policy_document.s3.json
}

output "bucket" { value = aws_s3_bucket.warehouse.bucket }
