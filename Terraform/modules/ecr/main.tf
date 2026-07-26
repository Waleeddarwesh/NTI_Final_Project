###############################################################################
# ECR Repositories
#
# One repository per name in var.repository_names. Using for_each rather
# than count so that adding a new repo name doesn't shift indices and cause
# Terraform to destroy-and-recreate existing repos.
###############################################################################

resource "aws_ecr_repository" "this" {
  for_each = toset(var.repository_names)

  name                 = "${var.project_name}/${each.key}"
  image_tag_mutability = var.image_tag_mutability

  image_scanning_configuration {
    scan_on_push = var.scan_on_push
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = merge(
    var.extra_tags,
    {
      Name = "${var.project_name}/${each.key}"
    }
  )
}

###############################################################################
# Lifecycle Policies
#
# Applied per-repository. Two rules:
#   1. Delete untagged images older than N days (untagged = build debris from
#      every push that replaces a mutable tag like `latest`)
#   2. Limit total tagged images per repo to N (oldest deleted first)
#
# Rules are evaluated in priority order (lower number = evaluated first).
###############################################################################

resource "aws_ecr_lifecycle_policy" "this" {
  for_each   = toset(var.repository_names)
  repository = aws_ecr_repository.this[each.key].name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Remove untagged images older than ${var.untagged_image_retention_days} days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = var.untagged_image_retention_days
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Keep only the ${var.tagged_image_count_limit} most recent tagged images"
        selection = {
          tagStatus   = "tagged"
          tagPrefixList = ["v", "main", "dev", "release", "sha"]
          countType   = "imageCountMoreThan"
          countNumber = var.tagged_image_count_limit
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

###############################################################################
# Repository Resource Policy
#
# Grants the EKS node role pull access via a resource-based policy. This is
# belt-and-suspenders with the AmazonEC2ContainerRegistryReadOnly managed
# policy on the node role (Part 2) — either alone is sufficient; together
# they ensure pull works even if the node identity policy is later modified.
#
# The Jenkins role's push/pull is covered entirely by its IAM identity policy
# (Part 2, iam module) and does NOT need to be in the repository policy.
# Repository policies are an additional grant, not a replacement.
###############################################################################

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "ecr_repo_policy" {
  for_each = toset(var.repository_names)

  statement {
    sid    = "EKSNodePull"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }

    actions = [
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ecr:BatchCheckLayerAvailability",
    ]
  }
}

resource "aws_ecr_repository_policy" "this" {
  for_each   = toset(var.repository_names)
  repository = aws_ecr_repository.this[each.key].name
  policy     = data.aws_iam_policy_document.ecr_repo_policy[each.key].json
}
