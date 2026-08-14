terraform {
  required_version = "~> 1.5"
  required_providers {
    aws = {
      source = "hashicorp/aws"
      # cpu_options.nested_virtualization in asg.tf requires AWS provider >= 6.33.0
      version = ">= 6.33.0, < 7.0.0"
      configuration_aliases = [
        aws.dns # AWS provider for DNS
      ]
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}
