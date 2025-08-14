terraform {
  required_version = ">= 1.8.0"
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  tags = {
    "App" = "${var.appName}"
    "Env" = "${var.envName}"
  }

  appTags = {
    "App" = "${var.appName}"
  }
}
