provider "aws" {
  region = var.region

  default_tags {
    tags = {
      KeboolaStack = "keboola-calico-timeouts-JQ-24"
      KeboolaRole  = "keboola-calico-timeouts-JQ-24"
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
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "19.5.1"

  cluster_name                    = local.name
  cluster_version                 = local.cluster_version
  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  create_aws_auth_configmap = true
  manage_aws_auth_configmap = true

  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent          = true
      configuration_values = "{\"env\":{\"AWS_VPC_K8S_CNI_CUSTOM_NETWORK_CFG\":\"true\",\"ENI_CONFIG_LABEL_DEF\":\"failure-domain.beta.kubernetes.io/zone\",\"ENABLE_PREFIX_DELEGATION\":\"true\",\"WARM_PREFIX_TARGET\":\"1\"}}"
    }
  }

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

      instance_type                          = "t3a.large"
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

resource "aws_vpc_ipv4_cidr_block_association" "secondary_cidr" {
  vpc_id     = module.vpc.vpc_id
  cidr_block = "100.66.0.0/16"
}

resource "aws_vpc_ipv4_cidr_block_association" "secondary_cidr_2" {
  vpc_id     = module.vpc.vpc_id
  cidr_block = "100.67.0.0/16"
}


resource "aws_subnet" "pods_a" {
  vpc_id            = aws_vpc_ipv4_cidr_block_association.secondary_cidr.vpc_id
  cidr_block        = "100.66.0.0/17"
  availability_zone = "${var.region}a"

  tags = {
    Name = "pods-a"
  }
}


resource "aws_subnet" "pods_b" {
  vpc_id            = aws_vpc_ipv4_cidr_block_association.secondary_cidr.vpc_id
  cidr_block        = "100.66.128.0/17"
  availability_zone = "${var.region}b"

  tags = {
    Name = "pods-b"
  }
}

resource "aws_subnet" "pods_c" {
  vpc_id            = aws_vpc_ipv4_cidr_block_association.secondary_cidr_2.vpc_id
  cidr_block        = "100.67.0.0/17"
  availability_zone = "${var.region}c"

  tags = {
    Name = "pods-c"
  }
}


resource "kubernetes_manifest" "cni_config_a" {
  manifest = {
    "apiVersion" = "crd.k8s.amazonaws.com/v1alpha1"
    "kind"       = "ENIConfig"
    "metadata"   = {
      "name" = aws_subnet.pods_a.availability_zone
    }
    "spec" = {
      subnet         = aws_subnet.pods_a.id
      securityGroups = [module.eks.node_security_group_id]
    }
  }
}

resource "kubernetes_manifest" "cni_config_b" {
  manifest = {
    "apiVersion" = "crd.k8s.amazonaws.com/v1alpha1"
    "kind"       = "ENIConfig"
    "metadata"   = {
      "name" = aws_subnet.pods_b.availability_zone
    }
    "spec" = {
      subnet         = aws_subnet.pods_b.id
      securityGroups = [module.eks.node_security_group_id]
    }
  }
}

resource "kubernetes_manifest" "cni_config_c" {
  manifest = {
    "apiVersion" = "crd.k8s.amazonaws.com/v1alpha1"
    "kind"       = "ENIConfig"
    "metadata"   = {
      "name" = aws_subnet.pods_c.availability_zone
    }
    "spec" = {
      subnet         = aws_subnet.pods_c.id
      securityGroups = [module.eks.node_security_group_id]
    }
  }
}

