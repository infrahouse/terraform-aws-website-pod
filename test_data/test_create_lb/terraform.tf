terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.11"
    }
    template = {
      source  = "hashicorp/template"
      version = "~> 2.2"

    }
  }
}
