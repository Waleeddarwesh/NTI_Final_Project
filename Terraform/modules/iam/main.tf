###############################################################################
# EKS Cluster Role
#
# Assumed by the EKS service itself to manage the control plane on your
# behalf (ENIs, load balancers via the cluster's own AWS API calls, etc).
###############################################################################

data "aws_iam_policy_document" "eks_cluster_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "eks_cluster" {
  name               = "${var.project_name}-${var.environment}-eks-cluster-role"
  assume_role_policy = data.aws_iam_policy_document.eks_cluster_assume_role.json

  tags = merge(
    var.extra_tags,
    {
      Name = "${var.project_name}-${var.environment}-eks-cluster-role"
    }
  )
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  role       = aws_iam_role.eks_cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

###############################################################################
# EKS Node Group Role
#
# Assumed by EC2 instances that join the cluster as worker nodes. Needs the
# three standard managed policies for kubelet operation, CNI networking, and
# pulling images from ECR.
###############################################################################

data "aws_iam_policy_document" "eks_node_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "eks_node" {
  name               = "${var.project_name}-${var.environment}-eks-node-role"
  assume_role_policy = data.aws_iam_policy_document.eks_node_assume_role.json

  tags = merge(
    var.extra_tags,
    {
      Name = "${var.project_name}-${var.environment}-eks-node-role"
    }
  )
}

resource "aws_iam_role_policy_attachment" "eks_node_worker_policy" {
  role       = aws_iam_role.eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "eks_node_cni_policy" {
  role       = aws_iam_role.eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "eks_node_ecr_readonly" {
  role       = aws_iam_role.eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_instance_profile" "eks_node" {
  name = "${var.project_name}-${var.environment}-eks-node-profile"
  role = aws_iam_role.eks_node.name

  tags = merge(
    var.extra_tags,
    {
      Name = "${var.project_name}-${var.environment}-eks-node-profile"
    }
  )
}

###############################################################################
# Jenkins EC2 Role
#
# Assumed by the Jenkins EC2 instance. Scoped to exactly what the CI/CD
# pipeline (Phase 6) needs: push/pull ECR images, update kubeconfig and
# deploy to EKS, read DB credentials from Secrets Manager, and write metrics/
# logs via the CloudWatch Agent. No broad "*" actions or resources.
###############################################################################

data "aws_iam_policy_document" "jenkins_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "jenkins" {
  name               = "${var.project_name}-${var.environment}-jenkins-role"
  assume_role_policy = data.aws_iam_policy_document.jenkins_assume_role.json

  tags = merge(
    var.extra_tags,
    {
      Name = "${var.project_name}-${var.environment}-jenkins-role"
    }
  )
}

# --- ECR: push/pull images built and scanned by the pipeline ---
data "aws_iam_policy_document" "jenkins_ecr" {
  statement {
    sid    = "ECRAuth"
    effect = "Allow"
    actions = [
      "ecr:GetAuthorizationToken",
    ]
    resources = ["*"] # GetAuthorizationToken does not support resource-level restriction
  }

  statement {
    sid    = "ECRPushPull"
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ecr:PutImage",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:DescribeRepositories",
      "ecr:DescribeImages",
    ]
    resources = ["arn:aws:ecr:*:*:repository/${var.project_name}-*"]
  }
}

resource "aws_iam_policy" "jenkins_ecr" {
  name   = "${var.project_name}-${var.environment}-jenkins-ecr-policy"
  policy = data.aws_iam_policy_document.jenkins_ecr.json
}

resource "aws_iam_role_policy_attachment" "jenkins_ecr" {
  role       = aws_iam_role.jenkins.name
  policy_arn = aws_iam_policy.jenkins_ecr.arn
}

# --- EKS: describe cluster (for update-kubeconfig) and deploy via Helm/kubectl ---
# Note: this grants the IAM permission to call the EKS *API* (DescribeCluster).
# Actual in-cluster RBAC (what the resulting kubeconfig identity can DO inside
# Kubernetes) is granted separately via the aws-auth ConfigMap / EKS access
# entries in Phase 3 (EKS module) — IAM alone does not grant cluster permissions.
data "aws_iam_policy_document" "jenkins_eks" {
  statement {
    sid    = "EKSDescribe"
    effect = "Allow"
    actions = [
      "eks:DescribeCluster",
      "eks:ListClusters",
    ]
    resources = ["arn:aws:eks:*:*:cluster/${var.project_name}-${var.environment}-eks"]
  }
}

resource "aws_iam_policy" "jenkins_eks" {
  name   = "${var.project_name}-${var.environment}-jenkins-eks-policy"
  policy = data.aws_iam_policy_document.jenkins_eks.json
}

resource "aws_iam_role_policy_attachment" "jenkins_eks" {
  role       = aws_iam_role.jenkins.name
  policy_arn = aws_iam_policy.jenkins_eks.arn
}

# --- Secrets Manager: read DB credentials and other app secrets ---
data "aws_iam_policy_document" "jenkins_secrets" {
  statement {
    sid    = "SecretsManagerRead"
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
    ]
    resources = ["arn:aws:secretsmanager:*:*:secret:${var.project_name}-${var.environment}-*"]
  }
}

resource "aws_iam_policy" "jenkins_secrets" {
  name   = "${var.project_name}-${var.environment}-jenkins-secrets-policy"
  policy = data.aws_iam_policy_document.jenkins_secrets.json
}

resource "aws_iam_role_policy_attachment" "jenkins_secrets" {
  role       = aws_iam_role.jenkins.name
  policy_arn = aws_iam_policy.jenkins_secrets.arn
}

# --- CloudWatch Agent: ship metrics/logs from the Jenkins host (Phase 2/7) ---
resource "aws_iam_role_policy_attachment" "jenkins_cloudwatch_agent" {
  role       = aws_iam_role.jenkins.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# --- SSM Session Manager: shell access without an SSH key or open port 22.
# Added in Part 4 so ssh_public_key can be left unset entirely if preferred;
# see ec2-jenkins module for the corresponding instance-side setup. ---
resource "aws_iam_role_policy_attachment" "jenkins_ssm" {
  role       = aws_iam_role.jenkins.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "jenkins" {
  name = "${var.project_name}-${var.environment}-jenkins-profile"
  role = aws_iam_role.jenkins.name

  tags = merge(
    var.extra_tags,
    {
      Name = "${var.project_name}-${var.environment}-jenkins-profile"
    }
  )
}
