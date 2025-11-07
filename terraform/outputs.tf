output "instance_id" {
  value = aws_instance.vm.id
}

output "public_ip" {
  value = aws_instance.vm.public_ip
}

output "ssh_command" {
  value       = "ssh -i ${path.module}/jenkins-ec2.pem ubuntu@${aws_instance.vm.public_ip}"
  description = "SSH command (download PEM from Jenkins artifacts first)"
}
