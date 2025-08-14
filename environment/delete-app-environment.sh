#!/usr/bin/env bash

# This script is a wizard that will delete an application environment
# for you by walking you through a guided series of questions

scriptDir="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "$scriptDir/utility-functions.sh" "source delete_env_wizard" 1> /dev/null

# Exports (as environment variables) all values defined in the supplied .json
# file so that this wizard can run in headless mode.
# param1: a working path (absolute or relative) to the JSON file 
#         containing wizard answers
export_wizard_answers () {
    
    if ! command -v jq --version &> /dev/null
    then
        displayIssue "jq could not be found. Please install jq, then run this script again." "error"
        exit 1
    fi

    if [[ ! -f "$1" ]]; then
        displayIssue "Failed to get headless mode values from JSON file." "error"
        displayIssue "File \"$1\" does not exist."
        exit 1
    fi

    if jq empty "$1" 2>/dev/null; then
        log "Headless input contains structurally valid JSON"
    else
        displayIssue "Headless input contains structurally invalid JSON" "error"
        exit 1
    fi

    eval "export $(jq -r 'to_entries | map("\(.key)=\(.value)") | @sh' "$1")"
}

validate_headless_mode_input () {

    [[ ! "$deleteEnv" =~ ^[^[:space:]]{1,80}$ ]] && \
    displayIssue "\"deleteEnv\" value is invalid: \"$newIacModuleName\"." "error" && \
    displayIssue "Must not include whitespace and length (${#deleteEnv}) must be between 1 and 6." && \
    exit 1

    [[ ! -f "$projectEnvDir/.environment-$deleteEnv.json" ]] && \
    displayIssue "\"deleteEnv\" value is invalid: \"$deleteEnv\"." "error" && \
    displayIssue "No JSON file exists for this environment" && \
    exit 1

    if [[ "$REMOTE_ENV_VAR_LOC" != "na" ]]; then
        validate_yes_or_no "deleteRemoteEnv" "$deleteRemoteEnv"
    fi

    if [[ ! -z "$AWS_CREDS_TARGET_ROLE" ]]; then
        validate_yes_or_no "deleteCicdCloudResources" "$deleteCicdCloudResources"
    fi

    if [[ ! -z "$TF_S3_BACKEND_NAME" ]]; then
        validate_yes_or_no "deleteTfBackendStack" "$deleteTfBackendStack"
    fi

    validate_yes_or_no "deleteConfig" "$deleteConfig"

    cdkJsonFile=$(find "$projectIacDir" -type f -name 'cdk.json')
    if [[ ! -z "$cdkJsonFile" ]]; then
        validate_yes_or_no "deleteCdk2BootstrapStack" "$deleteCdk2BootstrapStack"
    fi
}

display "\nWelcome to the Delete Application Environment Wizard!\n"

validate_bash_version
source "$scriptDir/../build-script/empty-s3.sh" "" 1> /dev/null

display "Note: This wizard does NOT delete a running application. Instead, it deletes the assets"
display "that were created to support deploying your application to an isolated environment."
display "Before deleting environment assets, you should delete the application itself from the"
display "environment, such as by running \"terraform destroy\" or \"cdk destroy\" for example.\n"
display "By continuing this wizard, you will be given a choice of which environment assets you"
display "wish to delete.\n"
display "Things that can be deleted by this wizard:"
display "  * Environment variables set on remote stores such as AWS Parameter Store or GitLab CI"
display "  * CICD pipeline IAM role CloudFormation stack"
display "  * Terraform back end CloudFormation stack"
display "  * CDK bootstrap CloudFormation stack"
display "  * Local environment-<env>.json that holds the configurations for the environment\n"

if [[ ! -z "$1" ]]; then
    export HEADLESS="y"

    display "Running in headless mode."

    log "\nHeadless file input:"
    log "$(cat "$1")"

    export_wizard_answers "$1"
    validate_headless_mode_input

else 

    choose_local_environment deleteEnv "Which environment would you like to delete?"
    yes_or_no deleteEnvSure "\nAre you sure you want to delete the \"$deleteEnv\" environment?" "n"
    display ""

    if [[ "$deleteEnvSure" != "y" ]]; then
        exit 0
    fi

fi

origCurEnv=$(get_current_env)
set_current_env "$deleteEnv"

# Clear cache for old environment and re-source utility functions so that 
# all variables reference the selected environment
ENV_RECONCILED_JSON=""
COIN_ENV_VAR_FILE_NAME=""
source "$scriptDir/utility-functions.sh" "source delete_env_wizard" 1> /dev/null

if [[ "$AWS_ACCOUNT_ID" != "000000000000" ]]; then
    set_aws_cli_profile
    validate_aws_cli_account || exit 1

    # Delete remote variables from Parameter Store if applicable
    if [[ "$REMOTE_ENV_VAR_LOC" == "ssm" ]]; then
        delete_ssm_remote_vars_for_env
    fi
fi

if [[ "$REMOTE_ENV_VAR_LOC" == "gitlab" ]]; then
    declare gitLabToken

    if [[ "$HEADLESS" == "y" ]]; then
        gitLabToken="$gltoken"
    else
        display "\nPreparing to delete environment variables from GitLab..."
        ask_gitlab_token gitLabToken ""
    fi

    if [[ -z "$gitLabToken" ]]; then
        display "Skipping deleting environment data from GitLab due to no GitLab token."
    else 
        delete_gitlab_cicd_vars_for_env "$gitLabToken"
        delete_gitlab_cicd_environment "$gitLabToken"
    fi
fi

# Delete CICD pipeline cloud resources if applicable
if [[ ! -z "$AWS_CREDS_TARGET_ROLE" ]] && [[ "$AWS_ACCOUNT_ID" != "000000000000" ]]; then

    if [[ "$HEADLESS" != "y" ]]; then
        yes_or_no deleteCicdCloudResources "\nAre you sure you want to delete the CICD pipeline cloud resources?" "n"
    elif [[ "$deleteCicdCloudResources" == "n" ]]; then
        log "Skipping deleting CICD pipeline cloud resources due to deleteCicdCloudResources config"
    fi

    display ""

    if [[ "$deleteCicdCloudResources" == "y" ]]; then
        display "Deleting CICD cloud resources ..."
        make destroy-cicd
        display "  DONE Deleting CICD cloud resources"
    fi
fi

# Delete Terraform backend if applicable
if [[ ! -z "$TF_S3_BACKEND_NAME" ]] && [[ "$AWS_ACCOUNT_ID" != "000000000000" ]]; then
    tfStackName="$TF_S3_BACKEND_NAME"

    if [[ "$HEADLESS" != "y" ]]; then
        display "\n${YELLOW}WARNING: make sure that you have executed \"terraform destroy\"${NC}"
        display "${YELLOW}to delete your application before you delete the Terraform back end${NC}\n"

        yes_or_no deleteTfBackendStack "Are you sure you want to delete the Terraform back end CloudFormation stack \"$tfStackName\"?" "n"
        display ""
    elif [[ "$deleteTfBackendStack" == "n" ]]; then
        log "Skipping deleting Terraform backend stack due to deleteTfBackendStack config"
    fi

    if [[ "$deleteTfBackendStack" == "y" ]]; then
        empty_s3_bucket_by_name "$APP_NAME-$ENV_NAME-tf-back-end-$AWS_ACCOUNT_ID-$AWS_DEFAULT_REGION"
        display "\nDeleting CloudFormation stack \"$tfStackName\" ..."
        aws cloudformation delete-stack --stack-name "$tfStackName"
        aws cloudformation wait stack-delete-complete --stack-name "$tfStackName"
        display "  DONE Deleting CloudFormation stack \"$tfStackName\""
    fi
fi

# Delete CDK v2 bootstrap CloudFormation stack if applicable
cdkJsonFile=$(find "$projectIacDir" -type f -name 'cdk.json')
if [[ ! -z "$cdkJsonFile" ]]; then
    cdk2StackName="CDKToolkit"

    if [[ "$HEADLESS" != "y" ]]; then
        display "\n${YELLOW}WARNING: make sure that you have executed \"cdk destroy\"${NC}"
        display "${YELLOW}to delete your application before you delete the CDK bootstap stack.${NC}"
        display "${YELLOW}Do not delete the CDK bootstrap stack if other applications have${NC}"
        display "${YELLOW}been deployed to your account that utilize CDK${NC}.\n"

        yes_or_no deleteCdk2BootstrapStack "Are you sure you want to delete the CDK v2 bootstrap CloudFormation stack \"$cdk2StackName\"?" "n"
        display ""

    elif [[ "$deleteCdk2BootstrapStack" == "n" ]]; then
        log "Skipping deleting CDK bootstrap stack due to deleteCdk2BootstrapStack config"
    fi

    if [[ "$deleteCdk2BootstrapStack" == "y" ]]; then
        cdkBucketName="cdk-hnb659fds-assets-$AWS_ACCOUNT_ID-$AWS_DEFAULT_REGION"
        empty_s3_bucket_by_name "$cdkBucketName"
        display "\nDeleting CDK v2 Bootstrap CloudFormation stack \"$cdk2StackName\" ..."
        aws cloudformation delete-stack --stack-name "$cdk2StackName" --region "$AWS_DEFAULT_REGION"
        aws cloudformation wait stack-delete-complete --stack-name "$cdk2StackName" --region "$AWS_DEFAULT_REGION"
        display "  DONE Deleting CDK v2 Bootstrap CloudFormation stack \"$cdk2StackName\""
    fi
fi

# delete .environment-<env>.json file
if [[ "$HEADLESS" != "y" ]]; then
    display ""
    yes_or_no deleteConfig "Are you sure you want to delete the local environment configuration file at \"$COIN_ENV_VAR_FILE_NAME\"?" "n"
    display ""
elif [[ "$deleteConfig" == "n" ]]; then
    log "Skipping deleting environment JSON file due to deleteConfig config"    
fi

if [[ "$deleteConfig" == "y" ]]; then
    rm "$COIN_ENV_VAR_FILE_NAME"
    display "DELETED: \"$COIN_ENV_VAR_FILE_NAME\"\n"

    # check if deleted environment was the current environment
    if [[ "$origCurEnv" != "$deleteEnv" ]]; then
        set_current_env "$origCurEnv"
        display "\nSetting the current environment to \"$origCurEnv\"."
    else
        localEnvNames=$(get_local_environment_names)

        if [[ -z "$localEnvNames" ]]; then
            display "\nThere are no local environments left. You will need to create a new one to continue working on this app."
            set_current_env "setme"
        elif [[ "$HEADLESS" == "y" ]]; then
            display "Note: You can pass one of these values into the 'set_current_env' function to set the new current environment:"
            display "$localEnvNames"
        else
            display "\nThe current environment has been deleted. Please choose another environment to make current."
            switch_local_environment
        fi
    fi

fi

display "\n${GREEN}Congratulations! The items selected for the \"$deleteEnv\" environment have been deleted!${NC}\n"
