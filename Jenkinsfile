pipeline {
  agent any

  options {
    timestamps()
    buildDiscarder(logRotator(numToKeepStr: '10'))
  }

  environment {
    TF_IN_AUTOMATION     = 'true'
    TF_WORKDIR           = 'terraform'
    AWS_REGION           = 'ap-south-1'
    INSTANCE_TYPE        = 't3.micro'
    SSH_INGRESS_CIDR     = '0.0.0.0/0'  // TODO: change to your IP/32 for security
    TF_PLUGIN_CACHE_DIR  = "${WORKSPACE}/.terraform.d/plugin-cache"
    PLAN_FILE            = 'tfplan.out'
  }

  stages {

    stage('Checkout') {
      options { timeout(time: 2, unit: 'MINUTES') }
      steps {
        echo '=== Checking out code ==='
        checkout scm
      }
    }

    stage('Prepare') {
      options { timeout(time: 1, unit: 'MINUTES') }
      steps {
        echo '=== Preparing workspace ==='
        sh '''
          set -e
          mkdir -p "${TF_PLUGIN_CACHE_DIR}"
          echo "Workspace ready"
        '''
      }
    }

    stage('Terraform Init') {
      options { timeout(time: 5, unit: 'MINUTES') }
      steps {
        echo '=== Initializing Terraform ==='
        withCredentials([usernamePassword(
          credentialsId: 'aws-creds',
          usernameVariable: 'AWS_ACCESS_KEY_ID',
          passwordVariable: 'AWS_SECRET_ACCESS_KEY'
        )]) {
          dir(env.TF_WORKDIR) {
            sh '''
              set -e
              export AWS_DEFAULT_REGION="${AWS_REGION}"
              # Fail fast and use local plugin cache for speed/stability
              export TF_PLUGIN_CACHE_DIR="${TF_PLUGIN_CACHE_DIR}"
              terraform init -input=false
            '''
          }
        }
      }
    }

    stage('Terraform Format (auto-fix)') {
      options { timeout(time: 1, unit: 'MINUTES') }
      steps {
        echo '=== Formatting Terraform files ==='
        dir(env.TF_WORKDIR) {
          sh 'terraform fmt -recursive'
        }
      }
    }

    stage('Terraform Plan') {
      options { timeout(time: 6, unit: 'MINUTES') }
      steps {
        echo '=== Planning Terraform deployment ==='
        withCredentials([usernamePassword(
          credentialsId: 'aws-creds',
          usernameVariable: 'AWS_ACCESS_KEY_ID',
          passwordVariable: 'AWS_SECRET_ACCESS_KEY'
        )]) {
          dir(env.TF_WORKDIR) {
            sh '''
              set -e
              export AWS_DEFAULT_REGION="${AWS_REGION}"
              export TF_VAR_region="${AWS_REGION}"
              export TF_VAR_instance_type="${INSTANCE_TYPE}"
              export TF_VAR_ssh_ingress_cidr="${SSH_INGRESS_CIDR}"
              # Create/overwrite plan file; no interactive input or locks
              terraform plan -out="${PLAN_FILE}" -input=false -lock-timeout=60s
              terraform show -no-color "${PLAN_FILE}" > tfplan.txt
            '''
          }
        }
      }
      post {
        success {
          dir(env.TF_WORKDIR) {
            archiveArtifacts artifacts: 'tfplan.out,tfplan.txt', fingerprint: true
          }
        }
      }
    }

    stage('Approval') {
      when { expression { return currentBuild.rawBuild.getCause(hudson.model.Cause$UserIdCause) != null } } // keep for manual runs
      options { timeout(time: 15, unit: 'MINUTES') }
      steps {
        echo '=== Review plan (Artifacts) and approve to deploy EC2 ==='
        input message: 'Deploy EC2 instance to AWS?', ok: 'Deploy'
      }
    }

    stage('Terraform Apply') {
      options { timeout(time: 10, unit: 'MINUTES') }
      steps {
        echo '=== Deploying EC2 instance ==='
        withCredentials([usernamePassword(
          credentialsId: 'aws-creds',
          usernameVariable: 'AWS_ACCESS_KEY_ID',
          passwordVariable: 'AWS_SECRET_ACCESS_KEY'
        )]) {
          dir(env.TF_WORKDIR) {
            sh '''
              set -euxo pipefail
              export AWS_DEFAULT_REGION="${AWS_REGION}"
              export TF_VAR_region="${AWS_REGION}"
              export TF_VAR_instance_type="${INSTANCE_TYPE}"
              export TF_VAR_ssh_ingress_cidr="${SSH_INGRESS_CIDR}"

              terraform apply -input=false "${PLAN_FILE}"

              # Fix permissions on PEM (if module generated it)
              if [ -f jenkins-ec2.pem ]; then
                chmod 600 jenkins-ec2.pem
                echo "PEM file created successfully"
              fi

              # Outputs for convenience
              terraform output -json > outputs.json
              echo "=== Deployment Complete ==="
              terraform output || true
            '''
          }
        }
      }
      post {
        success {
          dir(env.TF_WORKDIR) {
            archiveArtifacts artifacts: 'jenkins-ec2.pem,outputs.json', fingerprint: true
            echo '=== Download jenkins-ec2.pem from Build Artifacts to SSH into your EC2 instance ==='
          }
        }
      }
    }
  }

  post {
    success {
      echo '✅ Pipeline completed successfully!'
      echo '📦 Download the PEM file from Build Artifacts'
      echo '🔑 Use: ssh -i jenkins-ec2.pem ubuntu@<public_ip>'
    }
    failure {
      echo '❌ Pipeline failed. Check the logs above.'
    }
    always {
      echo "Pipeline finished at ${new Date()}"
      // Optional workspace cleanup to save disk
      // deleteDir()  // uncomment if you want to wipe workspace each run
    }
  }
}
