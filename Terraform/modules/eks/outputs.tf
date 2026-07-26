output "cluster_id" {
  description = "EKS cluster ID"
  value       = aws_eks_cluster.this.id
}

output "cluster_name" {
  description = "EKS cluster name, used in 'aws eks update-kubeconfig --name <this>' and by the Jenkinsfile / Helm deploy steps"
  value       = aws_eks_cluster.this.name
}

output "cluster_arn" {
  description = "EKS cluster ARN"
  value       = aws_eks_cluster.this.arn
}

output "cluster_endpoint" {
  description = "EKS API server endpoint URL"
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64-encoded cluster CA certificate, required to build a kubeconfig without calling the AWS CLI"
  value       = aws_eks_cluster.this.certificate_authority[0].data
  sensitive   = true
}

output "cluster_version" {
  description = "Running Kubernetes minor version"
  value       = aws_eks_cluster.this.version
}

output "oidc_provider_arn" {
  description = "ARN of the IAM OIDC provider for this cluster, needed when wiring IRSA roles for any add-on installed later"
  value       = aws_iam_openid_connect_provider.eks_oidc.arn
}

output "oidc_provider_url" {
  description = "OIDC issuer URL without the https:// prefix, as required by IRSA trust policy conditions"
  value       = replace(aws_eks_cluster.this.identity[0].oidc[0].issuer, "https://", "")
}

output "node_group_id" {
  description = "EKS managed node group ID"
  value       = aws_eks_node_group.this.id
}

output "node_group_status" {
  description = "Current status of the managed node group (useful to check after apply, before assuming nodes are Ready in Kubernetes)"
  value       = aws_eks_node_group.this.status
}

output "cloudwatch_log_group_name" {
  description = "CloudWatch Log Group receiving EKS control plane logs"
  value       = aws_cloudwatch_log_group.eks_cluster.name
}

output "kubeconfig_command" {
  description = "Command to run locally to configure kubectl against this cluster"
  value       = "aws eks update-kubeconfig --name ${aws_eks_cluster.this.name} --region ${data.aws_region.current.name}"
}

data "aws_region" "current" {}
