output "eks_cluster_role_arn" {
  description = "ARN of the IAM role for the EKS control plane"
  value       = aws_iam_role.eks_cluster.arn
}

output "eks_cluster_role_name" {
  description = "Name of the IAM role for the EKS control plane"
  value       = aws_iam_role.eks_cluster.name
}

output "eks_node_role_arn" {
  description = "ARN of the IAM role for EKS worker nodes"
  value       = aws_iam_role.eks_node.arn
}

output "eks_node_instance_profile_name" {
  description = "Name of the instance profile attached to EKS worker nodes"
  value       = aws_iam_instance_profile.eks_node.name
}

output "jenkins_role_arn" {
  description = "ARN of the IAM role for the Jenkins EC2 instance"
  value       = aws_iam_role.jenkins.arn
}

output "jenkins_instance_profile_name" {
  description = "Name of the instance profile attached to the Jenkins EC2 instance"
  value       = aws_iam_instance_profile.jenkins.name
}
