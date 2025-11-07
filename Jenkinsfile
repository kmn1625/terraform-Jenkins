pipeline {
  agent any

  options {
    // Removed ansiColor to avoid plugin requirement
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
    TF_IN_AUTOMATION = 'true'
    TF_WORKDIR = 'terraform'
    PLAN_FILE = 'tfplan.out'
    REPORT_DIR = 'reports'
    PEM_FILE = 'jenkins-ec2.pem'
  }

  stages {
    stage('Checkout') { 
      steps { checkout scm } 
    }

    stage('Tooling Check') {
      steps {
        sh '''
          terraform version || (echo "Terraform not found in PATH" && exit 1)
          aws --version || (echo "AWS CLI not found in PATH" && exit 1)
        '''
      }
    }

    stage('Init') {
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
              sh 'terraform init -input=false'
            }
          }
        }
      }
    }

    stage('Fmt Check') {
      steps { 
        dir(env.TF_WORKDIR) { sh 'terraform fmt -check -recursive' } 
      }
    }

    stage('Validate') {
      steps {
        withEnv(["AWS_DEFAULT_REGION=${params.AWS_REGION}"]) {
          dir(env.TF_WORKDIR) { sh 'terraform validate -no-color' }
        }
      }
    }

    stage('Plan') {
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
        always {
          dir(env.TF_WORKDIR) {
            archiveArtifacts artifacts: "${PLAN_FILE}", fingerprint: true, onlyIfSuccessful: true
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
      steps { 
        timeout(time: 20, unit: 'MINUTES') { input message: 'Proceed with terraform apply/destroy?' } 
      }
    }

    stage('Apply') {
      when { environment name: 'ACTION', value: 'apply' }
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
    }

    stage('Post-Apply Test') {
      when { environment name: 'ACTION', value: 'apply' }
      steps {
        withCredentials([usernamePassword(credentialsId: 'aws-creds', usernameVariable: 'AWS_ACCESS_KEY_ID', passwordVariable: 'AWS_SECRET_ACCESS_KEY')]) {
          withEnv([ "AWS_DEFAULT_REGION=${params.AWS_REGION}" ]) {
            sh '''
              set -e
              mkdir -p "${REPORT_DIR}"
              INSTANCE_ID=$(terraform -chdir="${TF_WORKDIR}" output -raw instance_id || true)
              if [ -z "$INSTANCE_ID" ]; then
                cat > "${REPORT_DIR}/aws-tests.xml" <<'XML'
<testsuite name="aws" tests="1" failures="1">
  <testcase classname="aws" name="instance_id_output">
    <failure message="No instance_id output from terraform">Expected an instance_id</failure>
  </testcase>
</testsuite>
XML
                exit 1
              fi
              STATE=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" --query 'Reservations[0].Instances[0].State.Name' --output text || echo "unknown")
              if [ "$STATE" = "running" ]; then
                cat > "${REPORT_DIR}/aws-tests.xml" <<'XML'
<testsuite name="aws" tests="1" failures="0">
  <testcase classname="aws" name="instance_running"/>
</testsuite>
XML
              else
                cat > "${REPORT_DIR}/aws-tests.xml" <<XML
<testsuite name="aws" tests="1" failures="1">
  <testcase classname="aws" name="instance_running">
    <failure message="Instance not running">State was: ${STATE}</failure>
  </testcase>
</testsuite>
XML
                exit 1
              fi
            '''
          }
        }
        junit allowEmptyResults: false, testResults: "${REPORT_DIR}/aws-tests.xml"
      }
      post {
        always {
          // Archive PEM and test report; PEM is sensitive—limit job visibility
          dir(env.TF_WORKDIR) {
            archiveArtifacts artifacts: "jenkins-ec2.pem", onlyIfSuccessful: true
          }
          archiveArtifacts artifacts: "${REPORT_DIR}/*.xml", fingerprint: true, onlyIfSuccessful: false
        }
      }
    }

    stage('Destroy') {
      when { environment name: 'ACTION', value: 'destroy' }
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
    failure { echo 'Pipeline failed. Check logs and Test Results.' }
  }
}
