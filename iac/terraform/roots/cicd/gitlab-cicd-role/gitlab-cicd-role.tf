resource "aws_iam_role" "gitlab-cicd-role" {
  name                 = "${var.appName}-${var.envName}-cicd-role"
  description          = "CICD role for use by the ${var.appName} project"
  max_session_duration = 10800
  tags                 = local.tags

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        "Sid" : "GitLabCicdPipeline",
        "Effect" : "Allow",
        "Principal" : {
          "AWS" : "${var.gitLabAssumeRoleArn}"
        },
        "Action" : [
          "sts:AssumeRole",
          "sts:TagSession"
        ],
        "Condition" : {
          "StringEquals" : {
            "aws:PrincipalTag/GitLab:Group" : "${var.gitLabGroup}",
            "aws:PrincipalTag/GitLab:Project" : "${var.gitLabProject}"
          }
        }
      }
    ]
  })

  inline_policy {
    name = "${var.appName}-${var.envName}-example-policy"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          "Sid" : "Params",
          "Effect" : "Allow",
          "Action" : [
            "ssm:*"
          ],
          "Resource" : [
            "arn:aws:ssm:*:${data.aws_caller_identity.current.account_id}:parameter/${var.appName}-*"
          ]
        }
      ]
    })
  }

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/PowerUserAccess"
  ]

}
