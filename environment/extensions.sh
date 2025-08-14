#!/usr/bin/env bash

# This script allows you to override/customize settings and behaviors to suit your needs

# Extension point that allows you to define additional questions that you want to be asked by the Create App Wizard.
ask_custom_create_app_questions () {
    log "\nexecuting ask_custom_create_app_questions\n"
}

# Extension point that allows you to define input validation logic that you want to be run by the Create App Wizard
# when it is running in headless mode
ask_custom_create_app_questions_headless_input_validation () {
    log "\nexecuting ask_custom_create_app_questions_headless_input_validation\n"
}

# Extension point that allows you to define additional actions that you want to be taken by the Create App Wizard.
take_custom_create_app_actions () {
    log "\nexecuting take_custom_create_app_actions\n"
}

# Extension point that allows you to define additional deployment actions that you want to be taken by the Create App Wizard.
take_custom_create_app_deployment_actions () {
    log "\nexecuting take_custom_create_app_deployment_actions\n"
}

# Extension point that allows you to define additional questions that you want to be asked by the Create App Environment Wizard.
ask_custom_create_app_environment_questions () {
    log "\nexecuting ask_custom_create_app_environment_questions\n"
}

# Extension point that allows you to define input validation logic that you want to be run by the Create App Environment Wizard
# when it is running in headless mode
ask_custom_create_app_environment_questions_headless_input_validation () {
    log "\nexecuting ask_custom_create_app_environment_questions_headless_input_validation\n"
}

# Extension point that allows you to define additional actions that you want to be taken by the Create App Environment Wizard.
take_custom_create_app_environment_actions () {
    log "\nexecuting take_custom_create_app_environment_actions\n"
}

# Extension point that allows you to define additional deployment actions that you want to be taken by the Create App Environment Wizard.
take_custom_create_app_environment_deployment_actions () {
    log "\nexecuting take_custom_create_app_environment_deployment_actions\n"
}

# Extension point that allows you to define additional logic for configuring a new git repository, such as to add
# custom configurations to the .git/config file
take_custom_git_config_actions () {
    log "\nexecuting take_custom_git_config_actions\n"

    # Example
    # echo -e "some configs" >> .git/config
}

# Extension point that allows you to map Git service domains to a provider type.
# parameter1: the git remote origin of the application
# Valid values: "gitlab", "github", "bitbucket", "azuredevops"
custom_git_provider_resolver () {
    local gitOriginValue="$1"
    log "\nexecuting custom_git_provider_resolver on origin \"$gitOriginValue\"\n"

    # Example implementation:
    # if [[ "$gitOriginValue" == *"example.com"* ]]; then
    #     echo "gitlab"
    # else
    #     echo "unknown"
    # fi

    echo "unknown"
}

# Sets curl command for use with GitLab APIs. This can be customized, such as to send cookies.
# Sets gitLabCurlCommand as a global variable
set_gitlab_curl_command () {
    log "\nexecuting set_gitlab_curl_command\n"
    
    gitLabCurlCommand="curl"

    # Here is how you could customize the curl command for calling GitLab APIs so that it passes
    # in cookies for two factor authentication
    # gitLabCurlCommand="curl -L -b ~/.some/cookie -c ~/.some/cookie"
}

# Creates an AWS CLI profile entry in ~/.aws/config to use for mapping a CLI profile to an environment.
# Only creates the new entry if the profile name has not already been configured in that file.
create_aws_cli_profile () {
    log "\nexecuting create_aws_cli_profile\n"

    # Example code below

    # if [[ -z "$coinAwsCliProfileName" ]] || [[ "$coinAwsCliProfileName" == "blank" ]]; then
    #     log "\nSkipping creating AWS CLI profile in ~/.aws/config since coinAwsCliProfileName was empty or blank.\n"
    #     return 0
    # fi

    # if [[ ! -d "${HOME}/.aws" ]]; then
    #     mkdir "${HOME}/.aws"
    #     log "Created directory: ${HOME}/.aws"
    # fi

    # if [[ ! -f "${HOME}/.aws/config" ]]; then 
    #     touch "${HOME}/.aws/config"
    #     log "Created file: ${HOME}/.aws/config"
    # fi

    # # Check if profile already exists
    # if ! grep -q "profile ${coinAwsCliProfileName}" "${HOME}/.aws/config"; then

    #     local awsAccountNameForProfile=<get-profile-name>
    #     if [[ -z "$awsAccountNameForProfile" ]]; then
    #         displayIssue "\nCould not find account ${AWS_ACCOUNT_ID}" "error"
    #         return 0
    #     else 
    #         awsAccountNameForProfile=<profile-name>
    #     fi

    #     local coinNewProfileConfig="[profile ${APP_NAME}-${ENV_NAME}]\noutput = json\nregion = ${AWS_DEFAULT_REGION}\n"
    #     coinNewProfileConfig="${coinNewProfileConfig}credential_process = my-tool credentials --awscli ${awsAccountNameForProfile} --role Admin --region ${AWS_DEFAULT_REGION}"

    #     echo -e "\n${coinNewProfileConfig}" >> "$HOME/.aws/config"

    #     display "\nAppended the below profile configuration to ~/.aws/config\n"

    #     displayInColor "$coinNewProfileConfig" "$CYAN"
    # else
    #     log "\nSkipping creating AWS CLI profile in ~/.aws/config since the \"${coinAwsCliProfileName}\" profile already exists.\n"
    # fi
}

# Asks if you want to map an AWS CLI profile to an environment. Has the ability to create new profiles in ~/.aws/config
# or use a user-entered profile name
optionally_ask_if_create_aws_cli_profile_mapping () {
    log "\nexecuting optionally_ask_if_create_aws_cli_profile_mapping\n"

    # Example code below

    # if [[ "$awsDeployDisabled" == "y" ]]; then
    #     return 0
    # fi

    # display "\nYou can optionally map an AWS CLI profile to a COIN environment so that COIN will automatically use the right CLI profile for your current COIN environment."
    # display "Select your preference:"
    # coinMapCliProfileToEnvChoice=$(select_with_default "Create a new \"${APP_NAME}-${ENV_NAME}\" AWS profile entry for me in ~/.aws/config|Use an existing AWS CLI profile|Skip this - I will manually log in to the AWS CLI without using a profile" 'create|use|disable' 'create')

    # if [[ "$coinMapCliProfileToEnvChoice" == "create" ]]; then

    #     coinAwsCliProfileName="${APP_NAME}-${ENV_NAME}"
    #     create_aws_cli_profile

    # elif [[ "$coinMapCliProfileToEnvChoice" == "use" ]]; then
    #     length_range coinAwsCliProfileName "Enter the AWS CLI profile name to map to the COIN \"${ENV_NAME}\" environment:" "${APP_NAME}-${ENV_NAME}" "1" "90"
    # fi

    # log "\ncoinAwsCliProfileName got set to \"${coinAwsCliProfileName}\"\n"

}
