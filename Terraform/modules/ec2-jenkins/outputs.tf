output "instance_id" {
  description = "EC2 instance ID of the Jenkins host"
  value       = aws_instance.jenkins.id
}

output "public_ip" {
  description = "Stable public (Elastic) IP of the Jenkins host — use this for GitHub webhook URLs and DNS, not the raw instance public IP, since the EIP doesn't change across instance restarts"
  value       = aws_eip.jenkins.public_ip
}

output "private_ip" {
  description = "Private IP of the Jenkins host within the VPC"
  value       = aws_instance.jenkins.private_ip
}

output "jenkins_url" {
  description = "Jenkins web UI URL, reachable once Phase 2 (Ansible) installs and starts Jenkins"
  value       = "http://${aws_eip.jenkins.public_ip}:8080"
}

output "ssh_command" {
  description = "SSH command to reach the host, if ssh_public_key was supplied. Null if relying on SSM instead."
  value       = var.ssh_public_key != null ? "ssh -i <path-to-matching-private-key> ec2-user@${aws_eip.jenkins.public_ip}" : null
}

output "ssm_command" {
  description = "SSM Session Manager command to reach the host without SSH keys or an open port 22"
  value       = "aws ssm start-session --target ${aws_instance.jenkins.id}"
}

output "key_pair_name" {
  description = "Name of the EC2 key pair created, if any (null if ssh_public_key was not supplied)"
  value       = var.ssh_public_key != null ? aws_key_pair.jenkins[0].key_name : null
}

output "ami_id" {
  description = "AMI ID actually used at creation time (pinned via ignore_changes — re-check data.aws_ami.al2023 for the current latest if planning a deliberate AMI refresh)"
  value       = data.aws_ami.al2023.id
}
