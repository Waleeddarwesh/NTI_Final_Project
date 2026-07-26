###############################################################################
# CloudWatch Log Group for control plane logs
#
# Must exist before the cluster ships logs to it, with a name matching EKS's
# expected convention: /aws/eks/<cluster-name>/cluster
###############################################################################

resource "aws_cloudwatch_log_group" "eks_cluster" {
  name              = "/aws/eks/${var.project_name}-${var.environment}-eks/cluster"
  retention_in_days = 90

  tags = merge(
    var.extra_tags,
    {
      Name = "${var.project_name}-${var.environment}-eks-cluster-logs"
    }
  )
}

###############################################################################
# EKS Cluster (Control Plane)
###############################################################################

resource "aws_eks_cluster" "this" {
  name     = "${var.project_name}-${var.environment}-eks"
  role_arn = var.cluster_role_arn
  version  = var.kubernetes_version

  vpc_config {
    subnet_ids              = var.private_subnet_ids
    security_group_ids      = [var.cluster_security_group_id]
    endpoint_private_access = true
    endpoint_public_access  = var.endpoint_public_access
    public_access_cidrs     = var.endpoint_public_access ? var.endpoint_public_access_cidrs : null
  }

  # Authentication mode API: this cluster uses EKS Access Entries
  # (aws_eks_access_entry below) instead of the legacy aws-auth ConfigMap.
  # This avoids needing the kubernetes/helm Terraform providers (and their
  # need for a live cluster connection at plan time) just to grant RBAC.
  access_config {
    authentication_mode                         = "API"
    bootstrap_cluster_creator_admin_permissions = true
  }

  enabled_cluster_log_types = var.enable_cluster_log_types

  tags = merge(
    var.extra_tags,
    {
      Name = "${var.project_name}-${var.environment}-eks"
    }
  )

  # Log group must exist before the cluster starts trying to write to it,
  # and the cluster role's AmazonEKSClusterPolicy attachment must be in
  # place before cluster creation can succeed.
  depends_on = [
    aws_cloudwatch_log_group.eks_cluster,
  ]
}

###############################################################################
# OIDC Provider for IAM Roles for Service Accounts (IRSA)
#
# Not consumed by anything in Phase 1 yet, but cluster add-ons and most
# Kubernetes-native AWS integrations (cluster-autoscaler, ALB controller,
# external-dns, cert-manager, EBS CSI driver) all expect this to exist.
# Creating it now avoids a second apply later when those are added.
###############################################################################

data "tls_certificate" "eks_oidc" {
  url = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks_oidc" {
  url             = aws_eks_cluster.this.identity[0].oidc[0].issuer
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks_oidc.certificates[0].sha1_fingerprint]

  tags = merge(
    var.extra_tags,
    {
      Name = "${var.project_name}-${var.environment}-eks-oidc"
    }
  )
}

###############################################################################
# Launch Template for the Managed Node Group
#
# Required because AWS's auto-generated default launch template attaches
# the EKS CLUSTER security group to nodes, not a custom node security
# group: "By default, Amazon EKS applies the cluster security group to the
# instances in your node group." Without this launch template, the
# eks_nodes security group built in the security-groups module (Part 2)
# would be attached to nothing — its node-to-node and kubelet rules would
# silently do nothing. This launch template explicitly attaches
# var.node_security_group_id so those rules actually apply.
###############################################################################

resource "aws_launch_template" "node_group" {
  name_prefix = "${var.project_name}-${var.environment}-node-"

  vpc_security_group_ids = [var.node_security_group_id]

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = var.node_disk_size_gb
      volume_type            = "gp3"
      delete_on_termination = true
      encrypted              = true
    }
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required" # IMDSv2 only
    http_put_response_hop_limit = 2
  }

  tag_specifications {
    resource_type = "instance"

    tags = merge(
      var.extra_tags,
      {
        Name = "${var.project_name}-${var.environment}-eks-node"
      }
    )
  }

  tags = merge(
    var.extra_tags,
    {
      Name = "${var.project_name}-${var.environment}-node-lt"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

###############################################################################
# Managed Node Group
###############################################################################

resource "aws_eks_node_group" "this" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.project_name}-${var.environment}-node-group"
  node_role_arn   = var.node_role_arn
  subnet_ids      = var.private_subnet_ids

  capacity_type = var.node_capacity_type

  launch_template {
    id      = aws_launch_template.node_group.id
    version = aws_launch_template.node_group.latest_version
  }

  # instance_types is set here rather than in the launch template: EKS
  # allows 0-20 instance types via the node group config when the launch
  # template itself specifies none, which keeps capacity-type/instance-type
  # changes a node-group-level update instead of forcing a new launch
  # template version.
  instance_types = var.node_instance_types

  # disk_size and remote_access are NOT set here (would conflict with the
  # custom launch template above, which already defines the root volume
  # via block_device_mappings) — see aws_launch_template.node_group.

  scaling_config {
    desired_size = var.node_desired_size
    min_size     = var.node_min_size
    max_size     = var.node_max_size
  }

  update_config {
    max_unavailable = 1
  }

  labels = {
    Project     = var.project_name
    Environment = var.environment
  }

  tags = merge(
    var.extra_tags,
    {
      Name = "${var.project_name}-${var.environment}-node-group"
    }
  )

  depends_on = [
    aws_eks_cluster.this,
    aws_launch_template.node_group,
  ]

  lifecycle {
    # Node count is meant to be managed by the cluster autoscaler / HPA
    # interaction at the Kubernetes layer (Phase 4+), not fought over by
    # Terraform on every apply.
    ignore_changes = [scaling_config[0].desired_size]
  }
}

###############################################################################
# EKS Access Entries (cluster RBAC for IAM principals)
#
# The managed node group's IAM role is automatically recognized by EKS for
# node bootstrapping — no separate access entry is needed for it. Access
# entries here are for IAM principals that need to interact with the
# cluster's Kubernetes API as users/operators, not as nodes.
###############################################################################

# Jenkins needs to run kubectl/Helm against this cluster as part of the
# CI/CD pipeline (Phase 6). DescribeCluster (granted in the iam module) only
# lets Jenkins authenticate to the EKS API and fetch connection details —
# it does NOT grant any permission inside Kubernetes. This access entry is
# what actually lets Jenkins's kubectl commands succeed once connected.
resource "aws_eks_access_entry" "jenkins" {
  cluster_name  = aws_eks_cluster.this.name
  principal_arn = var.jenkins_role_arn
  type          = "STANDARD"

  tags = var.extra_tags
}

resource "aws_eks_access_policy_association" "jenkins_admin" {
  cluster_name  = aws_eks_cluster.this.name
  principal_arn = var.jenkins_role_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.jenkins]
}

# Optional extra human/admin principals (e.g. your own IAM user) for direct
# kubectl access while building and debugging this cluster.
resource "aws_eks_access_entry" "additional_admins" {
  for_each = toset(var.additional_admin_principal_arns)

  cluster_name  = aws_eks_cluster.this.name
  principal_arn = each.value
  type          = "STANDARD"

  tags = var.extra_tags
}

resource "aws_eks_access_policy_association" "additional_admins" {
  for_each = toset(var.additional_admin_principal_arns)

  cluster_name  = aws_eks_cluster.this.name
  principal_arn = each.value
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.additional_admins]
}
