###############################################################################
# Terraform Backend Configuration
#
# Remote state is stored in S3 with DynamoDB for state locking. This bucket
# and table must exist BEFORE running `terraform init` for this config — they
# are bootstrapped once, manually or via a separate bootstrap stack, since
# Terraform cannot create the backend it is about to use.
#
# Bootstrap commands (run once, replace values as needed):
#
#   aws s3api create-bucket \
#     --bucket nti-devops-tfstate-<unique-suffix> \
#     --region us-east-1
#
#   aws s3api put-bucket-versioning \
#     --bucket nti-devops-tfstate-<unique-suffix> \
#     --versioning-configuration Status=Enabled
#
#   aws s3api put-bucket-encryption \
#     --bucket nti-devops-tfstate-<unique-suffix> \
#     --server-side-encryption-configuration \
#     '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
#
#   aws dynamodb create-table \
#     --table-name nti-devops-tfstate-lock \
#     --attribute-definitions AttributeName=LockID,AttributeType=S \
#     --key-schema AttributeName=LockID,KeyType=HASH \
#     --billing-mode PAY_PER_REQUEST
#
###############################################################################

terraform {
  backend "s3" {
    bucket         = "nti-devops-tfstate-change-me" # must be globally unique, update before init
    key            = "phase1/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "nti-devops-tfstate-lock"
    encrypt        = true
  }
}
