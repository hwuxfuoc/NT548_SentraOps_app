output "public_ip" {
  value = aws_eip.k3s.public_ip
}

output "ssh_command" {
  value = "ssh -i ~/.ssh/sentraops-key.pem ubuntu@${aws_eip.k3s.public_ip}"
}

output "app_url" {
  value = "http://${aws_eip.k3s.public_ip}:30080/health"
}
