###############################################################################
# irsa/lbc-irsa.tf
# IRSA (IAM Roles for Service Accounts) role for the AWS Load Balancer
# Controller. This is a Terraform SNIPPET — add it to your existing
# terraform/ root module or apply it separately after Phase 1.
#
# Prerequisites (already created by Phase 1):
#   - EKS cluster with OIDC provider (module.eks.oidc_provider_arn)
#   - VPC and public subnets with kubernetes.io/role/elb=1 tags
#
# How to use:
#   1. Copy this file into your terraform/ directory
#   2. Run: terraform init && terraform apply -target=aws_iam_role.lbc_irsa
#   3. Use the output role ARN when creating the LBC ServiceAccount
###############################################################################

# ── Data sources ──────────────────────────────────────────────────────────────

data "aws_caller_identity" "current_lbc" {}

# Fetch the OIDC provider details from the EKS cluster created in Phase 1.
# If running as a separate Terraform stack, replace these with data sources
# pointing to the correct cluster.
locals {
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.oidc_provider_url
  cluster_name      = module.eks.cluster_name
}

# ── Trust policy ──────────────────────────────────────────────────────────────

data "aws_iam_policy_document" "lbc_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.oidc_provider_arn]
    }

    # Restrict to the exact ServiceAccount the LBC chart creates in kube-system.
    # Without these conditions, ANY pod in ANY namespace in this cluster could
    # assume this role by simply using a ServiceAccount token — a major
    # privilege escalation risk.
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider_url}:sub"
      values   = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider_url}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

# ── IAM Role ──────────────────────────────────────────────────────────────────

resource "aws_iam_role" "lbc_irsa" {
  name               = "${var.project_name}-${var.environment}-lbc-irsa-role"
  assume_role_policy = data.aws_iam_policy_document.lbc_assume_role.json

  tags = merge(
    var.extra_tags,
    {
      Name      = "${var.project_name}-${var.environment}-lbc-irsa-role"
      Component = "aws-load-balancer-controller"
    }
  )
}

# ── IAM Policy ────────────────────────────────────────────────────────────────
# The LBC requires a specific set of EC2, ELB, WAF, and Shield permissions.
# Rather than maintaining a custom policy (which goes stale with each LBC
# release), we fetch the AWS-maintained policy document directly.
#
# For production: download and pin a specific version of this policy rather
# than fetching from main on every apply:
#   curl -o lbc-iam-policy.json \
#     https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v3.4.0/docs/install/iam_policy.json

data "http" "lbc_iam_policy" {
  url = "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v3.4.0/docs/install/iam_policy.json"
}

resource "aws_iam_policy" "lbc_irsa" {
  name        = "${var.project_name}-${var.environment}-lbc-irsa-policy"
  description = "IAM policy for the AWS Load Balancer Controller IRSA role"
  policy      = data.http.lbc_iam_policy.response_body
}

resource "aws_iam_role_policy_attachment" "lbc_irsa" {
  role       = aws_iam_role.lbc_irsa.name
  policy_arn = aws_iam_policy.lbc_irsa.arn
}

# ── Output ────────────────────────────────────────────────────────────────────

output "lbc_irsa_role_arn" {
  description = "ARN of the IRSA role for the AWS Load Balancer Controller. Use this when annotating the Kubernetes ServiceAccount: eks.amazonaws.com/role-arn=<this>"
  value       = aws_iam_role.lbc_irsa.arn
}
