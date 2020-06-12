provider "aws" {
  region     = "us-east-2"
  shared_credentials_file = "/home/a/.aws/credentials"
}

variable "create_m5" {
  # Can run DPDK and VPP...
  description = "Controls if m5 servers should be created"
  type        = bool
  default     = true
}

#VPC

resource "aws_vpc" "VPPTest" {
  cidr_block                       = "192.1.0.0/16"
  instance_tenancy                 = "dedicated"
  assign_generated_ipv6_cidr_block = true
  enable_dns_hostnames             = true
  enable_dns_support 		   = true
  tags = {
    Name = "VPPTest"
  }
}

#SUBNETS

resource "aws_subnet" "VPP-Management" {
  vpc_id            = aws_vpc.VPPTest.id
  cidr_block        = "192.1.0.0/24"
  #ipv6_cidr_block   = cidrsubnet (aws_vpc.VPPTest.ipv6_cidr_block, 8, 1)
  availability_zone = "us-east-2a"
  tags = {
    Name = "VPP-Management"
  }
}

resource "aws_subnet" "VPP-Eastwest" {
  vpc_id            = aws_vpc.VPPTest.id
  cidr_block        = "192.1.2.0/24"
  availability_zone = "us-east-2a"
  tags = {
    Name = "VPP-Eastwest"
  }
}

resource "aws_subnet" "VPP-Westnet" {
  vpc_id                          = aws_vpc.VPPTest.id
  cidr_block                      = "192.1.3.0/24"
  availability_zone               = "us-east-2a"
  tags = {
    Name = "VPP-Westnet"
  }
}

resource "aws_subnet" "VPP-Eastnet" {
  vpc_id                          = aws_vpc.VPPTest.id
  cidr_block                      = "192.1.4.0/24"
  availability_zone               = "us-east-2a"
  tags = {
    Name = "VPP-Eastnet"
  }
}

#INTERNET GATEWAY

resource "aws_internet_gateway" "VPP" {
  vpc_id = aws_vpc.VPPTest.id
  tags = {
    Name = "VPP"
  }
}

#SECURITY GROUPS

resource "aws_security_group" "VPP-ssh" {
  name        = "VPP-ssh"
  description = "Allow ssh inbound traffic"
  vpc_id      = aws_vpc.VPPTest.id

  ingress {
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["83.163.117.153/32", "193.110.1.0/24"]
    ipv6_cidr_blocks = ["2a03:6000:1004::/48"]
  }

  ingress {
        from_port   = 0
        protocol    = "esp"
        to_port     = 0
    	cidr_blocks      = ["83.163.117.153/32", "193.110.1.0/24"]
   }

  ingress {
        from_port   = 500
        protocol    = "udp"
        to_port     = 500
    	cidr_blocks      = ["83.163.117.153/32", "193.110.1.0/24"]
   }

   ingress {
        from_port   = 4500
        protocol    = "udp"
        to_port     = 4500
    	cidr_blocks      = ["83.163.117.153/32", "193.110.1.0/24"]
    }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "VPP-ssh"
  }
}

resource "aws_security_group" "VPP-Allow-all" {
  name        = "VPP-Allow-all"
  description = "Allow all inbound traffic"
  vpc_id      = aws_vpc.VPPTest.id

  ingress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = {
    Name = "VPP-All"
  }
}

#ROUTING TABLE

resource "aws_route_table" "VPP" {
  vpc_id = aws_vpc.VPPTest.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.VPP.id
  }
}

resource "aws_route_table_association" "VPP" {
  subnet_id      = aws_subnet.VPP-Management.id
  route_table_id = aws_route_table.VPP.id
}

# VARIABLES

variable "AMI-id" {
  type = string
  # on us-east-2
  # Ubuntu Server 18.04 LTS (HVM), SSD Volume Type - ami-07c1207a9d40bc3bd (64-bit x86)
  default = "ami-07c1207a9d40bc3bd"

}

variable "EC2-Type"  {
	type = string
	default = "m5dn.24xlarge"
	# default = "m5d.metal" # ssd
	# default = "m5.large"  # 25Gbps
	# c5n.metal 10Gbps
	# default = "c5d.24xlarge"
	# m5dn.24xlarge 96 384 4 x 900 (SSD) Yes 100 Gigabit
}

variable "RootVolumeSize" {
	default = 64
}

#NETWORK INTERFACES

resource "aws_network_interface" "VPP-WestAdmin" {
  count = var.create_m5 ? 1 : 0
  subnet_id = aws_subnet.VPP-Management.id

  security_groups   = [aws_security_group.VPP-ssh.id]
  source_dest_check = false
}

resource "aws_network_interface" "VPP-WestEth0" {
  count = var.create_m5 ? 1 : 0
  subnet_id = aws_subnet.VPP-Westnet.id

  security_groups   = [aws_security_group.VPP-Allow-all.id]
  source_dest_check = false
  attachment {
    instance     = aws_instance.VPP-West[1].id
    device_index = 1
  }
}

resource "aws_network_interface" "VPP-WestEth1" {
  count = var.create_m5 ? 1 : 0
  subnet_id = aws_subnet.VPP-Eastwest.id

  security_groups   = [aws_security_group.VPP-Allow-all.id]
  source_dest_check = false
  attachment {
    instance     = aws_instance.VPP-West[1].id
    device_index = 2
  }
}

resource "aws_network_interface" "VPP-EastAdmin" {
  count = var.create_m5 ? 1 : 0
  subnet_id = aws_subnet.VPP-Management.id

  security_groups   = [aws_security_group.VPP-ssh.id]
  source_dest_check = false
}

resource "aws_network_interface" "VPP-EastEth0" {
  count = var.create_m5 ? 1 : 0
  subnet_id = aws_subnet.VPP-Eastnet.id

  security_groups   = [aws_security_group.VPP-Allow-all.id]
  source_dest_check = false
  attachment {
    instance     = aws_instance.VPP-East[1].id
    device_index = 1
  }
}

resource "aws_network_interface" "VPP-EastEth1" {
  count = var.create_m5 ? 1 : 0
  subnet_id = aws_subnet.VPP-Eastwest.id

  security_groups   = [aws_security_group.VPP-Allow-all.id]
  source_dest_check = false
  attachment {
    instance     = aws_instance.VPP-East[1].id
    device_index = 2
  }
}

#ASSIGN EIP

resource "aws_eip" "VPP-West" {
 count = var.create_m5 ? 1 : 0
 network_interface = aws_network_interface.VPP-WestAdmin[count.index].id
 vpc = true
}

resource "aws_eip" "VPP-East" {
 count = var.create_m5 ? 1 : 0
 network_interface = aws_network_interface.VPP-EastAdmin[count.index].id
 vpc = true
}

#INSTANCE WITH VPP CREATED BY

resource "aws_instance" "VPP-West" {
  count = var.create_m5 ? 1 : 0
  ami                    = var.AMI-id
  instance_type          = var.EC2-Type
  key_name               = "VPP_VPPTest"
  network_interface {
    network_interface_id = aws_network_interface.VPP-WestAdmin[count.index].id
    device_index         = 0
  }
  root_block_device {
    volume_size = var.RootVolumeSize
  }
  availability_zone = "us-east-2a"
  tags = {
    Name = "VPP-West"
  }
}

resource "aws_instance" "VPP-East" {
  count = var.create_m5 ? 1 : 0

  ami                    = var.AMI-id
  instance_type          = var.EC2-Type
  key_name               = "VPP_VPPTest"
  network_interface {
    network_interface_id = aws_network_interface.VPP-EastAdmin[count.index].id
    device_index         = 0
  }
  root_block_device {
    volume_size = var.RootVolumeSize
  }
  availability_zone = "us-east-2a"
  tags = {
    Name = "VPP-East"
  }
}

#t2.micro isntances for testing

variable "EC2-Micro"  {
	type = string
	default = "t2.micro"
}

/*
resource "aws_instance" "VPP-WestMicro" {
  count = var.create_m5 ? 0 : 1
  ami                    = var.AMI-id
  instance_type          = var.EC2-Micro
  key_name               = "VPP_VPPTest"
  vpc_security_group_ids = [aws_security_group.VPP-ssh.id]
  subnet_id = aws_subnet.VPP-Management.id
  associate_public_ip_address = true
  availability_zone = "us-east-2a"
  tags = {
    Name = "VPP-WestMicro"
  }
}

resource "aws_instance" "VPP-EastMicro" {
  count = var.create_m5 ? 0 : 1
  ami                    = var.AMI-id
  instance_type          = var.EC2-Micro
  key_name               = "VPP_VPPTest"
  vpc_security_group_ids = [aws_security_group.VPP-ssh.id]
  subnet_id = aws_subnet.VPP-Management.id
  associate_public_ip_address = true
  availability_zone = "us-east-2a"
  tags = {
    Name = "VPP-EastMicro"
  }
}
*/
