# Delete App Environment Wizard Test Cases

The delete app environment wizard is defined here: `environment/delete-app-environment.sh`

## Logging

Should log wizard-session debugging information to `environment/.log.txt`

## Environment Choice

Should display the current local environments and ask the user which one to delete. The first environment found should be the default choice.

## Confirmation

Should confirm that the user is sure about deleting the selected environment. The default answer is no. If the user selects "no", the script should exit immediately.

## Check AWS CLI session

If the environment's AWS_ACCOUNT_ID setting does not match the CLIs session
* Should log an explanatory error
* Should stop executing

## GitLab Stored Environment Variable Deletion

* If the environment stores values in GitLab
  * Ask the user for the GitLab personal access token value.
  * Skip deleting GitLab variables if the user does not enter a personal access token
  * Ask if the user wants to delete GitLab environment variables
    * If yes
      * call GitLab APIs to delete environment variables
      * print and log each call to GitLab
        * Log message should state whether or not the variable was configured and whether it was deleted or not
        * Log message should show what failed if the command failed due to reasons such as a bad personal access token
      * Ask if the user wants to delete the GitLab environment itself
        * If yes, call GitLab APIs and log the result
        * If no, skip deleting the GitLab environment

## SSM Stored Environment Variable Deletion

* If the environment stores values in the SSM Parameter Store
  * Confirm that the user wants to delete the SSM values
    * If yes, delete the values and log each call
    * If no, do not delete SSM values

## Deleting the CICD stack

* If the application has NOT been configured with a CICD module
  * Do not ask the user about deleting the CICD stack
* If the application is configured with a CICD module
  * Ask if the user wants to delete the CICD stack
    * If yes, delete the stack
    * If no, do not attempt to delete the stack

## CDK Bootstrap Stack

* If the application is set to use CDK, ask if the user wants to delete the CDK bootstrap CloudFormation stack
  * If yes, delete the bootstrap stack
  * If no, skip deleting the bootstrap stack
* If the application is NOT using CDK, do not ask about deleting the CDK bootstrap CloudFormation stack

## Terraform Back End Stack

* If the application is set to use Terraform, ask if the user wants to delete the Terraform back end CloudFormation stack
  * If yes, delete the back end stack
  * If no, skip deleting the back end stack
* If the application is NOT using Terraform, do not ask about deleting the Terraform back end CloudFormation stack

## Local environment JSON file

* Ask if the user wants to delete the .environment-\<envName\>.json file
  * If yes
    * Delete the file out of the `environment` directory
    * Ask the user to pick a new current environment
  * If no, skip deleting the JSON file
* If the current environmentment does not match the environment being deleted
  * Should delete the correct environment JSON file





