

pipeline {
    agent any
    
    environment {
        // Set the AWS credentials ID that you configured in Jenkins
        // Go to: Jenkins > Manage Jenkins > Credentials > Add AWS credentials
        AWS_CREDENTIALS = credentials('aws-creds')
        AWS_DEFAULT_REGION = 'us-east-1'  // Change to your preferred region
    }
    
    stages {
        stage('Checkout Code') {
            steps {
                // This stage gets your code from Git repository
                // If running locally, this will use the current workspace
                echo 'Checking out code from repository...'
                checkout scm
            }
        }
        
        stage('Terraform Init') {
            steps {
                // Initialize Terraform - downloads required provider plugins (AWS)
                // This must run before any other Terraform commands
                echo 'Initializing Terraform...'
                sh '''
                    terraform init
                '''
            }
        }
        
        stage('Terraform Plan') {
            steps {
                // Creates an execution plan - shows what Terraform will do
                // This is a "dry run" to see changes before applying them
                // Helps catch errors before creating actual resources
                echo 'Creating Terraform execution plan...'
                sh '''
                    terraform plan -out=tfplan
                '''
            }
        }
        
        stage('Terraform Apply') {
            steps {
                // Apply the changes - actually creates the EC2 instance and key pair
                // The -auto-approve flag skips the manual confirmation
                echo 'Applying Terraform changes to create EC2 instance...'
                sh '''
                    terraform apply -auto-approve tfplan
                '''
            }
        }
        
        stage('Save PEM Key') {
            steps {
                // Extract the private key from Terraform output and save it
                // This creates the .pem file you need to SSH into your EC2 instance
                // The key is saved in Jenkins workspace for download
                echo 'Extracting and saving PEM key file...'
                sh '''
                    terraform output -raw private_key > my-ec2-key.pem
                    chmod 400 my-ec2-key.pem
                    echo "PEM key saved as: my-ec2-key.pem"
                    echo "You can download this file from Jenkins workspace"
                '''
            }
        }
        
        stage('Display Connection Info') {
            steps {
                // Show the EC2 instance details so you can connect to it
                // Displays public IP and the SSH command to use
                echo 'EC2 Instance created successfully!'
                sh '''
                    echo "=========================="
                    echo "EC2 Instance Information:"
                    echo "=========================="
                    terraform output
                    echo ""
                    echo "To download PEM key: Check Jenkins workspace for my-ec2-key.pem"
                    echo "To connect via SSH, use:"
                    echo "ssh -i my-ec2-key.pem ec2-user@$(terraform output -raw instance_public_ip)"
                '''
            }
        }
    }
    
    post {
        // This runs after all stages complete
        success {
            // If everything succeeded, print success message
            echo 'Pipeline completed successfully! EC2 instance is ready.'
            echo 'Download the PEM key from Jenkins workspace to connect to your instance.'
        }
        failure {
            // If any stage failed, print error message
            echo 'Pipeline failed! Check the logs above for errors.'
        }
        always {
            // Always archive the PEM key file so you can download it
            // Go to Jenkins job > Build # > Workspace to download
            archiveArtifacts artifacts: 'my-ec2-key.pem', allowEmptyArchive: true
        }
    }
}
