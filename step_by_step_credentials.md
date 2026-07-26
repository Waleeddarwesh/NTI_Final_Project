# 🔑 Step-by-Step: How to Get Every Credential

Follow these steps **in order**. Each step tells you exactly what to click, what to type, and where to paste the result.

---

## Step 1 — Get AWS Access Key & Secret Key

You need an AWS IAM user with programmatic access.

### If you DON'T have an IAM user yet:

1. Go to **[AWS Console](https://console.aws.amazon.com/)** → Sign in
2. Search for **IAM** in the top search bar → Click **IAM**
3. Left sidebar → Click **Users**
4. Click **Create user**
5. **User name:** `your name`
6. Click **Next**
7. **Set permissions:**
   - Select **Attach policies directly**
   - Search for `AdministratorAccess`
   - ✅ Check the box next to it
8. Click **Next** → **Create user**

### Create Access Key:

1. Still in **IAM** → **Users** → Click your user name
2. Click the **Security credentials** tab
3. Scroll down to **Access keys**
4. Click **Create access key**
5. Select **Command Line Interface (CLI)**
6. ✅ Check the confirmation checkbox at the bottom
7. Click **Next** → **Create access key**
8. 🔴 **IMPORTANT:** You will see:
   - **Access key ID:** something like `AKIAIOSFODNN7EXAMPLE`
   - **Secret access key:** something like `wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY`
9. **Copy both values** or click **Download .csv file** — you will NEVER see the secret key again!

### Configure your machine:

Open a terminal and run:

```bash
aws configure
```

Paste when prompted:

```
AWS Access Key ID [None]: AKIAIOSFODNN7EXAMPLE        ← paste your Access Key ID
AWS Secret Access Key [None]: wJalrXUtnFEMI/K7MD...   ← paste your Secret Access Key
Default region name [None]: us-east-1
Default output format [None]: json
```

### ✅ Verify it works:

```bash
aws sts get-caller-identity
```

You should see your account ID and user ARN:
```json
{
    "UserId": "AIDAEXAMPLE",
    "Account": "123456789012",
    "Arn": "arn:aws:iam::123456789012:user/walid-devops"
}
```

> **📝 Save your Account ID** (the 12-digit number) and your **ARN** — you'll need them in Step 4.

---

## Step 2 — Generate SSH Key Pair

This key lets Ansible connect to the Jenkins EC2 instance.

### Run this command:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/nti-devops-jenkins -C jenkins
```

When prompted:
```
Enter passphrase (empty for no passphrase):     ← just press Enter (no password)
Enter same passphrase again:                     ← press Enter again
```

### Get the public key content:

**On Windows (PowerShell):**
```powershell
Get-Content ~/.ssh/nti-devops-jenkins.pub
```

**On Linux/Mac:**
```bash
cat ~/.ssh/nti-devops-jenkins.pub
```

You'll see something like:
```
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx jenkins
```

> **📝 Copy the entire line** — you'll paste it in Step 4.

---

## Step 3 — Create S3 Bucket for Terraform State

### Pick a unique bucket name:

S3 bucket names are **globally unique**. Pick something like: `nti-devops-tfstate-walid-2026`

### Run these 3 commands:

```bash
# 1. Create the bucket
aws s3api create-bucket \
  --bucket nti-devops-tfstate-walid-2026 \
  --region us-east-1

# 2. Enable versioning
aws s3api put-bucket-versioning \
  --bucket nti-devops-tfstate-walid-2026 \
  --versioning-configuration Status=Enabled

# 3. Create DynamoDB lock table
aws dynamodb create-table \
  --table-name nti-devops-tfstate-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST
```

### ✅ Verify:

```bash
aws s3 ls | grep nti-devops
```

You should see your bucket listed.

> **📝 Remember your bucket name** — you'll use it in Step 4.

---

## Step 4 — Find Your Public IP Address

1. Open your browser
2. Go to **[https://whatismyip.com](https://whatismyip.com)**
3. Copy the **IPv4 address** shown (e.g., `41.44.xxx.xxx`)

> **📝 Save this IP** — you'll use it as `YOUR_IP/32` in the next step.

---

## Step 5 — Edit Terraform Configuration Files

Now paste all the credentials you've collected into the Terraform files.

### File 1: `Terraform/backend.tf`

Open the file and change **line 34**:

```diff
- bucket = "nti-devops-tfstate-change-me"
+ bucket = "nti-devops-tfstate-walid-2026"   ← your bucket name from Step 3
```

### File 2: `Terraform/terraform.tfvars`

Open the file and change these lines:

**Line 25** — Restrict Jenkins access to your IP:
```diff
- jenkins_allowed_cidrs = ["0.0.0.0/0"]
+ jenkins_allowed_cidrs = ["41.44.xxx.xxx/32"]   ← your IP from Step 4
```

**Line 31** — Add your IAM ARN for kubectl access:
```diff
- eks_additional_admin_principal_arns = []
+ eks_additional_admin_principal_arns = ["arn:aws:iam::123456789012:user/walid-devops"]
```
↑ Use the ARN you got from `aws sts get-caller-identity` in Step 1.

**Line 43** — Restrict EKS API access to your IP:
```diff
- eks_endpoint_public_access_cidrs = ["0.0.0.0/0"]
+ eks_endpoint_public_access_cidrs = ["41.44.xxx.xxx/32"]   ← your IP from Step 4
```

**Line 53** — Paste your SSH public key:
```diff
- jenkins_ssh_public_key = null
+ jenkins_ssh_public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHxxx... jenkins"
```
↑ Paste the entire output from Step 2.

---

## Step 6 — Run Terraform (Provisions Everything)

```bash
cd Terraform
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

⏱ **Wait ~15–20 minutes** (EKS cluster takes the longest).

When it finishes, save the outputs:

```bash
# Get Jenkins IP (you'll need this for Step 7)
terraform output jenkins_public_ip

# Get your AWS Account ID
terraform output -raw aws_account_id
```

> **📝 Save the Jenkins IP** — you'll need it for Ansible, Jenkins webhooks, and more.

---

## Step 7 — Set Jenkins IP in Ansible Inventory

### Option A — Automatic (recommended):

```bash
cd ansible
./scripts/update-inventory.sh
```

### Option B — Manual:

Edit `ansible/inventory/hosts.ini` **line 13**:

```diff
- jenkins-host ansible_host=REPLACE_WITH_JENKINS_IP
+ jenkins-host ansible_host=3.91.xxx.xxx   ← Jenkins IP from Step 6
```

Also verify **line 17** points to your SSH key:
```ini
ansible_ssh_private_key_file=~/.ssh/nti-devops-jenkins
```

---

## Step 8 — Run Ansible (Installs Jenkins)

```bash
cd ansible
ansible-playbook playbooks/site.yml
```

⏱ **Wait ~5–10 minutes**.

### ✅ Verify:

```bash
ansible-playbook playbooks/verify.yml
```

### Get Jenkins initial admin password:

After Ansible finishes, SSH into Jenkins to get the initial password:

```bash
ssh -i ~/.ssh/nti-devops-jenkins ec2-user@<JENKINS_IP>
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

This gives you a long string like: `a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6`

> **📝 Copy this password** — use it to log into Jenkins UI for the first time.

---

## Step 9 — Generate Django SECRET_KEY (for local Docker testing)

```bash
cd docker
cp .env.example .env
```

Generate a secret key:

**Option A — With Python:**
```bash
python -c "from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())"
```

**Option B — Without Django installed:**
```bash
python -c "import secrets; print(secrets.token_urlsafe(50))"
```

Edit `docker/.env` and paste the key:

```diff
- SECRET_KEY=replace-with-output-of-get-random-secret-key
+ SECRET_KEY=abc123xyz-your-generated-key-here
```

All other values in `.env` can stay as-is for local development.

---

## Step 10 — Connect kubectl to EKS

```bash
aws eks update-kubeconfig --name nti-devops-dev-eks --region us-east-1
```

### ✅ Verify:

```bash
kubectl get nodes
```

Expected output:
```
NAME                             STATUS   ROLES    AGE   VERSION
ip-10-0-10-xxx.ec2.internal     Ready    <none>   20m   v1.34.x
ip-10-0-11-xxx.ec2.internal     Ready    <none>   20m   v1.34.x
```

---

## Step 11 — Install EKS Cluster Add-ons

These are needed before deploying the app or monitoring:

```bash
# 1. EBS CSI Driver (needed for Prometheus/Grafana storage)
aws eks create-addon \
  --cluster-name nti-devops-dev-eks \
  --addon-name aws-ebs-csi-driver

# 2. Metrics Server (needed for HPA autoscaling)
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
helm install metrics-server metrics-server/metrics-server \
  -n kube-system \
  -f helm/releases/metrics-server-values.yaml

# 3. AWS Load Balancer Controller IRSA (Terraform)
cd helm/irsa
terraform init
terraform apply

# 4. AWS Load Balancer Controller (Helm)
helm repo add eks https://aws.github.io/eks-charts
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  -f helm/releases/aws-load-balancer-controller-values.yaml
```

---

## Step 12 — Set Up SonarQube + Get Token

You have two options:

### Option A — Run SonarQube on Jenkins EC2 (easiest):

```bash
# SSH into Jenkins
ssh -i ~/.ssh/nti-devops-jenkins ec2-user@<JENKINS_IP>

# Run SonarQube as a Docker container
docker run -d --name sonarqube -p 9000:9000 sonarqube:lts-community
```

Wait ~2 minutes, then open: `http://<JENKINS_IP>:9000`

- **Default login:** `admin` / `admin`
- It will ask you to change the password → change it and remember it

### Option B — Use SonarCloud (free for public repos):

1. Go to [https://sonarcloud.io](https://sonarcloud.io)
2. Sign in with GitHub
3. Import your repo
4. Skip — you already have `sonar-project.properties`

### Generate the SonarQube Token:

1. In SonarQube UI → Click your profile icon (top-right) → **My Account**
2. Click **Security** tab
3. Under **Generate Tokens:**
   - **Name:** `jenkins`
   - **Type:** `Global Analysis Token`
   - Click **Generate**
4. 🔴 **Copy the token** (starts with `squ_` or `sqp_`) — you will NEVER see it again!

> **📝 Save this token** — you'll paste it into Jenkins in the next step.

---

## Step 13 — Configure Jenkins Credentials

Open Jenkins UI: `http://<JENKINS_IP>:8080`

### 13a. Add SonarQube Token

1. **Manage Jenkins** → **Credentials**
2. Click **(global)** under **Stores scoped to Jenkins**
3. Click **Add Credentials**
4. Fill in:
   - **Kind:** `Secret text`
   - **Secret:** paste your SonarQube token from Step 12
   - **ID:** `sonarqube-token` ← must be exactly this
   - **Description:** `SonarQube analysis token`
5. Click **Create**

### 13b. Configure SonarQube Server in Jenkins

1. **Manage Jenkins** → **System**
2. Scroll down to **SonarQube servers**
3. Click **Add SonarQube**
4. Fill in:
   - **Name:** `SonarQube` ← must be exactly this (capital S, capital Q)
   - **Server URL:** `http://<JENKINS_IP>:9000` (or your SonarCloud URL)
   - **Server authentication token:** select `sonarqube-token` from dropdown
5. Click **Save**

---

## Step 14 — Set Up GitHub Webhook

1. Go to your **GitHub repository** page
2. Click **Settings** tab
3. Left sidebar → **Webhooks**
4. Click **Add webhook**
5. Fill in:
   - **Payload URL:** `http://<JENKINS_IP>:8080/github-webhook/`
   - **Content type:** `application/json`
   - **Secret:** (leave empty)
   - **Which events:** Select `Just the push event`
6. Click **Add webhook**

### ✅ Verify:

GitHub shows a ✅ green checkmark next to the webhook after a few seconds.

---

## Step 15 — Set Up SonarQube Webhook

This tells SonarQube to notify Jenkins when the quality gate result is ready.

1. Open SonarQube: `http://<JENKINS_IP>:9000`
2. Go to **Administration** → **Configuration** → **Webhooks**
3. Click **Create**
4. Fill in:
   - **Name:** `Jenkins`
   - **URL:** `http://<JENKINS_IP>:8080/sonarqube-webhook/`
   - **Secret:** (leave empty)
5. Click **Create**

---

## Step 16 — Set Grafana Password & Slack Webhook

### 16a. Grafana Admin Password

Edit `monitoring/kube-prometheus-stack-values.yaml` **line 151**:

```diff
- adminPassword: "REPLACE_WITH_SECURE_PASSWORD"
+ adminPassword: "YourStr0ngP@ssword!"
```

### 16b. Slack Webhook (optional)

If you want alert notifications in Slack:

1. Go to [https://api.slack.com/apps](https://api.slack.com/apps)
2. Click **Create New App** → **From scratch**
3. **App Name:** `NTI DevOps Alerts` → Pick your workspace → **Create App**
4. Left sidebar → **Incoming Webhooks** → Toggle **ON**
5. Click **Add New Webhook to Workspace**
6. Pick channel `#nti-devops-alerts` → **Allow**
7. Copy the **Webhook URL** (starts with `https://hooks.slack.com/services/...`)

Edit `monitoring/kube-prometheus-stack-values.yaml` **line 86**:

```diff
- slack_api_url: "https://hooks.slack.com/services/REPLACE/WITH/REAL_WEBHOOK"
+ slack_api_url: "https://hooks.slack.com/services/T0XXXXX/B0XXXXX/XXXXXXXXXX"
```

> **💡 No Slack?** That's fine — just leave the placeholder. Alerts will still show in the Alertmanager UI at `http://localhost:9093` (via port-forward). You won't get push notifications but monitoring still works.

---

## Step 17 — Deploy Monitoring Stack

```bash
cd monitoring
./install/install.sh
```

When prompted "Deploy monitoring to this cluster? [y/N]" → type `y`

### ✅ Access Grafana:

```bash
kubectl port-forward svc/kube-prometheus-stack-grafana 3000:80 -n monitoring
```

Open: `http://localhost:3000`
- **Username:** `admin`
- **Password:** whatever you set in Step 16a

---

## ✅ Final Checklist

| # | Credential | Got It? |
|---|---|---|
| 1 | AWS Access Key + Secret Key | ☐ |
| 2 | SSH Key Pair (~/.ssh/nti-devops-jenkins) | ☐ |
| 3 | S3 Bucket Name (for Terraform state) | ☐ |
| 4 | Your Public IP Address | ☐ |
| 5 | Edited `backend.tf` with bucket name | ☐ |
| 6 | Edited `terraform.tfvars` (IP, SSH key, IAM ARN) | ☐ |
| 7 | Ran `terraform apply` successfully | ☐ |
| 8 | Jenkins IP in Ansible inventory | ☐ |
| 9 | Ran `ansible-playbook` successfully | ☐ |
| 10 | Django SECRET_KEY in `docker/.env` | ☐ |
| 11 | kubectl connected to EKS | ☐ |
| 12 | Cluster add-ons installed (EBS CSI, Metrics Server, LBC) | ☐ |
| 13 | SonarQube running + token generated | ☐ |
| 14 | SonarQube token added to Jenkins credentials | ☐ |
| 15 | SonarQube server configured in Jenkins | ☐ |
| 16 | GitHub webhook created | ☐ |
| 17 | SonarQube webhook created | ☐ |
| 18 | Grafana password set in values file | ☐ |
| 19 | Slack webhook set (optional) | ☐ |
| 20 | Monitoring stack deployed | ☐ |

---

## 💰 Cost Warning

> [!CAUTION]
> This project creates **real AWS resources that cost money**:
> - **EKS cluster:** ~$0.10/hr ($72/month)
> - **2x t3.medium nodes:** ~$0.083/hr ($60/month)
> - **t3.large Jenkins:** ~$0.083/hr ($60/month)
> - **RDS db.t3.micro:** ~$0.018/hr ($13/month)
> - **NAT Gateway:** ~$0.045/hr ($32/month)
> - **Total estimate:** ~$240/month
>
> **To avoid charges when done testing:**
> ```bash
> cd Terraform
> terraform destroy
> ```
> Also manually delete the S3 state bucket and DynamoDB table if no longer needed.
