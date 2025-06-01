output "mongodb_public_ip_output" {
  description = "Public IP of the MongoDB EC2 instance"
  value       = aws_instance.mongodb_server.public_ip
}

output "mongodb_instance_id_output" {
  description = "ID of the MongoDB EC2 instance"
  value       = aws_instance.mongodb_server.id
}

output "actual_module_path" {
  value = path.module
}
