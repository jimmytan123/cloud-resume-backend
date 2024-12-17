terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.81.0"
    }

    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.7.0"
    }
  }

  required_version = "~> 1.2"

  # The backend defines where Terraform stores its state data files
  backend "s3" {
    # The bucket, region and key will be added via the GitHub Action workflows
    encrypt = true
  }
}
