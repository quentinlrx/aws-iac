terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }
  backend "s3"{
    bucket = "2022307OKn-template1f79b6g1oo7"
    key = "2022307OKn-template1f79b6g1oo7/s3/terraform.tfstate"
    region = "us-east-1"
}
  required_version = ">= 1.2.0"
}

provider "aws" {
  region  = "us-east-1"
}

resource "aws_instance" "app_server" {
  ami           = "ami-09d3b3274b6c5d4aa"
  instance_type = "t2.micro"
  subnet_id = aws_subnet.publicsubnets.id
  associate_public_ip_address = true
  vpc_security_group_ids = [aws_security_group.SecurityGroup.id] 
  user_data_replace_on_change = true
  user_data = <<EOF
#!/bin/bash
yum update -y
amazon-linux-extras install -y php7.2
yum install -y httpd 
systemctl start httpd
systemctl enable httpd
usermod -a -G apache ec2-user
chown -R ec2-user:apache /var/www
chmod 2775 /var/www
find /var/www -type d -exec chmod 2775 {} \;
find /var/www -type f -exec chmod 0664 {} \;
echo "<?php phpinfo(); ?>" > /var/www/html/phpinfo.php
yum install -y git
cd /var/www/
git clone https://bitbucket.org/fhoubart/testphaser_aws.git 
mv testphaser_aws/public_html/* html
EOF 
  

  tags = {
    Name = "Web"
  }
}

resource "aws_vpc" "myvpc" {
  tags = {
    Name = "test-quentin"
  }
  cidr_block = "10.0.0.0/24"
  instance_tenancy = "default"
}

resource "aws_internet_gateway" "igw" {
    vpc_id = aws_vpc.myvpc.id
}

resource "aws_subnet" "publicsubnets" {
    vpc_id = aws_vpc.myvpc.id
    cidr_block = "10.0.0.0/26"
}

resource "aws_subnet" "privatesubnets" {
    vpc_id = aws_vpc.myvpc.id
    cidr_block = "10.0.0.64/26"
}

resource "aws_route_table" "PubicRt" {
    vpc_id = aws_vpc.myvpc.id
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.igw.id
    }
}

resource "aws_route_table" "PrivateRT" {
    vpc_id = aws_vpc.myvpc.id
    route {
        cidr_block = "0.0.0.0/0"
        nat_gateway_id = aws_nat_gateway.NATgw.id
    }
}

resource "aws_route_table_association" "PublicRtassociation" {
    subnet_id = aws_subnet.publicsubnets.id
    route_table_id = aws_route_table.PubicRt.id
}

resource "aws_route_table_association" "PrivateRtassociation" {
    subnet_id = aws_subnet.privatesubnets.id
    route_table_id = aws_route_table.PrivateRT.id
}

resource "aws_eip" "nateIP" {
    vpc = true
}

resource "aws_nat_gateway" "NATgw" {
    allocation_id = aws_eip.nateIP.id
    subnet_id = aws_subnet.publicsubnets.id
}

resource "aws_security_group" "SecurityGroup" {
    name = "secgroupname"
    description = "secgroupname"
    vpc_id      = aws_vpc.myvpc.id
    ingress {
        from_port = 22
        protocol = "tcp"
        to_port = 22
        cidr_blocks = ["0.0.0.0/0"]
      }

      
    ingress {
        from_port = 80
        protocol = "tcp"
        to_port = 80
        cidr_blocks = ["0.0.0.0/0"]
      }

    egress {
        from_port = 0
        protocol = "-1"
        to_port = 0
        cidr_blocks = ["0.0.0.0/0"]
      }
  }
