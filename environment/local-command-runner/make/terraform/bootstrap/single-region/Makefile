
# Deploys the Terraform back end CloudFormation stack
deploy-tf-backend-cf-stack:
	@$(ENV_PATH)utility-functions.sh deploy_tf_backend_cf_stack "$(AWS_DEFAULT_REGION)"

# Destroys the Terraform back end CloudFormation stack and deletes Terraform
# state files
destroy-tf-backend-cf-stack:
	@$(ENV_PATH)../build-script/empty-s3.sh empty_s3_bucket_by_name "$(TF_S3_BACKEND_NAME)-$(AWS_ACCOUNT_ID)-$(AWS_DEFAULT_REGION)"
	@$(ENV_PATH)utility-functions.sh destroy_tf_backend_cf_stack "$(AWS_DEFAULT_REGION)"