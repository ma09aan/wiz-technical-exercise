output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.main.id
}

output "public_subnets_ids_output" {
  description = "List of IDs of public subnets"
  value       = aws_subnet.public[*].id
}

output "private_subnets_ids_output" {
  description = "List of IDs of private subnets"
  value       = aws_subnet.private[*].id
}

output "mongodb_sg_id_output" {
  description = "The ID of the MongoDB Security Group"
  value       = aws_security_group.mongodb_sg.id
}

