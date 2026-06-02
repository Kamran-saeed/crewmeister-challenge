terraform {
  backend "s3" {
    bucket         = "crewmeister-terraform-state"
    key            = "github-runner/terraform.tfstate"
    region         = "eu-central-1"
    dynamodb_table = "crewmeister-terraform-state-lock"
    encrypt        = true
  }
}
