###############################################################################
# AMI Lookup
#
# Latest Amazon Linux 2023 AMI, matching the node AMI family used by EKS in
# Part 3 (Kubernetes 1.34 -> AL2023). Looked up by data source rather than
# hardcoded so this doesn't go stale or break across regions.
###############################################################################

data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

###############################################################################
# SSH Key Pair (optional)
#
# Only created if ssh_public_key is supplied. Terraform NEVER generates the
# private key here — see variable description. If left null, SSM Session
# Manager (granted via the iam module's AmazonSSMManagedInstanceCore
# attachment) is the access path instead.
###############################################################################

resource "aws_key_pair" "jenkins" {
  count = var.ssh_public_key != null ? 1 : 0

  key_name   = "${var.project_name}-${var.environment}-jenkins-key"
  public_key = var.ssh_public_key

  tags = merge(
    var.extra_tags,
    {
      Name = "${var.project_name}-${var.environment}-jenkins-key"
    }
  )
}

###############################################################################
# User Data
#
# Deliberately minimal. Installing Jenkins itself, Docker, Java, plugins,
# kubectl, Helm, and the CloudWatch Agent CONFIGURATION is Phase 2's job
# (Ansible), not Terraform's — duplicating that here would mean two systems
# fighting over the same install steps. This script only does what only
# Terraform-layer boot-time logic can do: make the host reachable for
# Ansible (Python present, SSM Agent confirmed running) and pre-seed values
# Ansible will need but that only Terraform knows (the EKS cluster name,
# baked in as an env file rather than passed by hand on every Ansible run).
###############################################################################

locals {
  user_data = <<-EOF
    #!/bin/bash
    set -euxo pipefail

    # Amazon Linux 2023 ships Python 3 and the SSM Agent by default, but
    # confirm/enable explicitly rather than assuming — this is exactly the
    # kind of "should be fine" assumption that breaks silently on AMI updates.
    dnf install -y python3 python3-pip
    systemctl enable --now amazon-ssm-agent

    # Pre-seed values Ansible (Phase 2) and the Jenkinsfile (Phase 6) will
    # both need, without requiring them to be passed by hand on every run.
    # NOTE: inner heredoc content is left-aligned at column 0 deliberately —
    # `<<EOT` (unlike Terraform's `<<-EOF` above) does not strip leading
    # whitespace, so indenting these lines would write literal leading
    # spaces into the env file and break naive `source`/parsing of it.
    mkdir -p /etc/nti-devops
    cat > /etc/nti-devops/env <<EOT
PROJECT_NAME=${var.project_name}
ENVIRONMENT=${var.environment}
EKS_CLUSTER_NAME=${var.eks_cluster_name}
AWS_REGION=${data.aws_region.current.name}
EOT

    # Marker file Ansible's playbook can check for, to confirm cloud-init
    # finished before it starts configuring Jenkins on top.
    touch /etc/nti-devops/bootstrap-complete
  EOF
}

data "aws_region" "current" {}

###############################################################################
# Jenkins EC2 Instance
###############################################################################

resource "aws_instance" "jenkins" {
  ami           = data.aws_ami.al2023.id
  instance_type = var.instance_type
  subnet_id     = var.public_subnet_id

  vpc_security_group_ids = [var.jenkins_security_group_id]
  iam_instance_profile   = var.jenkins_instance_profile_name
  key_name                = var.ssh_public_key != null ? aws_key_pair.jenkins[0].key_name : null

  associate_public_ip_address = true

  root_block_device {
    volume_size           = var.root_volume_size_gb
    volume_type            = "gp3"
    delete_on_termination = true
    encrypted              = true
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required" # IMDSv2 only, same hardening as the EKS node launch template
    http_put_response_hop_limit = 1
  }

  user_data                  = base64encode(local.user_data)
  user_data_replace_on_change = true

  tags = merge(
    var.extra_tags,
    {
      Name = "${var.project_name}-${var.environment}-jenkins"
    }
  )

  lifecycle {
    # AMI updates shouldn't force a surprise instance replacement on every
    # apply once this host is provisioned and Ansible/Jenkins state lives
    # on it — re-provisioning a configured Jenkins controller is a deliberate
    # action (new instance + restore from backup), not a side effect of
    # Amazon publishing a new AL2023 AMI.
    ignore_changes = [ami]
  }
}

###############################################################################
# Elastic IP
#
# Jenkins UI URLs and GitHub webhook configuration (Phase 6) point at a
# fixed address. Without an EIP, restarting the instance would change the
# public IP and silently break every webhook pointed at the old one.
###############################################################################

resource "aws_eip" "jenkins" {
  domain   = "vpc"
  instance = aws_instance.jenkins.id

  tags = merge(
    var.extra_tags,
    {
      Name = "${var.project_name}-${var.environment}-jenkins-eip"
    }
  )

  depends_on = [aws_instance.jenkins]
}
