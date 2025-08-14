
terraform {

  backend "s3" {

    bucket         = "###TF_S3_BACKEND_NAME###-###AWS_ACCOUNT_ID###-###AWS_DEFAULT_REGION###"
    key            = "###ENV_NAME###/###CUR_DIR_NAME###/terraform.tfstate"
    dynamodb_table = "###TF_S3_BACKEND_NAME###-lock"
    region         = "###AWS_DEFAULT_REGION###"
    encrypt        = true
  }
}
