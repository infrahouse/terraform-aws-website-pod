provider "aws" {
  assume_role {
    role_arn = "arn:aws:iam::303467602807:role/ih-tf-cicd-control"
  }
  region = var.region
  default_tags {
    tags = {
      "created_by" : "infrahouse/terraform-aws-website-pod" # GitHub repository that created a resource
    }

  }
}
