
resource "aws_ssm_parameter" "###COIN_IAC_MOD_SPINALCASE###" {
  #checkov:skip=CKV2_AWS_34:Example SSM parameter - encryption not needed
  #checkov:skip=CKV_AWS_337:Example SSM parameter - KMS CMK not required
  name  = "/${var.appName}/${var.envName}/###COIN_IAC_MOD_SPINALCASE###-param"
  type  = "String"
  value = "bar"
}
