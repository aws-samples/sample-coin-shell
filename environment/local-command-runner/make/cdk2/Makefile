
# Start wizard that will auto-generate IaC deployment instructions
generate-deployment-instructions:
	@$(ENV_PATH)generate-deployment-instructions.sh "$(b)"

# Simple generate-deployment-instructions shortcut
gdi: generate-deployment-instructions

# Sets environment variables, then executes any CDK command that you supply
# usage:
# 	make runcdk m=<my-module-name> c="<my CDK command>"
# example:
# 	make runcdk m=COIN_IAC_FIRST_MODULE_PLACEHOLDER c="cdk synth STACK_ID --exclusively"
runcdk:
	$(ENV_PATH)utility-functions.sh exec_cdk_command_for_env $(m) "$(c)"
