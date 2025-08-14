
# deploy-cicd-iam-role-stack:
# 	(cd cicd/iam-role; \
# 	aws cloudformation deploy \
# 	--template-file iam-role.yml \
# 	--parameter-overrides file://parameters.json \
# 	--stack-name $(APP_NAME)-$(ENV_NAME)-cicd-role \
# 	--capabilities CAPABILITY_NAMED_IAM \
# 	--tags App=$(APP_NAME) Env=$(ENV_NAME);)

# destroy-cicd-iam-role-stack:
# 	aws cloudformation delete-stack \
# 	--stack-name $(APP_NAME)-$(ENV_NAME)-cicd-role
# 	aws cloudformation wait stack-delete-complete \
# 	--stack-name $(APP_NAME)-$(ENV_NAME)-cicd-role