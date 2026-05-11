terraform {
  backend "s3" {
    bucket         = "task-api-tfstate-058898200941"
    key            = "envs/dev/terraform.tfstate"
    region         = "ap-northeast-1"
    dynamodb_table = "task-api-tflock"
    encrypt        = true
  }
}