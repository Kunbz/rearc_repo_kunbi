
variable "region" {
  default = "us-east-1"
}

variable "main_vpc_name" {
  default = "Rearc Quest VPC"
}

variable "vpc_cidr_block" {
  default = "10.0.0.0/16"
  description = "CIDR Block for the VPC"
  type = string
}

variable "web_subnet" {
  default = "10.0.10.0/24"
  description = "Web subnet"
  type = string
}

variable "domain_name" {
 default = "kunbiainamarshall.com"
}

variable "endpoint" {
 default = "kunbiainamarshall.com"
}

variable "second_web_subnet" {
  default = "10.0.20.0/24"
  description = "Second web subnet"
  type = string
}

variable "availability_zone" {
  default = "us-east-1a"
}

variable "second_availability_zone" {
  default = "us-east-1b"
}
