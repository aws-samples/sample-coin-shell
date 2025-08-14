#!/usr/bin/env bash

# This script allows you to change the names of directories that
# the environment scripts use as well as other settings.

# Set commands to be run before COIN takes any action
COIN_BEFORE_HOOKS+=('generate_make_env')
# COIN_BEFORE_HOOKS+=('generate_env_file')

# Set commands to be run after user switches the current environment
# COIN_AFTER_SWITCH_ENV_HOOKS+=('generate_env_file')

# Set application environment configuration key names that are okay to be 
# logged in clear text by a CICD pipeline
CLEAR_TEXT_ENV_KEYS+=('APP_NAME')
CLEAR_TEXT_ENV_KEYS+=('AWS_ACCOUNT_ID')
CLEAR_TEXT_ENV_KEYS+=('AWS_CREDS_TARGET_ROLE')
CLEAR_TEXT_ENV_KEYS+=('AWS_DEFAULT_REGION')
CLEAR_TEXT_ENV_KEYS+=('CREATED_BY')
CLEAR_TEXT_ENV_KEYS+=('ENV_NAME')
CLEAR_TEXT_ENV_KEYS+=('TF_S3_BACKEND_NAME')

# Color codes used for outputting text in color to the console
CYAN='\033[0;36m'
GRAY='\033[0;37m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color
PURPLE='\033[0;35m'
RED='\033[0;31m'
YELLOW='\033[1;33m'

# Directories or files that COIN should ignore when attempting to find files with placeholders that need to be resolved
# These will be fed into the grep utility
# Example: COIN_EXCLUDE_TEMPLATE_SEARCH="--exclude-dir=.venv --exclude-dir=node_modules --exclude=exampleFile.txt"
COIN_EXCLUDE_TEMPLATE_SEARCH="--exclude-dir=environment --exclude-dir=.terraform --exclude-dir=node_modules --exclude-dir=.venv"

# Set the package manager to use
coinPackageManager="npm" # can be set to "npm" or "yarn"

# Set the name of the JSON file that contains team constants
projectEnvConstantsFileName="environment-constants.json"

# Set the suffix to append to a filename when making a backup
BACKUP_SUFFIX=".bak"

# Set the path of the directory where the COIN scripts are located
projectEnvPath="/environment"

# Set directory where core environment scripts are
projectEnvDir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# Set application root directory
projectDir="${projectEnvDir/$projectEnvPath/}" # set app root directory to parent of $projectEnvDir

# Set the directory where non-coin configs are stored
projectConfigsPath="/config"
projectConfigsDir="${projectDir}${projectConfigsPath}"
projectConfigsEnvFileName=".env"

# Set the directory where infrastructure as code is stored
projectIacPath="/iac"
projectIacDir="${projectDir}${projectIacPath}"

# Set the directory where the infrastructure as code root modules are stored
projectIacRootModulePath="${projectIacPath}/roots"
projectIacRootModuleDir="${projectDir}${projectIacRootModulePath}"

# Set the directory where application build scripts are stored
projectBuildScriptPath="/build-script"
projectBuildScriptDir="${projectDir}${projectBuildScriptPath}"

# Set the name of the CICD module
projectCicdModuleName="cicd"

# Only used if IaC is CloudFormation. This value is ignored for CDK or Terraform
# Set the directory where CICD files are stored
projectCicdPath="/$projectCicdModuleName"
projectCicdDir="${projectDir}${projectCicdPath}"

# Set the name of the file where the current environment is set
projectCurrentEnvFileName="$projectEnvDir/.current-environment"

# Set to "y" if COIN template resolution should occur when CDK commands are run
projectCdkResolveTemplates="n"

# Set to "y" if you want to clear CDK context/cache before running a CDK deploy command
projectCdkClearCache="y"

# Set to "y" if you want COIN to swap .terraform/terraform.tfstate files based on your current environment or "n" if not
projectToggleTerraformStateFiles="y"

# Set to "y" if you want the CUR_DIR_NAME placeholder to be resolved with the full path to the IaC module 
# under the $projectIacRootModulePath directory.
# Example: We have an IaC module at iac/roots/my/nested/dir
# With projectUseNestedPathForCurDirName="y", CUR_DIR_NAME will resolve to "my/nested/dir"
# With projectUseNestedPathForCurDirName="n", CUR_DIR_NAME will resolve to "dir"
projectUseNestedPathForCurDirName="y"

# The protocol to use (http or https) for API calls to GitLab
projectGitLabApiProtocol="https"

# An optional prefix to be used before the git domain when setting the generated application's remote origin
# Example: "ssh."
gitRemoteOriginPrefix=""

# The default Git service provider, used if the provider can't be determined from the Git host name
# Valid values: "gitlab", "github", "bitbucket", "azuredevops"
defaultGitProvider="gitlab"
