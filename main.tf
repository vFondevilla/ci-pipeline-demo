variable access_key {}
variable secret_key {}
provider "aws" {
  access_key = "${var.access_key}"
  secret_key = "${var.secret_key}"
  region     = "eu-west-1"
}
variable "auth" {
  default = "vfondevilla-tsib"
}
variable "aws_ami" {
  default = "ami-07683a44e80cd32c5"
}

# Configuración del backend de Terraform para almacenar el tfstate
terraform {
  backend "remote" {
    hostname = "app.terraform.io"
    organization = "vFondevilla"
    token = "TF_TOKEN"


    workspaces {
      name = "aws-ci-demo"
    }
  }
}

# Creación del VPC
resource "aws_vpc" "default" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Managed_by = "TSIB-ci-managed"
  }
}

# Crear un gateway de salida a internet para las instancias
resource "aws_internet_gateway" "default" {
  vpc_id = "${aws_vpc.default.id}"
  tags = {
    Managed_by = "TSIB-ci-managed"
  }
}

# Añadir el tráfico de salida a internet
resource "aws_route" "internet_access" {
  route_table_id         = "${aws_vpc.default.main_route_table_id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.default.id}"
}

# Creación de subnet
resource "aws_subnet" "default" {
  vpc_id                  = "${aws_vpc.default.id}"
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  tags = {
    Managed_by = "TSIB-ci-managed"
  }
}

# Security group del ELB
resource "aws_security_group" "elb" {
  name        = "terraform_example_elb"
  description = "Used in the terraform"
  vpc_id      = "${aws_vpc.default.id}"

  # Abrimos el acceso HTTP
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Tráfico de salida
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Managed_by = "TSIB-ci-managed"
  }
}

# Security group para acceder a las VMs por SSH desde cualquier sitio y por el puerto 80 desde el LB.
resource "aws_security_group" "default" {
  name        = "terraform_example"
  description = "Used in the terraform"
  vpc_id      = "${aws_vpc.default.id}"

  # SSH access from anywhere
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP access from the VPC
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }
   # HTTP access from Internet (for troubleshooting)
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Managed_by = "TSIB-ci-managed"
  }
}

# Load Balancer
resource "aws_elb" "web" {
  name = "terraform-example-elb"

  subnets         = ["${aws_subnet.default.id}"]
  security_groups = ["${aws_security_group.elb.id}"]
  instances       = ["${aws_instance.web.*.id}"]

  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }

  health_check {
    healthy_threshold = 2
    unhealthy_threshold = 2
    target = "TCP:80"
    interval = 5
    timeout = 2
  }
  tags = {
    Managed_by = "TSIB-ci-managed"
  }
}

# Creación de instancias
resource "aws_instance" "web" {
  # The connection block tells our provisioner how to
  # communicate with the resource (instance)
  connection {
    # The default username for our AMI
    user = "ec2-user"
    private_key = "${file("vfondevilla-tsib.pem")}"

    # The connection will use the local SSH agent for authentication.
  }

  instance_type = "t2.micro"

  # Lookup the correct AMI based on the region
  # we specified
  ami = "${var.aws_ami}"

  # The name of our SSH keypair.
  key_name = "${var.auth}"

  # Our Security group to allow HTTP and SSH access
  vpc_security_group_ids = ["${aws_security_group.default.id}"]

  # We're going to launch into the same subnet as our ELB. In a production
  # environment it's more common to have a separate private subnet for
  # backend instances.
  subnet_id = "${aws_subnet.default.id}"

  # We run a remote provisioner on the instance after creating it.
  # In this case, we just install nginx and start it. By default,
  # this should be on port 80

  count = 4
  user_data = <<-EOF
    #!/bin/bash
    yum install -y httpd
    service httpd start
    echo -e "<h1>I'm the $(curl http://169.254.169.254/latest/meta-data/local-ipv4) server</h1>" > /var/www/html/index.html  
    EOF
}


output "elb-address" {
  value = "${aws_elb.web.dns_name}"
}