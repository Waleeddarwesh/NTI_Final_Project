output "eks_cluster_security_group_id" {
  description = "Security group ID attached to the EKS control plane"
  value       = aws_security_group.eks_cluster.id
}

output "eks_nodes_security_group_id" {
  description = "Security group ID attached to EKS worker nodes"
  value       = aws_security_group.eks_nodes.id
}

output "jenkins_security_group_id" {
  description = "Security group ID attached to the Jenkins EC2 instance"
  value       = aws_security_group.jenkins.id
}

output "rds_security_group_id" {
  description = "Security group ID attached to the RDS instance"
  value       = aws_security_group.rds.id
}
