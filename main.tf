
# Create a VPC
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr_block
  tags = {
    "Name" = var.main_vpc_name
  }
}

# Create a subnet
resource "aws_subnet" "web" {
  vpc_id = aws_vpc.main.id
  cidr_block = var.web_subnet
  availability_zone = var.availability_zone
  tags = {
    "Name" = "Web subnet"
  }
}

# Create a second subnet for ALB
resource "aws_subnet" "second_web" {
  vpc_id = aws_vpc.main.id
  cidr_block = var.second_web_subnet
  availability_zone = var.second_availability_zone
  tags = {
    "Name" = "Second web subnet"
  }
}

resource "aws_internet_gateway" "my_web_igw" {
  vpc_id = aws_vpc.main.id
  tags = {
    "Name" = "${var.main_vpc_name} IGW"
  }
}

resource "aws_default_route_table" "main_vpc_default_rt" {
  default_route_table_id = aws_vpc.main.default_route_table_id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.my_web_igw.id
  }
  tags = {
    "Name" = "Default RT"
  }
}

# security group for Application Load Balancer
resource "aws_security_group" "alb_sg" {
  vpc_id = aws_vpc.main.id
  # HTTPS rule
  ingress {
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = [ "0.0.0.0/0" ]
  }
  # HTTP rule
  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = [ "0.0.0.0/0" ]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = [ "0.0.0.0/0" ]
  }

  tags = {
    "Name" = "ALB Security Group"
  }
}

# security group for the web server
resource "aws_security_group" "instance_sg" {
  vpc_id = aws_vpc.main.id
  ingress {
    from_port = 3000
    to_port = 3000
    protocol = "tcp"
    cidr_blocks = [ "0.0.0.0/0" ]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = [ "0.0.0.0/0" ]
  }

  tags = {
    "Name" = "Instance Security Group"
  }
}

# Data source for AWS Linux 2 AMI
data "aws_ami" "latest_amazon_linux2" {
  owners = [ "amazon" ]
  most_recent = true
  filter {
    name = "name"
    values = [ "amzn2-ami-kernel-*-x86_64-gp2" ]
  }

  filter {
    name = "architecture"
    values = [ "x86_64" ]
  }
}

# Quest EC2 Instance
resource "aws_instance" "quest_instance" {
  ami = data.aws_ami.latest_amazon_linux2.id
  instance_type = "t2.micro"
  subnet_id = aws_subnet.web.id
  vpc_security_group_ids = [ aws_security_group.instance_sg.id ]
  associate_public_ip_address = true
  user_data = file("userdata.sh")
  
  tags = {
    "Name" = "Quest Instance"
  }
}


# Application Load Balancer (ALB)
resource "aws_lb" "quest_alb" {
  name               = "quest-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [ aws_security_group.alb_sg.id ]
  subnets            = [ aws_subnet.web.id, aws_subnet.second_web.id ]

  tags = {
    Name = "Quest ALB"
  }
}

# Target Group for ALB
resource "aws_lb_target_group" "main_tg" {
  name     = "quest-alb-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path = "/loadbalanced"
  }
}

resource "aws_lb_target_group_attachment" "alb_tg_attachment" {
  target_group_arn = aws_lb_target_group.main_tg.arn
  target_id        = aws_instance.quest_instance.id
  port             = 3000
}

# ALB HTTP listener
resource "aws_lb_listener" "http_listener" {
  load_balancer_arn = aws_lb.quest_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "redirect"
    
    redirect {
      port = "443"
      protocol = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# ALB HTTPS listener with ACM cert
resource "aws_lb_listener" "https_listener" {
  load_balancer_arn = aws_lb.quest_alb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = aws_acm_certificate.cert.arn
  

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main_tg.arn
  }
}

# TLS Certificate creation
resource "tls_private_key" "tls_p_key" {
  algorithm = "RSA"
}

# Adding ACM certificate to ALB HTTPS listener
resource "aws_lb_listener_certificate" "alb_listener_cert" {
  listener_arn    = aws_lb_listener.https_listener.arn
  certificate_arn = aws_acm_certificate.cert.arn
}

// to provision a secure network communication
resource "aws_acm_certificate" "cert" {
    provider                  = aws.virginia
    domain_name               = var.domain_name
    subject_alternative_names = ["*.${var.domain_name}"]
    validation_method         = "DNS"
    tags                      = local.tags  
}

// to validate the domain i'm setting the certificate with and also create the CNAME record
resource "aws_route53_record" "certvalidation" {
  for_each = {
    for d in aws_acm_certificate.cert.domain_validation_options : d.domain_name => {
      name   = d.resource_record_name
      record = d.resource_record_value
      type   = d.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = aws_route53_zone.domain.id
}

// to  ensures that the CNAME record points to a valid certificate in AWS ACM
resource "aws_acm_certificate_validation" "certvalidation" {
    certificate_arn = aws_acm_certificate.cert.arn
    validation_record_fqdns = [for r in aws_route53_record.certvalidation : r.fqdn]
}

resource "aws_route53_zone" "domain" {
  name = var.domain_name
}

// url to talk to cloudfront resource 
resource "aws_route53_record" "websiteurl" {
  name    = var.endpoint
  zone_id = aws_route53_zone.domain.id
  type    = "A"

  alias {
    name                   = aws_lb.quest_alb.dns_name
    zone_id                = aws_lb.quest_alb.zone_id
    evaluate_target_health = true
  }
}