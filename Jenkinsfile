pipeline {
    agent any
    
    environment {
        // AWS credentials - Jenkins will inject these as environment variables
        // Make sure to create credentials with ID 'aws-credentials-id' in Jenkins
        AWS_ACCESS_KEY_ID     = credentials('aws-creds')
        AWS_SECRET_ACCESS_KEY = credentials('aws-creds')
        AWS_DEFAULT_REGION    = 'us-east-1'  // Change to your preferred region
        
        // Tell Terraform to NOT use interactive mode
        TF_IN_AUTOMATION      = 'true'
        TF_INPUT              = 'false'
    }
    
    stages {
        stage('Checkout Code') {
            steps {
                // Gets your code from repository
                echo 'Checking out code from repository...'
                checkout scm
            }
        }
        
        stage('Terraform Init') {
            steps {
                // Initialize Terraform - downloads AWS provider plugin
                // -input=false: Never ask for interactive input
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
                // Create execution plan - shows what will be created
                // -input=false: Prevents hanging and waiting for input
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
                // Apply changes - creates the EC2 instance
                // -input=false: No interactive prompts
                // -auto-approve: Skip confirmation
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
                // Extract private key and save to workspace root
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
                // Show instance details
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
            // Archive PEM key for download
            archiveArtifacts artifacts: 'my-ec2-key.pem', allowEmptyArchive: true
        }
    }
}
