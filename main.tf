#TODO list:
# * add new az and new subnet so we can run ALB
# * 

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "${var.vpc_name}example_1"
  cidr = "10.0.0.0/16"

  azs                  = ["eu-west-1a", "eu-west-1b"]
  private_subnets      = ["10.0.1.0/24"]
  public_subnets       = ["10.0.101.0/24", "10.0.102.0/24"]
  enable_dns_hostnames = true

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }

}


module "instance_sg" {
  source = "terraform-aws-modules/security-group/aws"

  name        = "user-service-sg"
  description = "Security group for user-service with custom ports open within VPC, and MySQL publicly open"
  vpc_id      = module.vpc.vpc_id
  
  ingress_with_cidr_blocks = [
    {
      rule        = "ssh-tcp"
      cidr_blocks = "0.0.0.0/0"
    },
    {
      rule        = "http-80-tcp"
      cidr_blocks = "0.0.0.0/0"
    }
  ]
  egress_with_cidr_blocks = [
    {
      rule        = "all-all"
      cidr_blocks = "0.0.0.0/0"
    }
  ]
}

resource "tls_private_key" "tls_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "ec2key" {
  key_name   = var.public_key_name
  public_key = tls_private_key.tls_key.public_key_openssh
}

#* script to setup the instance
data "template_file" "init" {
  template = file("script.tpl")
  vars = {
    db_username         = var.db_username
    db_user_password    = var.db_user_password
    db_name             = var.db_name
    db_RDS              = var.db_RDS
  }
}

module "ec2_instance" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "~> 3.0"

  name = "${var.vpc_name}-sbg-wordpresssqlinstance "

  ami                    = var.instance_ami
  instance_type          = var.instance_type
  key_name               = aws_key_pair.ec2key.key_name
  monitoring             = true
  vpc_security_group_ids = [module.instance_sg.security_group_id]
  subnet_id              = module.vpc.public_subnets[0]
  user_data              = data.template_file.init.rendered
  ebs_block_device = [
    {
      device_name           = "/dev/xvdz"
      volume_type           = "gp2"
      volume_size           = "8"
      delete_on_termination = true
    },
  ]
  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}