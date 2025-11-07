# Jenkins ↔ Terraform on AWS: Ubuntu EC2 + Auto-Generated PEM

This repository provisions **one Ubuntu 22.04 LTS EC2 instance** in your **default VPC** using Terraform, via a **Jenkins Declarative Pipeline**.
It **generates an SSH keypair automatically** (no console click needed), uploads the **public key** to AWS as an EC2 key pair, and saves the **private key** (`jenkins-ec2.pem`) locally so you can download it from Jenkins artifacts and SSH into the instance.

> For POC only: the private key is sensitive. Guard the Jenkins job and artifacts.

---

## What’s included
- `Jenkinsfile` with stages: **fmt → validate → plan → approval → apply → test → archive PEM → destroy**
- Terraform that:
  - Finds **Ubuntu 22.04 LTS (Jammy) amd64** AMI (Canonical owner)
  - Generates an **SSH keypair** (`tls_private_key`)
  - Creates **EC2 key pair** from the public key
  - Saves the **private key** to `terraform/jenkins-ec2.pem` (mode `0600`)
  - Creates Security Group with SSH restricted by CIDR
- **JUnit** test: verifies the instance is **running**

---

## Prerequisites
On the Jenkins node:
- Jenkins 2.440+
- Plugins: Pipeline, Git, ANSI Color, Timestamper, JUnit, Credentials Binding
- Git CLI
- Terraform 1.5+
- AWS CLI v2
- Internet access

**Jenkins credential (AWS):**
- Kind: **Username with password**
- ID: `aws-creds`
- Username: **AWS Access Key ID**
- Password: **AWS Secret Access Key**

**IAM (demo-minimal):**
```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect":"Allow",
    "Action":[
      "ec2:RunInstances","ec2:TerminateInstances","ec2:DescribeInstances",
      "ec2:CreateTags","ec2:DescribeImages","ec2:DescribeVpcs","ec2:DescribeSubnets",
      "ec2:DescribeSecurityGroups","ec2:CreateSecurityGroup","ec2:AuthorizeSecurityGroupIngress",
      "ec2:RevokeSecurityGroupIngress","ec2:DeleteSecurityGroup","ec2:CreateKeyPair","ec2:DeleteKeyPair"
    ],
    "Resource":"*"
  }]
}
```

---

## Repo layout
```
.
├── Jenkinsfile
├── README.md
└── terraform
    ├── main.tf
    ├── variables.tf
    └── outputs.tf
```

---

## Jenkins job setup
1. Push this project to GitHub.
2. In Jenkins: **New Item → Pipeline** → *Pipeline script from SCM* → Git URL → Branch `*/main` → Script Path `Jenkinsfile` → **Save**.

**Parameters when building:**
- `ACTION`: `plan | apply | destroy`
- `AUTO_APPROVE`: `true/false`
- `AWS_REGION`: e.g., `ap-south-1`
- `INSTANCE_TYPE`: e.g., `t3.micro`
- `SSH_INGRESS_CIDR`: your `/32` for safety, e.g., `203.0.113.10/32`
- `TAGS_JSON`: JSON map for tags

---

## After Apply: get your PEM
The pipeline **archives** `terraform/jenkins-ec2.pem`. In the Jenkins build page:
- Click **Artifacts** → download `jenkins-ec2.pem`.
- Fix permissions locally:
  ```bash
  chmod 600 jenkins-ec2.pem
  ```
- SSH into the VM:
  ```bash
  ssh -i jenkins-ec2.pem ubuntu@<PUBLIC_IP>
  ```

> The default username on Ubuntu is **ubuntu**.

---

## Test cases
1. **Fmt/Validate fail**: Break formatting/syntax and re-run; watch `Fmt Check` / `Validate` fail.
2. **Plan success**: `ACTION=plan` → plan file archived.
3. **Apply & test**: `ACTION=apply` → test verifies instance is `running`; PEM is archived.
4. **Destroy**: `ACTION=destroy` cleans up EC2 + SG + KeyPair. (PEM stays in Jenkins artifacts; delete old artifacts manually if needed.)

---

## Cost
Assume charges may apply. Always destroy after testing.
