pipeline {
  agent any

  options {
    timestamps()
  }

  parameters {
    choice(name: 'ACTION', choices: ['plan', 'apply', 'destroy'], description: 'Terraform action')
    booleanParam(name: 'AUTO_APPROVE', defaultValue: false, description: 'Skip manual approval for apply/destroy')
    string(name: 'AWS_REGION', defaultValue: 'ap-south-1', description: 'AWS region')
    string(name: 'INSTANCE_TYPE', defaultValue: 't3.micro', description: 'EC2 instance type')
    string(name: 'SSH_INGRESS_CIDR', defaultValue: '0.0.0.0/0', description: 'CIDR allowed for SSH (use your /32 for safety)')
    string(name: 'TAGS_JSON', defaultValue: '{"Project":"JenkinsTF","Env":"Dev"}', description: 'JSON map of extra tags')
  }

  environment {
    TF_IN_AUTOMATION     = 'true'
    TF_WORKDIR           = 'terraform'
    PLAN_FILE            = 'tfplan.out'
    REPORT_DIR           = 'reports'
    PEM_FILE             = 'jenkins-ec2.pem'
    TF_PLUGIN_CACHE_DIR  = "${WORKSPACE}/.terraform.d/plugin-cache"
  }

  stages {

    stage('Checkout') {
      options { timeout(time: 2, unit: 'MINUTES') }
      steps {
        checkout scm
      }
    }

    stage('Prepare') {
      options { timeout(time: 1, unit: 'MINUTES') }
      steps {
        sh '''
          set -e
          mkdir -p "${TF_PLUGIN_CACHE_DIR}"
          mkdir -p "${REPORT_DIR}"
        '''
      }
    }

    stage('Tooling Check') {
      options { timeout(time: 1, unit: 'MINUTES') }
      steps {
        sh '''
          terraform version || (echo "Terraform not found in PATH" && exit 1)
          # AWS CLI not required for this simplified pipeline
        '''
      }
    }

    stage('Init') {
      options { timeout(time: 5, unit: 'MINUTES') }
      steps {
        withCredentials([usernamePassword(credentialsId: 'aws-creds', usernameVariable: 'AWS_ACCESS_KEY_ID', passwordVariable: 'AWS_SECRET_ACCESS_KEY')]) {
          withEnv([
            "AWS_DEFAULT_REGION=${params.AWS_REGION}",
            "TF_VAR_region=${params.AWS_REGION}",
            "TF_VAR_instance_type=${params.INSTANCE_TYPE}",
            "TF_VAR_ssh_ingress_cidr=${params.SSH_INGRESS_CIDR}",
            "TF_VAR_tags=${params.TAGS_JSON}",
          ]) {
            dir(env.TF_WORKDIR) {
              sh '''
                set -e
                terraform init -input=false
              '''
            }
          }
        }
      }
    }

    stage('Fmt (auto-fix)') {
      options { timeout(time: 1, unit: 'MINUTES') }
      steps {
        dir(env.TF_WORKDIR) {
          sh 'terraform fmt -recursive'
        }
      }
    }

    stage('Validate') {
      options { timeout(time: 2, unit: 'MINUTES') }
      steps {
        // FIX: Added credentials and environment variables
        withCredentials([usernamePassword(credentialsId: 'aws-creds', usernameVariable: 'AWS_ACCESS_KEY_ID', passwordVariable: 'AWS_SECRET_ACCESS_KEY')]) {
          withEnv([
            "AWS_DEFAULT_REGION=${params.AWS_REGION}",
            "TF_VAR_region=${params.AWS_REGION}",
            "TF_VAR_instance_type=${params.INSTANCE_TYPE}",
            "TF_VAR_ssh_ingress_cidr=${params.SSH_INGRESS_CIDR}",
            "TF_VAR_tags=${params.TAGS_JSON}",
          ]) {
            dir(env.TF_WORKDIR) {
              sh 'terraform validate -no-color'
            }
          }
        }
      }
    }

    stage('Plan') {
      options { timeout(time: 5, unit: 'MINUTES') }
      when { anyOf { environment name: 'ACTION', value: 'plan'; environment name: 'ACTION', value: 'apply' } }
      steps {
        withCredentials([usernamePassword(credentialsId: 'aws-creds', usernameVariable: 'AWS_ACCESS_KEY_ID', passwordVariable: 'AWS_SECRET_ACCESS_KEY')]) {
          withEnv([
            "AWS_DEFAULT_REGION=${params.AWS_REGION}",
            "TF_VAR_region=${params.AWS_REGION}",
            "TF_VAR_instance_type=${params.INSTANCE_TYPE}",
            "TF_VAR_ssh_ingress_cidr=${params.SSH_INGRESS_CIDR}",
            "TF_VAR_tags=${params.TAGS_JSON}",
          ]) {
            dir(env.TF_WORKDIR) {
              sh 'terraform plan -out="${PLAN_FILE}" -input=false'
            }
          }
        }
      }
      post {
        success {
          dir(env.TF_WORKDIR) {
            archiveArtifacts artifacts: "${PLAN_FILE}", fingerprint: true
          }
        }
      }
    }

    stage('Manual Approval') {
      when {
        anyOf {
          allOf { environment name: 'ACTION', value: 'apply'; expression { return params.AUTO_APPROVE == false } }
          allOf { environment name: 'ACTION', value: 'destroy'; expression { return params.AUTO_APPROVE == false } }
        }
      }
      options { timeout(time: 15, unit: 'MINUTES') }
      steps {
        input message: 'Proceed with terraform apply/destroy?'
      }
    }

    stage('Apply') {
      when { environment name: 'ACTION', value: 'apply' }
      options { timeout(time: 10, unit: 'MINUTES') }
      steps {
        script {
          def AUTO_FLAG = params.AUTO_APPROVE ? "-auto-approve" : ""
          withCredentials([usernamePassword(credentialsId: 'aws-creds', usernameVariable: 'AWS_ACCESS_KEY_ID', passwordVariable: 'AWS_SECRET_ACCESS_KEY')]) {
            withEnv([ "AWS_DEFAULT_REGION=${params.AWS_REGION}" ]) {
              dir(env.TF_WORKDIR) {
                sh """
                  set -euxo pipefail
                  terraform apply -input=false ${AUTO_FLAG} "${PLAN_FILE}"
                  # Ensure the PEM is 0600 for SSH clients
                  if [ -f "${PEM_FILE}" ]; then chmod 600 "${PEM_FILE}"; fi
                """
              }
            }
          }
        }
      }
      post {
        success {
          // Archive the PEM created by Terraform (sensitive)
          dir(env.TF_WORKDIR) {
            archiveArtifacts artifacts: "jenkins-ec2.pem", onlyIfSuccessful: true
          }
        }
      }
    }

    stage('Destroy') {
      when { environment name: 'ACTION', value: 'destroy' }
      options { timeout(time: 10, unit: 'MINUTES') }
      steps {
        script {
          def AUTO_FLAG = params.AUTO_APPROVE ? "-auto-approve" : ""
          withCredentials([usernamePassword(credentialsId: 'aws-creds', usernameVariable: 'AWS_ACCESS_KEY_ID', passwordVariable: 'AWS_SECRET_ACCESS_KEY')]) {
            withEnv([ "AWS_DEFAULT_REGION=${params.AWS_REGION}" ]) {
              dir(env.TF_WORKDIR) {
                sh """
                  set -euxo pipefail
                  terraform destroy -input=false ${AUTO_FLAG}
                """
              }
            }
          }
        }
      }
    }
  }

  post {
    success { echo 'Pipeline completed successfully.' }
    failure { echo 'Pipeline failed. Check stage logs.' }
  }
}
