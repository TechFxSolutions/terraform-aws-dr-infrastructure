# Networking Module Outputs

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "IDs of public subnets"
  value       = aws_subnet.public[*].id
}

output "private_web_subnet_ids" {
  description = "IDs of private web tier subnets"
  value       = aws_subnet.private_web[*].id
}

output "private_app_subnet_ids" {
  description = "IDs of private application tier subnets"
  value       = aws_subnet.private_app[*].id
}

output "private_db_subnet_ids" {
  description = "IDs of private database tier subnets"
  value       = aws_subnet.private_db[*].id
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = aws_internet_gateway.main.id
}

output "nat_gateway_ids" {
  description = "IDs of NAT Gateways"
  value       = var.enable_nat_gateway ? aws_nat_gateway.main[*].id : []
}

output "public_route_table_id" {
  description = "ID of the public route table"
  value       = aws_route_table.public.id
}

output "private_route_table_ids" {
  description = "IDs of private route tables"
  value       = aws_route_table.private[*].id
}

output "availability_zones" {
  description = "Availability zones used"
  value       = var.availability_zones
}
