provider "aws" {
  region  = "us-east-1"
}

variable "sec-gr-k8s" {
  default = "petclinic-k8s-sec-group"
}

data "aws_vpc" "name" {
  default = true
}

data "aws_subnets" "mysubnets" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.name.id]
  }
}

data "aws_subnet" "picked_subnet" {
  id = data.aws_subnets.mysubnets.ids[0]
}

resource "aws_security_group" "k8s-sec-gr" {
  name = var.sec-gr-k8s
  vpc_id = data.aws_vpc.name.id
  tags = {
    Name = var.sec-gr-k8s
  }

  ingress {
    from_port = 0
    protocol  = "-1"
    to_port   = 0
    self = true
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol = "tcp"
    from_port = 6443
    to_port = 6443
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    protocol    = "-1"
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}


resource "aws_iam_role" "petclinic-master-server-s3-role" {
  name               = "petclinic-master-server-role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF

}

resource "aws_iam_role_policy_attachment" "petclinic_s3_policy" {
  role       = aws_iam_role.petclinic-master-server-s3-role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}

resource "aws_iam_instance_profile" "petclinic-master-server-profile" {
  name = "petclinic-master-server-profile"
  role = aws_iam_role.petclinic-master-server-s3-role.name
}

resource "aws_instance" "kube-master" {
  ami = "ami-005fc0f236362e99f"
  instance_type = var.master_instance_type
  iam_instance_profile = aws_iam_instance_profile.petclinic-master-server-profile.name
  vpc_security_group_ids = [aws_security_group.k8s-sec-gr.id]
  key_name = var.mykey
  subnet_id = data.aws_subnet.picked_subnet.id
  availability_zone = data.aws_subnet.picked_subnet.availability_zone
  tags = {
    Name = "kube-master"
    Project = "tera-kube-ans"
    Role = "master"
    Id = "1"
    environment = var.env
  }
}

resource "aws_instance" "workers" {
  count = var.worker_count
  ami = "ami-005fc0f236362e99f"
  instance_type = var.worker_instance_type
  vpc_security_group_ids = [aws_security_group.k8s-sec-gr.id]
  key_name = var.mykey
  subnet_id = data.aws_subnet.picked_subnet.id
  availability_zone = data.aws_subnet.picked_subnet.availability_zone
  tags = {
    Name = "worker-${count.index + 1}"
    Project = "tera-kube-ans"
    Role = "worker"
    Id = count.index + 1
    environment = var.env
  }
}

output kube-master-ip {
  value       = aws_instance.kube-master.public_ip
  sensitive   = false
  description = "public ip of the kube-master"
}

output worker-ips {
  value       = aws_instance.workers[*].public_ip
  sensitive   = false
  description = "public ips of the workers"
}
