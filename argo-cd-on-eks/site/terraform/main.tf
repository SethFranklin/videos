
terraform {
  required_version = ">= 1.12.1"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.98.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.37.1"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "3.0.0-pre2"
    }
  }
  backend "s3" {
  }
}

provider "aws" {
  region = var.aws_region
}

locals {
  VPC_ADDRESS_SPACE  = "10.0.0.0/16"
  AVAILABILITY_ZONES = ["a", "b", "c"]

  ARGO_CD_K8S_NAMESPACE_NAME = "argocd"

  subnet_prefix_new_bits = ceil(log(length(local.AVAILABILITY_ZONES), 2))
  subnet_address_spaces  = cidrsubnets(local.VPC_ADDRESS_SPACE, [for az in local.AVAILABILITY_ZONES : local.subnet_prefix_new_bits]...)
}

resource "aws_vpc" "argo_cd" {
  cidr_block = local.VPC_ADDRESS_SPACE

  tags = {
    Name = "Argo CD VPC"
  }
}

resource "aws_subnet" "argo_cd" {
  for_each = toset(local.AVAILABILITY_ZONES)

  vpc_id            = aws_vpc.argo_cd.id
  cidr_block        = local.subnet_address_spaces[index(local.AVAILABILITY_ZONES, each.key)]
  availability_zone = "${var.aws_region}${each.key}"

  tags = {
    Name = "Argo CD Subnet AZ ${each.key}"
  }
}

resource "aws_eks_cluster" "argo_cd" {
  name = "argo_cd_cluster"

  access_config {
    authentication_mode = "API"
  }

  role_arn = aws_iam_role.cluster.arn
  version  = "1.31"

  vpc_config {
    subnet_ids = [for az in local.AVAILABILITY_ZONES : aws_subnet.argo_cd[az].id]
  }

  depends_on = [
    aws_iam_role_policy_attachment.cluster,
  ]
}

resource "aws_iam_role" "cluster" {
  name = "argo_cd_cluster_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "sts:AssumeRole",
          "sts:TagSession"
        ]
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "cluster" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster.name
}

resource "aws_eks_fargate_profile" "argo_cd" {
  cluster_name           = aws_eks_cluster.argo_cd.name
  fargate_profile_name   = "argo_cd_fargate_profile"
  pod_execution_role_arn = aws_iam_role.fargate.arn
  subnet_ids             = [for az in local.AVAILABILITY_ZONES : aws_subnet.argo_cd[az].id]

  selector {
    namespace = local.ARGO_CD_K8S_NAMESPACE_NAME
  }

  depends_on = [
    aws_iam_role_policy_attachment.fargate
  ]
}

resource "aws_iam_role" "fargate" {
  name = "argo_cd_fargate_profile_role"

  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "eks-fargate-pods.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })
}

resource "aws_iam_role_policy_attachment" "fargate" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSFargatePodExecutionRolePolicy"
  role       = aws_iam_role.fargate.name
}

data "aws_eks_cluster_auth" "argo_cd" {
  name = aws_eks_cluster.argo_cd.name
}

data "aws_caller_identity" "current" {}

resource "aws_eks_access_entry" "argo_cd" {
  cluster_name      = aws_eks_cluster.argo_cd.name
  principal_arn     = data.aws_caller_identity.current.arn
  kubernetes_groups = ["group-1", "group-2"]
  type              = "STANDARD"
}

resource "aws_eks_access_policy_association" "argo_cd" {
  cluster_name  = aws_eks_cluster.argo_cd.name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  principal_arn = data.aws_caller_identity.current.arn

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.argo_cd]
}

provider "kubernetes" {
  host                   = aws_eks_cluster.argo_cd.endpoint
  cluster_ca_certificate = base64decode(one(aws_eks_cluster.argo_cd.certificate_authority).data)
  token                  = data.aws_eks_cluster_auth.argo_cd.token
}

resource "kubernetes_namespace" "argo_cd" {
  metadata {
    name = local.ARGO_CD_K8S_NAMESPACE_NAME
  }

  depends_on = [aws_eks_access_policy_association.argo_cd]
}

provider "helm" {
  kubernetes = {
    host                   = aws_eks_cluster.argo_cd.endpoint
    cluster_ca_certificate = base64decode(one(aws_eks_cluster.argo_cd.certificate_authority).data)
    token                  = data.aws_eks_cluster_auth.argo_cd.token
  }
}

resource "helm_release" "argo_cd" {
  name       = "argo-cd"
  chart      = "argo-cd"
  repository = "https://argoproj.github.io/argo-helm"
  version    = "8.0.17"
  namespace  = kubernetes_namespace.argo_cd.id

  set = [{
    name  = "server.service.type"
    value = "LoadBalancer"
  }, {
    name  = "server.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-type"
    value = "nlb"
  }]
}

data "kubernetes_service" "argo_cd" {
  metadata {
    name      = "argocd-server"
    namespace = helm_release.argo_cd.namespace
  }
}

output "argocd_server_load_balancer" {
  value = data.kubernetes_service.argo_cd.status[0].load_balancer[0].ingress[0].hostname
}

