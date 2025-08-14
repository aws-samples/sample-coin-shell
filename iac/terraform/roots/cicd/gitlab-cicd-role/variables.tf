
variable "gitLabGroup" {
  description = "group/namespace that gitlab repository resides in"
  type        = string
}

variable "gitLabProject" {
  description = "gitlab repository project name"
  type        = string
}

variable "gitLabAssumeRoleArn" {
  description = "The ARN of the role that can assume the CICD role"
  default = "arn:aws:iam::979517299116:role/gitlab-runners-prod"
  type        = string
}
