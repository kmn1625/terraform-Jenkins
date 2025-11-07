pipeline {
  agent any

  stages {

    stage('Checkout') {
      steps {
        checkout scm
      }
    }

    stage('Terraform Init') {
      steps {
        withCredentials([usernamePassword(
          credentialsId: 'aws-creds',
          usernameVariable: 'AWS_ACCESS_KEY_ID',
          passwordVariable: 'AWS_SECRET_ACCESS_KEY'
        )]) {
          dir('terraform') {
            sh '''
              export AWS_DEFAULT_REGION=ap-south-1
              terraform init -input=false
            '''
          }
        }
      }
    }

    stage('Terraform Plan') {
      steps {
        withCredentials([usernamePassword(
          credentialsId: 'aws-creds',
          usernameVariable: 'AWS_ACCESS_KEY_ID',
          passwordVariable: 'AWS_SECRET_ACCESS_KEY'
        )]) {
          dir('terraform') {
            sh '''
              export AWS_DEFAULT_REGION=ap-south-1
              terraform plan -out=tfplan.out -input=false
            '''
          }
        }
      }
    }

    stage('Terraform Apply') {
      steps {
        withCredentials([usernamePassword(
          credentialsId: 'aws-creds',
          usernameVariable: 'AWS_ACCESS_KEY_ID',
          passwordVariable: 'AWS_SECRET_ACCESS_KEY'
        )]) {
          dir('terraform') {
            sh '''
              export AWS_DEFAULT_REGION=ap-south-1
              terraform apply -auto-approve tfplan.out

              # Fix key permissions if pem exists
              if [ -f jenkins-ec2.pem ]; then chmod 600 jenkins-ec2.pem; fi

              terraform output -json > outputs.json
            '''
          }
        }
      }
      post {
        success {
          dir('terraform') {
            archiveArtifacts artifacts: 'jenkins-ec2.pem,outputs.json', fingerprint: true
          }
        }
      }
    }
  }
}
