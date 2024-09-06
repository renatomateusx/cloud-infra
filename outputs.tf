output "ec2_public_ip" {
  value = aws_instance.web.public_ip
}

output "rds_endpoint" {
  value = aws_db_instance.mysql.endpoint
}

output "elb_dns_name" {
  value = aws_elb.web_lb.dns_name
}
