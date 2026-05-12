terraform {
  backend "s3" {
    key            = "envs/dev/terraform.tfstate"
    region         = "ap-northeast-1"
    dynamodb_table = "task-api-tflock"
    encrypt        = true
  }
}