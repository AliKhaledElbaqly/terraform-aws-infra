variable "vpc_name" {
  type = string
  default = "project_vpc"
}

variable "vpc_cidr" {
  type = string
  default = "10.0.0.0/16"
}

variable "public_subnets" {
  default = {
    "eu-north-1a" = 10
    "eu-north-1b" = 20
  }
}

variable "private_subnets" {
  default = {
    "eu-north-1a" = 100
    "eu-north-1b" = 200
  }
}

variable "allowed_ports" {
  type = list(any)
  default = [ "22", "80", "443" ]
}

variable "instance_type" {
  default = "t3.micro"
}

variable "allowed_ports_alb" {
   type = list(any)
  default = [ "80", "443" ]
}

variable "instance_class" {
   default = "db.t3.micro"
}

variable "db_name" {
   default = "project_rds"
}


variable "db_username" {
  type = string
}


variable "db_password" {
  type = string
  sensitive = true
}