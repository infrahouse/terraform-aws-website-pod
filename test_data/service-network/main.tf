module "service-network" {
  source  = "infrahouse/service-network/aws"
  version = "~> 2.3"

  environment           = "dev"
  service_name          = "test_data/terraform-aws-website-pod"
  vpc_cidr_block        = "10.1.0.0/16"
  management_cidr_block = "10.1.0.0/16"
  subnets = [
    {
      cidr                    = "10.1.0.0/24"
      availability-zone       = "${var.region}a"
      map_public_ip_on_launch = true
      create_nat              = true
      forward_to              = null
    },
    {
      cidr                    = "10.1.1.0/24"
      availability-zone       = "${var.region}b"
      map_public_ip_on_launch = true
      create_nat              = true
      forward_to              = null
    },
    {
      cidr                    = "10.1.2.0/24"
      availability-zone       = "${var.region}c"
      map_public_ip_on_launch = true
      create_nat              = true
      forward_to              = null
    },
    {
      cidr                    = "10.1.100.0/24"
      availability-zone       = "${var.region}a"
      map_public_ip_on_launch = false
      create_nat              = false
      forward_to              = "10.1.0.0/24"
    },
    {
      cidr                    = "10.1.101.0/24"
      availability-zone       = "${var.region}b"
      map_public_ip_on_launch = false
      create_nat              = false
      forward_to              = "10.1.1.0/24"
    },
    {
      cidr                    = "10.1.102.0/24"
      availability-zone       = "${var.region}c"
      map_public_ip_on_launch = false
      create_nat              = false
      forward_to              = "10.1.2.0/24"
    }
  ]
}
