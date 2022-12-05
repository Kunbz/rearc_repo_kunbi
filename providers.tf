# Configure the AWS Provider
provider "aws" {
  region     = var.region
}

provider "aws" {
  alias = "virginia"
  region     = var.region
}
