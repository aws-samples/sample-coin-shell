

# Start wizard that will auto-generate IaC deployment instructions
generate-deployment-instructions:
	@$(ENV_PATH)generate-deployment-instructions.sh "$(b)"

# Simple generate-deployment-instructions shortcut
gdi: generate-deployment-instructions

# Resolves all environment variables in template files, executes any terraform command that you 
# supply, then restores template files to their original content
# Note: to see a list of root Terraform module names, run 'make list-tf-modules'
# usage:
# 	make tf m=<my-module-name> c="<my Terraform command>"
# example:
# 	make tf m=my-module-name c="terraform init"
tf:
	$(ENV_PATH)utility-functions.sh exec_tf_command_for_env $(m) "$(c)"

# Print out the names of all of this project's root Terraform modules
list-tf-modules:
	$(ENV_PATH)utility-functions.sh print_root_terraform_modules

# Runs checkov scan against a root Terraform module
# Note: to see a list of root Terraform module names, run 'make list-tf-modules'
# usage:
# 	make tf m=<my-module-name>
# example:
# 	make tf m=my-module-name
checkov:
	$(ENV_PATH)utility-functions.sh exec_checkov $(m)

# Runs checkov scan against all root Terraform modules
checkov-all:
	$(ENV_PATH)utility-functions.sh exec_checkov_all
