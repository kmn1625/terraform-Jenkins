# Jenkins Terraform EC2 Deployment

Simple Jenkins pipeline to deploy Ubuntu EC2 instances on AWS using Terraform.

## 📋 Prerequisites

1. **Jenkins** with the following plugins:
   - Pipeline plugin
   - Git plugin
   - Credentials Binding plugin

2. **Terraform** installed on Jenkins agent (version >= 1.5.0)
   ```bash
   # Install on Jenkins server/agent
   wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip
   unzip terraform_1.6.0_linux_amd64.zip
   sudo mv terraform /usr/local/bin/
   terraform version
   ```

3. **AWS Credentials** configured in Jenkins

## 🔐 Setup AWS Credentials in Jenkins

1. Go to **Jenkins → Manage Jenkins → Credentials**
2. Click **(global)** domain → **Add Credentials**
3. Select **Username with password**
4. Fill in:
   - **Username**: Your AWS Access Key ID
   - **Password**: Your AWS Secret Access Key
   - **ID**: `aws-creds` (must match the Jenkinsfile)
   - **Description**: AWS Credentials
5. Click **Create**

## 📁 Project Structure

```
.
├── Jenkinsfile                 # Simple pipeline (recommended)
├── Jenkinsfile-with-params     # Pipeline with parameters (optional)
├── README.md
└── terraform/
    ├── main.tf                 # Main Terraform config
    └── variables.tf            # Variable definitions
```

## 🚀 Quick Start

### Option 1: Simple Pipeline (Recommended)

1. **Create Jenkins Pipeline Job**:
   - New Item → Pipeline
   - Name: `Deploy-EC2-Terraform`
   - Pipeline Definition: **Pipeline script from SCM**
   - SCM: Git
   - Repository URL: `<your-repo-url>`
   - Script Path: `Jenkinsfile`

2. **Configure Settings** (Optional):
   Edit `Jenkinsfile` environment section:
   ```groovy
   environment {
     AWS_REGION        = 'ap-south-1'      # Your AWS region
     INSTANCE_TYPE     = 't3.micro'        # Instance size
     SSH_INGRESS_CIDR  = '0.0.0.0/0'       # Change to YOUR_IP/32 for security!
   }
   ```

3. **Run the Pipeline**:
   - Click **Build Now**
   - Pipeline will:
     - ✅ Initialize Terraform
     - ✅ Validate configuration
     - ✅ Create execution plan
     - ⏸️ Wait for your approval
     - ✅ Deploy EC2 instance
     - 📦 Archive PEM file

4. **Download PEM File**:
   - Go to build → **Build Artifacts**
   - Download `jenkins-ec2.pem`

5. **Connect to EC2**:
   ```bash
   chmod 600 jenkins-ec2.pem
   ssh -i jenkins-ec2.pem ubuntu@<public-ip>
   ```

### Option 2: Pipeline with Parameters

1. Use `Jenkinsfile-with-params` (rename to `Jenkinsfile`)
2. This gives you:
   - Choice between: Apply / Plan-only / Destroy
   - Instance type selection
   - Custom SSH CIDR
   - Auto-approve option

## 🔧 What Gets Created

- ✅ Ubuntu 22.04 LTS EC2 instance
- ✅ Security Group (SSH access on port 22)
- ✅ SSH Key Pair (auto-generated)
- ✅ Public IP assigned
- ✅ PEM file for SSH access

## 📝 Key Changes from Original

### Issues Fixed:

1. **Validate Stage Hanging**:
   - ❌ Before: No credentials in validate stage
   - ✅ Fixed: Added AWS credentials and env vars

2. **Wrong `when` Condition**:
   - ❌ Before: `environment name: 'ACTION'` (doesn't work for parameters)
   - ✅ Fixed: `expression { params.ACTION == 'apply' }`

3. **Missing Variables in Apply/Destroy**:
   - ❌ Before: Only AWS credentials, missing TF_VAR_* exports
   - ✅ Fixed: All required variables exported

4. **Over-complicated**:
   - ❌ Before: Multiple unnecessary parameters for simple deployment
   - ✅ Fixed: Simplified pipeline for single purpose

### Improvements:

- 📦 Combined all outputs in main.tf (cleaner)
- 🔐 Better security group with name_prefix
- 📊 Plan output saved as artifact
- 🎯 Clear stage names and logging
- 🔄 Proper error handling with `set -e`
- 📝 Better user feedback and instructions

## 🔒 Security Recommendations

1. **IMPORTANT**: Change `SSH_INGRESS_CIDR` from `0.0.0.0/0` to your IP:
   ```groovy
   SSH_INGRESS_CIDR = 'YOUR_IP/32'  # e.g., '203.0.113.45/32'
   ```

2. Get your public IP:
   ```bash
   curl ifconfig.me
   ```

3. Use the `/32` CIDR notation for single IP

## 🧹 Cleanup

To destroy the EC2 instance:

**Simple Pipeline**: Run the destroy pipeline job (if created)

**With Parameters**: Select `destroy` action and run

**Manual Cleanup**:
```bash
cd terraform/
terraform destroy -auto-approve
```

## 📚 AWS Resources Created

| Resource | Name | Purpose |
|----------|------|---------|
| EC2 Instance | jenkins-terraform-ubuntu-vm | Your VM |
| Security Group | jenkins-tf-ec2-sg | Firewall rules |
| Key Pair | jenkins-ec2-key-* | SSH authentication |

## 🐛 Troubleshooting

### Pipeline Stuck at Validate
- ✅ Fixed in new Jenkinsfile
- Ensure AWS credentials are properly configured

### Cannot SSH to Instance
```bash
# Check permissions
chmod 600 jenkins-ec2.pem

# Verify security group allows your IP
# Check in AWS Console: EC2 → Security Groups
```

### Terraform Init Fails
```bash
# On Jenkins agent, clear cache:
rm -rf .terraform .terraform.lock.hcl
```

### PEM File Not in Artifacts
- Check Apply stage completed successfully
- Look in: Build → Build Artifacts section

## 📊 Pipeline Stages Explained

1. **Checkout**: Gets code from Git
2. **Prepare**: Creates necessary directories
3. **Init**: Downloads Terraform providers
4. **Format**: Auto-formats Terraform files
5. **Validate**: Checks configuration syntax
6. **Plan**: Creates execution plan
7. **Approval**: Manual gate (review before deploy)
8. **Apply**: Creates AWS resources
9. **Post**: Archives PEM file

## 💡 Tips

- First run takes ~5 minutes
- Always review the plan before approving
- PEM file is sensitive - keep it secure
- Instance costs ~$0.0116/hour (t3.micro in ap-south-1)
- Remember to destroy when done testing!

## 📞 Need Help?

- Check Jenkins console output for errors
- Verify AWS credentials in Jenkins
- Ensure Terraform is in PATH on Jenkins agent
- Check AWS service limits in your region

## 🎯 Quick Commands

```bash
# Get your IP for SSH restriction
curl ifconfig.me

# Connect to instance
ssh -i jenkins-ec2.pem ubuntu@<public-ip>

# Check instance in AWS
aws ec2 describe-instances --filters "Name=tag:Name,Values=jenkins-terraform-ubuntu-vm"
```

---

**Created by**: Jenkins + Terraform Pipeline  
**Last Updated**: 2025
