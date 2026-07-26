#!/usr/bin/env bash
# update-inventory.sh
# Reads the Jenkins public IP from Terraform state and writes it into
# inventory/hosts.ini automatically — so you don't have to look it up and
# copy-paste after every terraform apply.
#
# Usage: ./scripts/update-inventory.sh
# Run from the ansible/ directory.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANSIBLE_DIR="$(dirname "$SCRIPT_DIR")"
TERRAFORM_DIR="$(dirname "$ANSIBLE_DIR")/terraform"
INVENTORY_FILE="$ANSIBLE_DIR/inventory/hosts.ini"

if [ ! -d "$TERRAFORM_DIR" ]; then
  echo "ERROR: Terraform directory not found at $TERRAFORM_DIR"
  echo "  Adjust TERRAFORM_DIR in this script if your layout differs."
  exit 1
fi

echo "Reading jenkins_public_ip from Terraform state..."
JENKINS_IP=$(terraform -chdir="$TERRAFORM_DIR" output -raw jenkins_public_ip 2>/dev/null)

if [ -z "$JENKINS_IP" ]; then
  echo "ERROR: Could not read jenkins_public_ip from Terraform output."
  echo "  Make sure terraform apply has been run and the output exists."
  exit 1
fi

echo "Jenkins IP: $JENKINS_IP"

# Replace the placeholder (or any existing IP) on the jenkins-host line
sed -i "s/ansible_host=.*/ansible_host=${JENKINS_IP}/" "$INVENTORY_FILE"

echo "Updated: $INVENTORY_FILE"
echo ""
echo "Verify with:  ansible -m ping jenkins"
