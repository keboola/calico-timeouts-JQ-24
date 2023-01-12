provider "aws" {
  region = var.region

  default_tags {
    tags = {
      KeboolaStack = "keboola-stuck-docker-JQ-48"
      KeboolaRole  = "keboola-stuck-docker-JQ-48"
    }
  }
}


locals {
  name            = var.cluster_name
  cluster_version = "1.23"
}

################################################################################
# EKS Module
################################################################################

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    # This requires the awscli to be installed locally where Terraform is executed
    args = ["eks", "get-token", "--cluster-name", module.eks.cluster_id]
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "18.30.2"

  cluster_name                    = local.name
  cluster_version                 = local.cluster_version
  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  create_aws_auth_configmap = true
  manage_aws_auth_configmap = true

  node_security_group_additional_rules = {
    ingress_vxlan = {
      description = "Calico VXLAN"
      protocol    = "udp"
      from_port   = 4789
      to_port     = 4789
      type        = "ingress"
      self        = true
    }

    egress_vxlan = {
      description = "Calico VXLAN"
      protocol    = "udp"
      from_port   = 4789
      to_port     = 4789
      type        = "egress"
      self        = true
    }

  }

  self_managed_node_groups = {
    main = {
      name         = "main"
      max_size     = 1
      desired_size = 1

      instance_type                          = "r6a.2xlarge"
      update_launch_template_default_version = true

    }
  }

}


################################################################################
# Supporting Resources
################################################################################

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 3.0"

  name = local.name
  cidr = "10.0.0.0/16"

  azs             = ["${var.region}a", "${var.region}b", "${var.region}c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  public_subnet_tags = {
    "kubernetes.io/cluster/${local.name}" = "shared"
    "kubernetes.io/role/elb"              = 1
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${local.name}" = "shared"
    "kubernetes.io/role/internal-elb"     = 1
  }

}
