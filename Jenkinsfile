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
    SSH_INGRESS_CIDR     = '0.0.0.0/0'  // Change to your IP/32 for security
    TF_PLUGIN_CACHE_DIR  = "${WORKSPACE}/.terraform.d/plugin-cache"
  }

  stages {

    stage('Checkout') {
      steps {
        echo '=== Checking out code ==='
        checkout scm
      }
    }

    stage('Prepare') {
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
              terraform init -input=false
            '''
          }
        }
      }
    }

    stage('Terraform Format') {
      steps {
        echo '=== Formatting Terraform files ==='
        dir(env.TF_WORKDIR) {
          sh 'terraform fmt -recursive'
        }
      }
    }

    stage('Terraform Validate') {
      steps {
        echo '=== Validating Terraform configuration ==='
        withCredentials([usernamePassword(
          credentialsId: 'aws-creds',
          usernameVariable: 'AWS_ACCESS_KEY_ID',
          passwordVariable: 'AWS_SECRET_ACCESS_KEY'
        )]) {
          dir(env.TF_WORKDIR) {
            sh '''
              set -e
              export AWS_DEFAULT_REGION="${AWS_REGION}"
              terraform validate
            '''
          }
        }
      }
    }

    stage('Terraform Plan') {
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
              
              terraform plan -out=tfplan.out -input=false
              terraform show -no-color tfplan.out > tfplan.txt
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
      steps {
        script {
          echo '=== Review the plan above and approve to deploy EC2 instance ==='
          input message: 'Deploy EC2 instance to AWS?', ok: 'Deploy'
        }
      }
    }

    stage('Terraform Apply') {
      steps {
        echo '=== Deploying EC2 instance ==='
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
              
              terraform apply -input=false tfplan.out
              
              # Set correct permissions on PEM file
              if [ -f jenkins-ec2.pem ]; then
                chmod 600 jenkins-ec2.pem
                echo "PEM file created successfully"
              fi
              
              # Show outputs
              terraform output -json > outputs.json
              echo "=== Deployment Complete ==="
              terraform output
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
    }
  }
}
