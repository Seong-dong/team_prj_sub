// prod - main
provider "aws" {
  region                  = "ap-northeast-2"
  profile                 = "22shop"
  shared_credentials_file = "~/.aws/credentials"
  #2.x버전의 AWS공급자 허용
  version = "~> 3.0"

}

locals {
  region = "ap-northeast-2"
  common_tags = {
    project = "22shop-web"
    owner   = "icurfer"
  }
  cidr = {
    vpc    = "10.1.0.0/16"
    zone_a = "10.1.1.0/24"
    zone_c = "10.1.3.0/24"
    zone_a_private = "10.1.2.0/24"
    zone_c_private = "10.1.4.0/24"
    zone_a_tgw = "10.1.5.0/24"
    zone_c_tgw = "10.1.6.0/24"
  }
  tcp_port = {
    any_port    = 0
    http_port   = 80
    https_port  = 443
    ssh_port    = 22
    dns_port    = 53
    django_port = 8000
    mysql_port  = 3306
  }
  udp_port = {
    dns_port = 53
  }
  any_protocol  = "-1"
  tcp_protocol  = "tcp"
  icmp_protocol = "icmp"
  all_ips       = ["0.0.0.0/0"]

}

// GET 계정정보
data "aws_caller_identity" "this" {}

//vpc 생성
module "vpc_hq" {
  source = "../modules/vpc"
  #   source = "github.com/Seong-dong/team_prj/tree/main/modules/vpc"
  tag_name   = "${local.common_tags.project}-vpc"
  cidr_block = local.cidr.vpc

}

//외부통신 gateway
module "vpc_igw" {
  source = "../modules/igw"

  vpc_id = module.vpc_hq.vpc_hq_id

  tag_name = "${local.common_tags.project}-vpc_igw"

  depends_on = [
    module.vpc_hq
  ]
}

// public 서브넷 생성
module "subnet_public" {
  source = "../modules/vpc-subnet"

  vpc_id         = module.vpc_hq.vpc_hq_id
  subnet-az-list = {
    "zone-a" = {
      name = "${local.region}a"
      cidr = local.cidr.zone_a
    }
    "zone-c" = {
      name = "${local.region}c"
      cidr = local.cidr.zone_c
    }
  }
  public_ip_on   = true
}
// private외부통신을 위한 nat
module "nat_gw" {
  source = "../modules/nat-gateway"
  subnet_id = module.subnet_public.subnet.zone-a.id
  nat_name = "nat-gw_web"

  depends_on = [
    module.vpc_igw
  ]
}

// public route
module "route_public" {
  source   = "../modules/route-table"
  tag_name = "${local.common_tags.project}-public_tbl-sdjo"
  vpc_id   = module.vpc_hq.vpc_hq_id

}

module "route_add" {
  source          = "../modules/route-add"
  route_id = module.route_public.route_id
  igw_id          = module.vpc_igw.igw_id
  gw_type = "igw"
}

module "route_association" {
  source         = "../modules/route-association"
  route_table_id = module.route_public.route_id

  association_count = 2
  subnet_ids        = [module.subnet_public.subnet.zone-a.id, module.subnet_public.subnet.zone-c.id]
}
#----------------------------------------------------------------------------------------------------#
######################################################################################################
#----------------------------------------------------------------------------------------------------#
module "subnet_private" {
  source = "../modules/vpc-subnet"

  vpc_id         = module.vpc_hq.vpc_hq_id
  subnet-az-list = {
    "zone-a" = {
      name = "${local.region}a"
      cidr = local.cidr.zone_a_private
    }
    "zone-c" = {
      name = "${local.region}c"
      cidr = local.cidr.zone_c_private
    }
  }
  public_ip_on   = false
}

// private route
module "route_private" {
  source   = "../modules/route-table"
  tag_name = "${local.common_tags.project}-private_tbl-sdjo"
  vpc_id   = module.vpc_hq.vpc_hq_id

}
module "route_add_nat" {
  source          = "../modules/route-add"
  route_id = module.route_private.route_id
  nat_id = module.nat_gw.nat_id
  gw_type = "nat"
}
module "route_association_nat" {
  source         = "../modules/route-association"
  route_table_id = module.route_private.route_id

  association_count = 2
  subnet_ids        = [module.subnet_private.subnet.zone-a.id, module.subnet_private.subnet.zone-c.id]
}

#----------------------------------------------------------------------------------------------------#
######################################################################################################
#----------------------------------------------------------------------------------------------------#
//tgw-subnet
module "subnet_private_tgw" {
  source = "../modules/vpc-subnet"

  vpc_id         = module.vpc_hq.vpc_hq_id
  subnet-az-list = {
    "zone-a" = {
      name = "${local.region}a"
      cidr = local.cidr.zone_a_tgw
    }
    "zone-c" = {
      name = "${local.region}c"
      cidr = local.cidr.zone_c_tgw
    }
  }
  public_ip_on   = false
}
// private route
module "route_private_tgw" {
  source   = "../modules/route-table"
  tag_name = "${local.common_tags.project}-private_tbl_tgw-sdjo"
  vpc_id   = module.vpc_hq.vpc_hq_id

}
module "route_association_tgw" {
  source         = "../modules/route-association"
  route_table_id = module.route_private_tgw.route_id

  association_count = 2
  subnet_ids        = [module.subnet_private_tgw.subnet.zone-a.id, module.subnet_private_tgw.subnet.zone-c.id]
}