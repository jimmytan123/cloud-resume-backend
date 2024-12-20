# Configure the AWS Provider
provider "aws" {
  region = var.aws_region

  # Add default tag and apply across all resources handled by this provider
  default_tags {
    tags = {
      project = "cloud-resume-backend-with-terraform"
    }
  }

  # Credentials
  # Comment out when using GitHub Actions
  # profile = "dev" # my aws profile
}
