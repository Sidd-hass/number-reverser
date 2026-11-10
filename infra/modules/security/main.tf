resource "aws_security_group" "ec2" {
  name        = "${var.project_name}-ec2-sg"
  description = "Security group for the Number Reverser k3s EC2 instance."
  vpc_id      = var.vpc_id

  tags = merge(var.tags, {
    Name = "${var.project_name}-ec2-sg"
  })
}

resource "aws_vpc_security_group_ingress_rule" "http" {
  security_group_id = aws_security_group.ec2.id
  description       = "Allow public HTTP traffic."
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "https" {
  security_group_id = aws_security_group.ec2.id
  description       = "Allow public HTTPS traffic."
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "https_outbound" {
  security_group_id = aws_security_group.ec2.id
  description       = "Allow HTTPS for SSM, Docker image pulls and package downloads."
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "http_outbound" {
  security_group_id = aws_security_group.ec2.id
  description       = "Allow HTTP for package repositories and redirects."
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "dns_udp_outbound" {
  security_group_id = aws_security_group.ec2.id
  description       = "Allow outbound DNS queries (UDP)."
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 53
  to_port           = 53
  ip_protocol       = "udp"
}

resource "aws_vpc_security_group_egress_rule" "dns_tcp_outbound" {
  security_group_id = aws_security_group.ec2.id
  description       = "Allow outbound DNS queries (TCP)."
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 53
  to_port           = 53
  ip_protocol       = "tcp"
}
