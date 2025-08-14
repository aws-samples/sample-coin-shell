
deploy-tf-backend-cf-stack:
	aws cloudformation deploy \
	--template-file ./iac/bootstrap/tf-backend-cf-stack.yml \
	--stack-name $(TF_S3_BACKEND_NAME) \
	--tags App=$(APP_NAME) Env=$(ENV_NAME) \
	--region $(AWS_PRIMARY_REGION) \
	--capabilities CAPABILITY_NAMED_IAM \
	--parameter-overrides file://iac/bootstrap/parameters.json
	aws cloudformation deploy \
	--template-file ./iac/bootstrap/tf-backend-cf-stack.yml \
	--stack-name $(TF_S3_BACKEND_NAME) \
	--tags App=$(APP_NAME) Env=$(ENV_NAME) \
	--region $(AWS_SECONDARY_REGION) \
	--capabilities CAPABILITY_NAMED_IAM \
	--parameter-overrides file://iac/bootstrap/parameters-secondary.json
	aws cloudformation deploy \
	--template-file ./iac/bootstrap/tf-backend-cf-stack.yml \
	--stack-name $(TF_S3_BACKEND_NAME) \
	--tags App=$(APP_NAME) Env=$(ENV_NAME) \
	--region $(AWS_PRIMARY_REGION) \
	--capabilities CAPABILITY_NAMED_IAM \
	--parameter-overrides file://iac/bootstrap/parameters-crr.json

destroy-tf-backend-cf-stack:
	@./build-script/empty-s3.sh empty_s3_bucket_by_name "$(TF_S3_BACKEND_NAME)-$(AWS_ACCOUNT_ID)-$(AWS_PRIMARY_REGION)"
	aws cloudformation delete-stack \
	--stack-name $(TF_S3_BACKEND_NAME) \
	--region $(AWS_PRIMARY_REGION)
	aws cloudformation wait stack-delete-complete \
	--stack-name $(TF_S3_BACKEND_NAME) \
	--region $(AWS_PRIMARY_REGION)
	@./build-script/empty-s3.sh empty_s3_bucket_by_name "$(TF_S3_BACKEND_NAME)-$(AWS_ACCOUNT_ID)-$(AWS_SECONDARY_REGION)"
	aws cloudformation delete-stack \
	--stack-name $(TF_S3_BACKEND_NAME) \
	--region $(AWS_SECONDARY_REGION)
	aws cloudformation wait stack-delete-complete \
	--stack-name $(TF_S3_BACKEND_NAME) \
	--region $(AWS_SECONDARY_REGION)
