# The bucket is created MANUALLY (versioning + default encryption ON), as allowed by the task.
# Backend blocks cannot use variables, so edit the values below.
# Each workspace stores its state under: env:/<workspace>/movie-analyst/terraform.tfstate
terraform {
  backend "s3" {
    bucket       = "CHANGE-ME-movie-analyst-tfstate"
    key          = "movie-analyst/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true # native S3 locking (Terraform >= 1.10), no DynamoDB table needed
  }
}
