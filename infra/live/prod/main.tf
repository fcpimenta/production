provider "aws" {
  region = "${var.AWS_DEFAULT_REGION}"
}

locals {
  az_count         = "${length(data.aws_availability_zones.available.names)}"
  az_a             = "${var.AWS_DEFAULT_REGION}a"
  az_b             = "${var.AWS_DEFAULT_REGION}b"
  az_c             = "${var.AWS_DEFAULT_REGION}c"
  kube_cluster_tag = "kubernetes.io/cluster/${var.cluster_name}"
}

module "vpc" {
  source = "../../modules/vpc"
  name   = "standard"
  az     = "${data.aws_availability_zones.available.names}"

  tags = {
    Environment                 = "staging"
    "${local.kube_cluster_tag}" = "shared"
  }
}

resource "aws_route53_zone" "k8s_private_zone" {
  name = "k8s.devopxlabs.com"

  vpc {
    vpc_id = "${element(module.vpc.vpc_id, 0)}"
  }
}

# Create 3 etcd nodes with HA
module "etcd-cluster" {
  source               = "../../modules/etcd"
  key_name               = "deploy-key"
  availability_zone    = ["${local.az_a}", "${local.az_b}", "${local.az_c}"]
  zone_suffix          = ["a", "b", "c"]
  iam_instance_profile = "${aws_iam_instance_profile.aws_iam_instance_profile.name}"
  sg_id                = "${element(module.etcd_sg.security_group_id, 0)}"
  zone_id              = "${aws_route53_zone.k8s_private_zone.zone_id}"
  subnet_id            = "${module.vpc.private_subnets_id}"
}

# Create Kubernetes masters
module "k8s-cluster" {
  source                 = "../../modules/kubernetes"
  nodes                  = 4
  key_name               = "deploy-key"
  cluster_tag            = "${local.kube_cluster_tag}"
  iam_instance_profile   = "${aws_iam_instance_profile.aws_iam_instance_profile.name}"
  availability_zone      = ["${local.az_a}", "${local.az_b}", "${local.az_c}"]
  sg_id                  = "${element(module.security_group.security_group_id, 0)}"
  zone_id                = "${aws_route53_zone.k8s_private_zone.zone_id}"
  subnet_id              = "${module.vpc.private_subnets_id}"
  api_lb_subnets         = "${module.vpc.public_subnets_id}"
  api_lb_vpc_id          = "${element(module.vpc.vpc_id, 0)}" 
 }

module "bastion" {
  source                      = "../../modules/instances"
  name                        = "Bastion"
  ami                         = "${data.aws_ami.latest-ubuntu.id}"
  instance_type               = "t2.micro"
  servers                     = 1
  key_name                    = "deploy-key"
  iam_instance_profile        = "${aws_iam_instance_profile.aws_iam_instance_profile.name}"
  availability_zone           = "${element(data.aws_availability_zones.available.names, 0)}"
  subnet_id                   = "${element(module.vpc.public_subnets_id, 0)}"
  public_ip_address           = true
  vpc_security_group_ids      = ["${module.ssh-sg.security_group_id}"]
}

# ssh -i './deploy-key' <instance ip or dns>

resource "aws_key_pair" "deploy" {
  key_name   = "deploy-key"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC+JU1XbsRml+fYSncdjJ3MAgt2NX5wsUmF0cnMSdfBWcJ3dygiKcnnj5FKPeNSOnHyYUKciFvmHZ0kVvX4pS5zmD1eZhB1iaHdnOFeSVN6tB+PnRdtUxtxIGyA89pb//0Xc01cWd6mGsXGXMHVZmc/D6iPWPXUJMK7o5Oc6uwWaFYBf0lB0105c0X6zUxKeix2sh7D6zWwYJCHjwPfljHKLcpJxOQpMM2Ja/tzdG95sWnfvTIBT/lmoUhJ3yZP6fVJgfa36PGykYxihyvW3xO3SN4l0ywXcse2vKC9qu+KUZ5nqZ7VKys6r1ix30nuuhZDzEbMHP76BitnEtoTGfVRPe1ASGPitsDJd3/VIjp2XnwkjMGV/Da7gnvCJtIIxLa4d52F4vs60HXtX40Ja+6c2FFdoSQg2ULNiPowTAG0IsxFwQKH0N85NnjN9DUyghxgJmMtsKc5kv2VKH7UGewDDVjOj+SCCWWt+rdYBYSHwR1LlhM0arP5J96Ku/c9CI3mC/Lvh373MsjvVjHkCgpnEr6sn7I8L35iKn6MPire2gMl3VleNvePNn51yrh2zfrhn6zpHeO8/5pELr/czuyzNsKZr5fJU6k4cOiNRzGeKnUhDKkt1CW3KIDMpqANic+oufIIUI4K7qaGGjOR410lxqCR4ZK5/LAyR5nzcyeF5Q== deploy@domain.io"
}
