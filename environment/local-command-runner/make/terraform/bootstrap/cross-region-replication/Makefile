
# Deploys the Terraform back end CloudFormation stack
deploy-tf-backend-cf-stack:
	@$(ENV_PATH)utility-functions.sh deploy_tf_backend_cf_stack "$(AWS_PRIMARY_REGION)"
	@$(ENV_PATH)utility-functions.sh deploy_tf_backend_cf_stack "$(AWS_SECONDARY_REGION)" "parameters-secondary.json"
	@$(ENV_PATH)utility-functions.sh deploy_tf_backend_cf_stack "$(AWS_PRIMARY_REGION)" "parameters-crr.json"

# Destroys the Terraform back end CloudFormation stack and deletes Terraform
# state files
destroy-tf-backend-cf-stack:
	@$(ENV_PATH)../build-script/empty-s3.sh empty_s3_bucket_by_name "$(TF_S3_BACKEND_NAME)-$(AWS_ACCOUNT_ID)-$(AWS_PRIMARY_REGION)"
	@$(ENV_PATH)utility-functions.sh destroy_tf_backend_cf_stack "$(AWS_PRIMARY_REGION)"
	@$(ENV_PATH)../build-script/empty-s3.sh empty_s3_bucket_by_name "$(TF_S3_BACKEND_NAME)-$(AWS_ACCOUNT_ID)-$(AWS_SECONDARY_REGION)"
	@$(ENV_PATH)utility-functions.sh destroy_tf_backend_cf_stack "$(AWS_SECONDARY_REGION)"