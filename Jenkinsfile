pipeline {
    agent any
    
    environment {
        // AWS credentials from Jenkins - these will be available as environment variables
        // Make sure you create AWS credentials in Jenkins with ID 'aws-credentials-id'
        AWS_ACCESS_KEY_ID     = credentials('aws-creds')
        AWS_SECRET_ACCESS_KEY = credentials('aws-creds')
        AWS_DEFAULT_REGION    = 'us-east-1'  // Change to your region
        
        // Tell Terraform not to use interactive mode
        TF_IN_AUTOMATION      = 'true'
        TF_INPUT              = 'false'
    }
    
    stages {
        stage('Checkout Code') {
            steps {
                echo 'Checking out code from repository...'
                checkout scm
            }
        }
        
        stage('Terraform Init') {
            steps {
                echo 'Initializing Terraform...'
                dir('terraform') {
                    sh '''
                        terraform init -input=false
                    '''
                }
            }
        }
        
        stage('Terraform Plan') {
            steps {
                echo 'Creating Terraform execution plan...'
                dir('terraform') {
                    sh '''
                        terraform plan -input=false -out=tfplan
                    '''
                }
            }
        }
        
        stage('Terraform Apply') {
            steps {
                echo 'Applying Terraform changes to create EC2 instance...'
                dir('terraform') {
                    sh '''
                        terraform apply -input=false -auto-approve tfplan
                    '''
                }
            }
        }
        
        stage('Save PEM Key') {
            steps {
                echo 'Extracting and saving PEM key file...'
                dir('terraform') {
                    sh '''
                        terraform output -raw private_key > ../my-ec2-key.pem
                        chmod 400 ../my-ec2-key.pem
                        echo "PEM key saved as: my-ec2-key.pem in workspace root"
                    '''
                }
            }
        }
        
        stage('Display Connection Info') {
            steps {
                echo 'EC2 Instance created successfully!'
                dir('terraform') {
                    sh '''
                        echo "=========================="
                        echo "EC2 Instance Information:"
                        echo "=========================="
                        terraform output
                        echo ""
                        echo "To connect via SSH, use:"
                        echo "ssh -i my-ec2-key.pem ec2-user@$(terraform output -raw instance_public_ip)"
                    '''
                }
            }
        }
    }
    
    post {
        success {
            echo 'Pipeline completed successfully! EC2 instance is ready.'
        }
        failure {
            echo 'Pipeline failed! Check the logs above for errors.'
        }
        always {
            archiveArtifacts artifacts: 'my-ec2-key.pem', allowEmptyArchive: true
        }
    }
}
