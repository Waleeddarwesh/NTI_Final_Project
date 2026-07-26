###############################################################################
# EKS Cluster Security Group
#
# Attached to the EKS control plane ENIs. Controls traffic between the
# control plane and worker nodes.
###############################################################################

resource "aws_security_group" "eks_cluster" {
  name_prefix = "${var.project_name}-${var.environment}-eks-cluster-"
  description = "EKS control plane security group"
  vpc_id      = var.vpc_id

  tags = merge(
    var.extra_tags,
    {
      Name = "${var.project_name}-${var.environment}-eks-cluster-sg"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# Control plane -> nodes: kubelet and extension API servers
resource "aws_security_group_rule" "cluster_egress_to_nodes" {
  type                     = "egress"
  from_port                = 1025
  to_port                  = 65535
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks_cluster.id
  source_security_group_id = aws_security_group.eks_nodes.id
  description               = "Control plane to node kubelet/extension API"
}

# Nodes -> control plane: HTTPS API server
resource "aws_security_group_rule" "cluster_ingress_https_from_nodes" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks_cluster.id
  source_security_group_id = aws_security_group.eks_nodes.id
  description               = "Node kubelet/kube-proxy to control plane API"
}

###############################################################################
# EKS Node Security Group
#
# Attached to worker node ENIs. Controls node-to-node and node-to-control
# plane traffic.
###############################################################################

resource "aws_security_group" "eks_nodes" {
  name_prefix = "${var.project_name}-${var.environment}-eks-nodes-"
  description = "EKS worker node security group"
  vpc_id      = var.vpc_id

  tags = merge(
    var.extra_tags,
    {
      Name                                                                = "${var.project_name}-${var.environment}-eks-nodes-sg"
      "kubernetes.io/cluster/${var.project_name}-${var.environment}-eks" = "owned"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# Nodes <-> nodes: all traffic (pod-to-pod, including CNI overlay)
resource "aws_security_group_rule" "nodes_ingress_self" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "-1"
  security_group_id        = aws_security_group.eks_nodes.id
  source_security_group_id = aws_security_group.eks_nodes.id
  description               = "Node to node, all ports (pod networking)"
}

# Control plane -> nodes: kubelet and extension API servers
resource "aws_security_group_rule" "nodes_ingress_from_cluster" {
  type                     = "ingress"
  from_port                = 1025
  to_port                  = 65535
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks_nodes.id
  source_security_group_id = aws_security_group.eks_cluster.id
  description               = "Control plane to node kubelet/extension API"
}

# Control plane -> nodes: HTTPS for managed add-ons / webhook calls
resource "aws_security_group_rule" "nodes_ingress_https_from_cluster" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks_nodes.id
  source_security_group_id = aws_security_group.eks_cluster.id
  description               = "Control plane to node HTTPS (webhooks, add-ons)"
}

# Nodes -> anywhere: needed for pulling images, calling AWS APIs, etc.
resource "aws_security_group_rule" "nodes_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.eks_nodes.id
  cidr_blocks       = ["0.0.0.0/0"]
  description        = "Node outbound, all traffic"
}

###############################################################################
# Jenkins EC2 Security Group
###############################################################################

resource "aws_security_group" "jenkins" {
  name_prefix = "${var.project_name}-${var.environment}-jenkins-"
  description = "Jenkins EC2 instance security group"
  vpc_id      = var.vpc_id

  tags = merge(
    var.extra_tags,
    {
      Name = "${var.project_name}-${var.environment}-jenkins-sg"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "jenkins_ingress_ssh" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  security_group_id = aws_security_group.jenkins.id
  cidr_blocks       = var.jenkins_allowed_cidrs
  description        = "SSH access to Jenkins host"
}

resource "aws_security_group_rule" "jenkins_ingress_ui" {
  type              = "ingress"
  from_port         = 8080
  to_port           = 8080
  protocol          = "tcp"
  security_group_id = aws_security_group.jenkins.id
  cidr_blocks       = var.jenkins_allowed_cidrs
  description        = "Jenkins web UI"
}

resource "aws_security_group_rule" "jenkins_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.jenkins.id
  cidr_blocks       = ["0.0.0.0/0"]
  description        = "Jenkins outbound, all traffic (package installs, ECR push, EKS API, GitHub webhooks)"
}

###############################################################################
# RDS Security Group
#
# No public ingress. Only the EKS node SG and Jenkins SG (for migrations/
# admin tasks) may reach Postgres.
###############################################################################

resource "aws_security_group" "rds" {
  name_prefix = "${var.project_name}-${var.environment}-rds-"
  description = "RDS Postgres security group"
  vpc_id      = var.vpc_id

  tags = merge(
    var.extra_tags,
    {
      Name = "${var.project_name}-${var.environment}-rds-sg"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "rds_ingress_from_nodes" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = aws_security_group.rds.id
  source_security_group_id = aws_security_group.eks_nodes.id
  description               = "Postgres from EKS worker nodes"
}

resource "aws_security_group_rule" "rds_ingress_from_jenkins" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = aws_security_group.rds.id
  source_security_group_id = aws_security_group.jenkins.id
  description               = "Postgres from Jenkins (migrations, admin tasks)"
}

resource "aws_security_group_rule" "rds_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.rds.id
  cidr_blocks       = ["0.0.0.0/0"]
  description        = "RDS outbound, all traffic"
}
