
# Executes cdk bootstrap against the current environment's AWS account for the
# AWS_DEFAULT_REGION
# You can supply an optional region argument to deploy the CDK stack to the region
# of your choice.
# usage: 
#   make deploy-cdk2-bootstrap-cf-stack
#   OR
#   make deploy-cdk2-bootstrap-cf-stack region=<myChosenAWSRegion>
deploy-cdk2-bootstrap-cf-stack:
	@$(ENV_PATH)utility-functions.sh deploy_cdk_bootstrap_cf_stack "$(region)"

# Executes cloudformation delete-stack against the current environment's AWS 
# account for the AWS_DEFAULT_REGION
# You can supply an optional region argument to destroy the CDK stack from the region
# of your choice.
# usage: 
#   make destroy-cdk2-bootstrap-cf-stack
#   OR
#   make destroy-cdk2-bootstrap-cf-stack region=<myChosenAWSRegion>
destroy-cdk2-bootstrap-cf-stack:
	@$(ENV_PATH)utility-functions.sh destroy_cdk_bootstrap_cf_stack "$(region)"
