output "public_ip" {
  description = "Public IP of the k3s node"
  value       = aws_eip.k3s.public_ip
}

output "ssh_command" {
  description = "SSH command to connect to the instance"
  value       = "ssh -i ~/Downloads/key.pem ubuntu@${aws_eip.k3s.public_ip}"
}

output "k3s_api" {
  description = "k3s API endpoint"
  value       = "https://${aws_eip.k3s.public_ip}:6443"
}
