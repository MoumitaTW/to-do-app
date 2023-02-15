terraform {
  required_version = ">= 1.2.0"
}

provider "aws" {
  region = "ap-south-1"
}

data "aws_iam_policy_document" "moumita_eks_assume_role_policy" {
  version = "2012-10-17"
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"
    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "moumita_ec2_assume_role_policy" {
  version = "2012-10-17"
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "moumita_infra_eks_cluster_iam_role" {
  name               = "moumita_infra_eks_cluster_iam_role"
  assume_role_policy = data.aws_iam_policy_document.moumita_eks_assume_role_policy.json
}


resource "aws_iam_role" "moumita_infra_node_group_iam_role" {
  name               = "moumita_infra_node_group_iam_role"
  assume_role_policy = data.aws_iam_policy_document.moumita_ec2_assume_role_policy.json
}

resource "aws_iam_role_policy_attachment" "moumita_AmazonEKSClusterPolicy" {
  role       = aws_iam_role.moumita_infra_eks_cluster_iam_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role_policy_attachment" "moumita_AmazonEC2ContainerRegistryReadOnly" {
  role       = aws_iam_role.moumita_infra_node_group_iam_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "moumita_AmazonEKS_CNI_Policy" {
  role       = aws_iam_role.moumita_infra_node_group_iam_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "moumita_AmazonEKSWorkerNodePolicy" {
  role       = aws_iam_role.moumita_infra_node_group_iam_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}


resource "aws_security_group" "moumita_infra_sg" {
  name        = "moumita_infra_sg"
  description = "Allow HTTP and SSH inbound traffics"
  vpc_id      = "vpc-087d9a138cb75a809"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["202.142.105.2/32"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["202.142.105.2/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


resource "aws_eks_cluster" "moumita-infracubator-cluster" {
  name     = "moumita-infracubator-cluster"
  role_arn = aws_iam_role.moumita_infra_eks_cluster_iam_role.arn
  kubernetes_network_config {
    ip_family = "ipv4"
  }

  vpc_config {
    security_group_ids      = ["${aws_security_group.moumita_infra_sg.id}"]
    subnet_ids              = ["subnet-0d6cf0838053435a9", "subnet-0d9c79b537d591ab2", "subnet-097dcf4c27c763332", "subnet-097e8dccbf700f80b"]
    endpoint_public_access  = true
    endpoint_private_access = true
    public_access_cidrs     = ["0.0.0.0/0"]
  }

}



resource "aws_eks_node_group" "moumita-infra-ng" {
  cluster_name    = aws_eks_cluster.moumita-infracubator-cluster.name
  node_group_name = "moumita-infra-ng"
  node_role_arn   = aws_iam_role.moumita_infra_node_group_iam_role.arn
  subnet_ids      = ["subnet-0d6cf0838053435a9", "subnet-0d9c79b537d591ab2", "subnet-097dcf4c27c763332", "subnet-097e8dccbf700f80b"]

  capacity_type  = "ON_DEMAND"
  disk_size      = 20
  instance_types = ["t2.small"]
  scaling_config {
    desired_size = 2
    max_size     = 2
    min_size     = 1
  }

  update_config {
    max_unavailable = 1
  }
  depends_on = [
    aws_iam_role_policy_attachment.moumita_AmazonEC2ContainerRegistryReadOnly,
    aws_iam_role_policy_attachment.moumita_AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.moumita_AmazonEKSWorkerNodePolicy,
  ]
}
