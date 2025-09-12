output "key_name" {
  description = "Name of the AWS key pair"
  value       = aws_key_pair.docker_swarm_key.key_name
}

output "key_pair_id" {
  description = "ID of the AWS key pair"
  value       = aws_key_pair.docker_swarm_key.key_pair_id
}

output "private_key_path" {
  description = "Path to the private key file"
  value       = local_file.private_key.filename
}

output "public_key" {
  description = "Public key content"
  value       = tls_private_key.ssh_key.public_key_openssh
  sensitive   = false
}

output "private_key_pem" {
  description = "Private key in PEM format"
  value       = tls_private_key.ssh_key.private_key_pem
  sensitive   = true
}