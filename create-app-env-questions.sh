#!/usr/bin/env bash

# This script holds reusable "create app" and "create app environment"
# questions that can be asked by a wizard.

# Puts Create App Wizard choices into an array for later caching use
populate_create_app_choice_cache_array () {
    [[ ! -z "$appParentDir" ]] && choiceCacheArray+=("defaultProjectParentDir=${appParentDir}")
    [[ ! -z "$gitProjectGroup" ]] && choiceCacheArray+=("defaultGitProjectGroup=${gitProjectGroup}")
    [[ ! -z "$gitProjectName" ]] && choiceCacheArray+=("defaultGitProjectName=${gitProjectName}")
    [[ ! -z "$gitRepoDomain" ]] && choiceCacheArray+=("defaultGitRepoDomain=${gitRepoDomain}")
    [[ ! -z "$gitRepoProvider" ]] && choiceCacheArray+=("defaultGitRepoProvider=${gitRepoProvider}")
    [[ ! -z "$APP_NAME" ]] && choiceCacheArray+=("defaultAppName=${APP_NAME}")
    [[ ! -z "$ENV_NAME" ]] && choiceCacheArray+=("defaultEnvName=${ENV_NAME}")
    [[ ! -z "$firstIacModuleName" ]] && choiceCacheArray+=("defaultFirstIacModuleName=${firstIacModuleName}")
    [[ ! -z "$CREATED_BY" ]] && choiceCacheArray+=("defaultCreatedBy=${CREATED_BY}")
    [[ ! -z "$AWS_ACCOUNT_ID" ]] && choiceCacheArray+=("defaultAwsAccountNum=${AWS_ACCOUNT_ID}")
    [[ ! -z "$AWS_DEFAULT_REGION" ]] && choiceCacheArray+=("defaultRegion=${AWS_DEFAULT_REGION}")
    [[ ! -z "$AWS_SECONDARY_REGION" ]] && choiceCacheArray+=("defaultSecondaryRegion=${AWS_SECONDARY_REGION}")
    [[ ! -z "$iac" ]] && choiceCacheArray+=("defaultIaC=${iac}")
    [[ ! -z "$useCicd" ]] && choiceCacheArray+=("defaultUseCicd=${useCicd}")
    [[ ! -z "$cicd" ]] && choiceCacheArray+=("defaultCicd=${cicd}")
    [[ ! -z "$deployCicdResources" ]] && choiceCacheArray+=("defaultDeployRole=${deployCicdResources}")
    [[ ! -z "$deployRemoteEnvVars" ]] && choiceCacheArray+=("defaultDeployRemoteEnvVars=${deployRemoteEnvVars}")
    [[ ! -z "$REMOTE_ENV_VAR_LOC" ]] && choiceCacheArray+=("defaultRemoteEnvVarLoc=${REMOTE_ENV_VAR_LOC}")
    [[ ! -z "$deployTfBackend" ]] && choiceCacheArray+=("defaultDeployTfBackend=${deployTfBackend}")
    [[ ! -z "$deployCdk2Backend" ]] && choiceCacheArray+=("defaultDeployCdk2Backend=${deployCdk2Backend}")
    [[ ! -z "$hasSecondaryRegion" ]] && choiceCacheArray+=("defaultHasSecondaryRegion=${hasSecondaryRegion}")
}

# Puts Create App Environment Wizard choices into an array for later caching use
populate_create_app_env_choice_cache_array () {
    [[ ! -z "$useEnvWithCicd" ]] && choiceEnvCacheArray+=("defaultUseEnvWithCicd=${useEnvWithCicd}")
    [[ ! -z "$APP_NAME" ]] && choiceEnvCacheArray+=("defaultAppName=${APP_NAME}")
    [[ ! -z "$CREATED_BY" ]] && choiceEnvCacheArray+=("defaultCreatedBy=${CREATED_BY}")
    [[ ! -z "$AWS_ACCOUNT_ID" ]] && choiceEnvCacheArray+=("defaultAwsAccountNum=${AWS_ACCOUNT_ID}")
    [[ ! -z "$AWS_DEFAULT_REGION" ]] && choiceEnvCacheArray+=("defaultRegion=${AWS_DEFAULT_REGION}")
    [[ ! -z "$AWS_SECONDARY_REGION" ]] && choiceEnvCacheArray+=("defaultSecondaryRegion=${AWS_SECONDARY_REGION}")
    [[ ! -z "$deployCicdResources" ]] && choiceEnvCacheArray+=("defaultDeployRole=${deployCicdResources}")
    [[ ! -z "$deployRemoteEnvVars" ]] && choiceEnvCacheArray+=("defaultDeployRemoteEnvVars=${deployRemoteEnvVars}")
    [[ ! -z "$REMOTE_ENV_VAR_LOC" ]] && choiceEnvCacheArray+=("defaultRemoteEnvVarLoc=${REMOTE_ENV_VAR_LOC}")
    [[ ! -z "$deployTfBackend" ]] && choiceEnvCacheArray+=("defaultDeployTfBackend=${deployTfBackend}")
    [[ ! -z "$deployCdk2Backend" ]] && choiceEnvCacheArray+=("defaultDeployCdk2Backend=${deployCdk2Backend}")
}

# adds hasSecondaryRegion to global namespace
ask_if_has_secondary_region () {
    local defaultHasSecondaryRegion=$(echo "$choiceCacheJson" | jq -r '.defaultHasSecondaryRegion | select(type == "string")')
    defaultHasSecondaryRegion="${defaultHasSecondaryRegion:=n}"

    display ""
    yes_or_no hasSecondaryRegion "Will components of your application be deployed to a secondary region" "$defaultHasSecondaryRegion"
}

# adds useEnvWithCicd to global namespace
ask_if_use_new_environment_with_cicd_pipeline () {
    local defaultUseEnvWithCicd=n
    display ""
    yes_or_no useEnvWithCicd "Do you want to use your environment from a CICD pipeline" "$defaultUseEnvWithCicd"
}

# adds createRemoteGitRepo to global namespace
ask_if_create_git_repo () {
    if [[ "$coinAppGitDirExists" == "y" ]]; then
        createRemoteGitRepo="n"
        return 0
    fi

    local defaultCreateRemoteGitRepo=y
    display ""
    yes_or_no createRemoteGitRepo "Create a Git repository for your project if it does not exist" "$defaultCreateRemoteGitRepo"
    # Note - this choice is deliberately not stored in the wizard choice cache
}

# adds gitRepoProvider to global namespace
optionally_ask_which_git_repo_provider () {
    if [[ "$coinAppGitDirExists" != "y" ]] && [[ "$createRemoteGitRepo" == "y" ]]; then
        display ""
        local defaultGitRepoProvider=$(echo "$choiceCacheJson" | jq -r '.defaultGitRepoProvider | select(type == "string")')
        defaultGitRepoProvider="${defaultGitRepoProvider:=gitlab}"
        display "Which Git provider will your project use?"
        gitRepoProvider=$(select_with_default "GitLab" "gitlab" "$defaultGitRepoProvider")
    fi
}

# adds gitRepoDomain to global namespace
# param1: default git repo domain
ask_git_repo_domain () {
    local paramRepoDefault="$1"
    display ""
    local defaultGitRepoDomain=$(echo "$choiceCacheJson" | jq -r '.defaultGitRepoDomain | select(type == "string")')
    if [[ -z "$defaultGitRepoDomain" ]]; then
        defaultGitRepoDomain="$paramRepoDefault"
    fi
    length_range gitRepoDomain "Enter the Git repository domain:" \
    "$defaultGitRepoDomain" "1" "60"
}

# adds gitRepoDomain to global namespace
# param1: default git repo domain
optionally_ask_git_repo_domain () {
    if [[ ! -z "$gitRepoDomain" ]]; then
        return
    fi

    if [[ "$gitRepoProvider" == "gitlab" ]] || [[ "$createRemoteGitRepo" == "y" ]] || [[ "$cicd" == "gitlab" ]]; then
        ask_git_repo_domain "$1"
    fi
}

# adds gitProjectGroup to global namespace
# param1: the default value of the Git project group
ask_git_project_group () {
    if [[ "$coinAppGitDirExists" == "y" ]]; then
        return 0
    fi
    display ""
    local defaultGitProjectGroup=$(echo "$choiceCacheJson" | jq -r '.defaultGitProjectGroup | select(type == "string")')
    if [[ -z "$defaultGitProjectGroup" ]]; then
        defaultGitProjectGroup="$1"
    fi
    length_range gitProjectGroup "Enter the GitLab repository group/namespace:" \
    "$defaultGitProjectGroup" "1" "50"
}

# param1: the default value of the Git project group
optionally_ask_git_project_group () {
    if [[ ! -z "$gitProjectGroup" ]]; then
        return 0
    fi

    if [[ "$createRemoteGitRepo" == "y" ]] || [[ "$cicd" == "gitlab" ]]; then
        ask_git_project_group "$1"
    fi
}

# adds gitProjectName to global namespace
ask_git_project_name () {
    display ""
    local defaultGitProjectName=$(echo "$choiceCacheJson" | jq -r '.defaultGitProjectName | select(type == "string")')
    length_range gitProjectName \
    "Enter the application directory name (without any path). Example: \"my-app\". A directory will be created later on your computer based upon this name if it does not already exist:" "$defaultGitProjectName" "1" "75"
}

# adds APP_NAME to global namespace
ask_app_name () {
    display "\nThe application name should be short since it is often used"
    display "as a prefix to an AWS resource identifier."
    local defaultAppName=$(echo "$choiceCacheJson" | jq -r '.defaultAppName | select(type == "string")')
    defaultAppName="${defaultAppName:=$gitProjectName}"
    length_range APP_NAME "Enter the app name:" "$defaultAppName" "1" "10"
}

# adds ENV_NAME to global namespace
# pass in "ignoreDefault" as the first argument if you do not want to
# suggest a default value
ask_environment_name () {
    # Optional param to not use a default value
    local ignoreDefault=$1

    display "\nThe deployment environment name should be short since it is"
    display "often used as part of an AWS resource identifier."
    display "Use your initials if the environment is just for you or use"
    display "traditional names like \"dev\" or \"qa\" for shared environments"
    local defaultEnvName=""
    if [[ "$ignoreDefault" != "ignoreDefault" ]]; then
        defaultEnvName=$(echo "$choiceCacheJson" | jq -r '.defaultEnvName | select(type == "string")')
    fi
    length_range ENV_NAME "Enter an environment name:" "$defaultEnvName" "1" "6"
}

# adds firstIacModuleName to global namespace
ask_iac_first_module_name () {
    display ""
    local defaultFirstIacModuleName="$(echo "$choiceCacheJson" | jq -r '.defaultFirstIacModuleName | select(type == "string")')"
    if [[ -z "$defaultFirstIacModuleName" ]] || [[ "$defaultFirstIacModuleName" == "not_used_during_upgrade" ]]; then
        defaultFirstIacModuleName=$APP_NAME
    fi

    local iacName=""
    get_iac_name iacName

    length_range firstIacModuleName \
    "Enter the name of a $iacName root module that you want to create in your new project:" "$defaultFirstIacModuleName" "1" "50"
}

# adds CREATED_BY to global namespace
ask_created_by () {
    display ""
    local defaultCreatedBy=$(echo "$choiceCacheJson" | jq -r '.defaultCreatedBy | select(type == "string")')
    if [[ -z "$defaultCreatedBy" ]]; then
        defaultCreatedBy=$(whoami)
    fi
    length_range CREATED_BY "Enter your name to mark the \"$ENV_NAME\" environment as yours:" "$defaultCreatedBy" "1" "90" "allowWhitespace"
}

optionally_ask_created_by () {
    if [[ "$REMOTE_ENV_VAR_LOC" != "na" ]]; then
        ask_created_by
    fi
}

# adds AWS_ACCOUNT_ID to global namespace
# adds awsDeployDisabled to the global namespace
ask_aws_account_number () {
    display ""
    local defaultAwsAccountNum=$(echo "$choiceCacheJson" | jq -r '.defaultAwsAccountNum | select(type == "string")')
    aws_account_number AWS_ACCOUNT_ID "Enter the AWS account number used to host the environment or enter all 0's if you do not have an account yet:" "$defaultAwsAccountNum"

    if [[ "$AWS_ACCOUNT_ID" == "000000000000" ]]; then
        awsDeployDisabled="y"
    else
        awsDeployDisabled="n"
    fi
}

# adds AWS_DEFAULT_REGION or AWS_SECONDARY_REGION to global namespace
# param1: variable name to set
ask_aws_region () {
    local varName="$1"
       
    local joinedRegionNames
    printf -v joinedRegionNames '%s|' "${awsRegionChoicesArray[@]}"

    display ""

    if [[ "$varName" == "AWS_DEFAULT_REGION" ]]; then
        local defaultRegion=$(echo "$choiceCacheJson" | jq -r '.defaultRegion | select(type == "string")')
        defaultRegion="${defaultRegion:=us-east-1}"
        display "What is the default AWS region for the application environment?"
        AWS_DEFAULT_REGION=$(select_with_default "$joinedRegionNames" "$awsJoinedRegionCodes" "$defaultRegion")
    else
        local defaultSecondaryRegion=$(echo "$choiceCacheJson" | jq -r '.defaultSecondaryRegion | select(type == "string")')
        defaultSecondaryRegion="${defaultSecondaryRegion:=us-west-2}"
        display "What is the secondary AWS region for the application environment?"
        AWS_SECONDARY_REGION=$(select_with_default "$joinedRegionNames" "$awsJoinedRegionCodes" "$defaultSecondaryRegion")
    fi
}

# adds iac to global namespace
ask_which_iac () {
    display ""
    local defaultIaC=$(echo "$choiceCacheJson" | jq -r '.defaultIaC | select(type == "string")')
    defaultIaC="${defaultIaC:=terraform}"
    display "Which Infrastructure as Code technology will your project use?"
    iac=$(select_with_default "Terraform|CDK v2 (TypeScript)|CloudFormation" "terraform|cdk2|cf" "$defaultIaC")

    if [[ "$iac" == "terraform" ]]; then

        if ! command -v terraform --version &> /dev/null
        then
            displayIssue "terraform could not be found. Please install terraform, then run this script again." "error"
            exit 1
        fi

        local tfVer=$(terraform --version)
        display "\nRequired Terraform Version: 1.8.0 or greater"
        display "Your Terraform Version: ${tfVer}"
    fi
}

# adds TF_S3_BACKEND_NAME to global namespace
# Terraform state is backed up to an S3 bucket with a
# DynamoDB table for optimistic locking.
optionally_inform_tf_backend_name () {
    if [[ "$iac" != "terraform" ]]; then
        return 0
    fi

    display "\nTerraform state files are backed up to an S3 bucket."
    display "Each application environment will use a unique bucket"
    display "that can store multiple state files (1 per root Terraform"
    display "module). The bucket name used by your envrionment will be"
    display "\"${APP_NAME}-${ENV_NAME}-tf-back-end\"."
    
    TF_S3_BACKEND_NAME="${APP_NAME}-${ENV_NAME}-tf-back-end"
}

# adds useCicd to global namespace
ask_generate_cicd_pipeline () {

    display ""
    local defaultUseCicd=$(echo "$choiceCacheJson" | jq -r '.defaultUseCicd | select(type == "string")')
    defaultUseCicd="${defaultUseCicd:=y}"
    yes_or_no useCicd "Do you want a CICD pipeline generated for your project" "$defaultUseCicd"
}

# adds cicd to global namespace
ask_which_cicd_tech () {
    if [[ "$useCicd" == "y" ]]; then
        display ""
        local defaultCicd=$(echo "$choiceCacheJson" | jq -r '.defaultCicd | select(type == "string")')
        defaultCicd="${defaultCicd:=gitlab}"
        display "Which CICD technology will your project use?"
        cicd=$(select_with_default "GitLab" "gitlab" "$defaultCicd")
    fi
}



# adds deployCicdResources to global namespace
ask_if_deploy_cicd_resources () {
    if [[ "$awsDeployDisabled" == "y" ]]; then
        deployCicdResources="n"
        return 0
    fi

    if [[ "$useCicd" == "y" ]]; then
        local defaultDeployRole=$(echo "$choiceCacheJson" | jq -r '.defaultDeployRole | select(type == "string")')
        defaultDeployRole="${defaultDeployRole:=y}"
        yes_or_no deployCicdResources "\nDo you want to deploy the CICD resources to AWS" "$defaultDeployRole"
    fi
}

# adds deployRemoteEnvVars to global namespace
optionally_ask_push_env_vars () {
    if [[ "$awsDeployDisabled" == "y" ]] && [[ "$REMOTE_ENV_VAR_LOC" == "ssm" ]]; then
	    deployRemoteEnvVars="n"
        return 0
    fi 

    if [[ "$REMOTE_ENV_VAR_LOC" != "na" ]]; then
        display ""
        local defaultDeployRemoteEnvVars=$(echo "$choiceCacheJson" | jq -r '.defaultDeployRemoteEnvVars | select(type == "string")')
        defaultDeployRemoteEnvVars="${defaultDeployRemoteEnvVars:=y}"
        local storeName="SSM"
        [ "$REMOTE_ENV_VAR_LOC" == "gitlab" ] && storeName="GitLab"
        yes_or_no deployRemoteEnvVars "Do you want to push \"$ENV_NAME\" environment variables to the remote store ($storeName)" "$defaultDeployRemoteEnvVars"
    else
        defaultDeployRemoteEnvVars="n"
    fi
}

# adds REMOTE_ENV_VAR_LOC to global namespace
ask_where_to_store_remote_env_vars () {
    display ""
    if [[ "$useCicd" == "y" ]]; then
        display "Your CICD pipeline will need environment variables to be set."
        local whereStore="Where do you want to store remote pipeline variables?"
        local envVarLocNames="AWS SSM Parameter Store|GitLab (requires Maintainer privileges)"
        local envVarLocVals="ssm|gitlab"
        local localDefaultLoc="gitlab"
    else
        display "You can optionally store your environment variables remotely for reference by your teammates."
        local whereStore="Where do you want to store remote environment variables?"

        local envVarLocNames="AWS SSM Parameter Store|GitLab (requires Maintainer privileges)|Do not store"
        local envVarLocVals="ssm|gitlab|na"
        
        local localDefaultLoc="na"
    fi

    display ""
    local defaultRemoteEnvVarLoc=$(echo "$choiceCacheJson" | jq -r '.defaultRemoteEnvVarLoc | select(type == "string")')
    defaultRemoteEnvVarLoc="${defaultRemoteEnvVarLoc:=$localDefaultLoc}"
    echo "$whereStore"
    REMOTE_ENV_VAR_LOC=$(select_with_default "$envVarLocNames" "$envVarLocVals" "$defaultRemoteEnvVarLoc")
}

# adds deployTfBackend to global namespace
ask_if_deploy_terraform_backend_cf_stack () {
    if [[ "$awsDeployDisabled" == "y" ]]; then
	    deployTfBackend="n"
        return 0
    fi  

    if [[ "$iac" == "terraform" ]]; then
        display "\nThe Terraform backend is configured in a CloudFormation stack."
        display "The stack name will be \"$TF_S3_BACKEND_NAME\"."
        local defaultDeployTfBackend=$(echo "$choiceCacheJson" | jq -r '.defaultDeployTfBackend | select(type == "string")')
        defaultDeployTfBackend="${defaultDeployTfBackend:=y}"
        yes_or_no deployTfBackend "Do you want to deploy the Terraform back end stack to AWS" "$defaultDeployTfBackend"
    fi
}

# adds deployCdk2Backend to global namespace
ask_if_deploy_cdk2_bootstrap_cf_stack () {
    if [[ "$awsDeployDisabled" == "y" ]]; then
        deployCdk2Backend="n"
        return 0
    fi

    if [[ "$iac" == "cdk2" ]]; then
        display "\nThe AWS CDK needs to be "bootstrapped" once per AWS account."
        local defaultDeployCdk2Backend=$(echo "$choiceCacheJson" | jq -r '.defaultDeployCdk2Backend | select(type == "string")')
        defaultDeployCdk2Backend="${defaultDeployCdk2Backend:=y}"
        yes_or_no deployCdk2Backend "Do you want to run \"cdk bootstrap\"" "$defaultDeployCdk2Backend"
    fi
}

# Must be run from project directory, not the create app wizard source code directory
optionally_deploy_cicd_resources () {
    if [[ "$deployCicdResources" == "y" ]]; then

        if [[ "$awsDeployDisabled" == "y" ]]; then
            log "Skipping deploying CICD since awsDeployDisabled=y"
            return
        fi

        local mainLogFile="$projectEnvDir/.log-${ROOT_CONTEXT}.txt"
        # When Create App Env Wizard is running on its own (not during App Creation), we need to prevent the log
        # file from being overwritten by additional calls to Make.
        if [[ "$CREATE_APP" != "true" ]]; then
            mv "$projectEnvDir/.log.txt" "$mainLogFile"
        fi

        export IS_VALID_CLI_ACCOUNT_ID=y && make deploy-cicd
        if [[ "$CREATE_APP" == "true" ]]; then
            log "\nBEGIN APP Makefile TARGET deploy-cicd -----------\n"
            log "$(cat .log.txt)"
            log "\nEND APP Makefile TARGET deploy-cicd -----------\n"
        fi

        if [[ "$CREATE_APP" != "true" ]]; then
            cat "$projectEnvDir/.log.txt" >> "$mainLogFile"
            rm "$projectEnvDir/.log.txt"
            mv "$mainLogFile" "$projectEnvDir/.log.txt"
        fi
    fi
}

# Must be run from project directory, not the create app wizard source code directory
optionally_deploy_terraform_back_end_cf_stack () {
    if [[ "$deployTfBackend" == "y" ]]; then

        if [[ "$awsDeployDisabled" == "y" ]]; then
            log "Skipping deploying Terraform back end CF stack since awsDeployDisabled=y"
            return
        fi

        # Execute make deploy-tf-backend-cf-stack from project root directory
        local currentSimpleDirName="$(get_simple_dir_name)"
        if [[ "/${currentSimpleDirName}" == "$projectEnvPath" ]]; then
            cd .. 1> /dev/null
        fi

        local mainLogFile="$projectEnvDir/.log-${ROOT_CONTEXT}.txt"
        # When Create App Env Wizard is running on its own (not during App Creation), we need to prevent the log
        # file from being overwritten by additional calls to Make.
        if [[ "$CREATE_APP" != "true" ]]; then
            mv "$projectEnvDir/.log.txt" "$mainLogFile"
        fi

        export IS_VALID_CLI_ACCOUNT_ID=y && make deploy-tf-backend-cf-stack

        if [[ "/${currentSimpleDirName}" == "$projectEnvPath" ]]; then
            cd - 1> /dev/null
        fi

        if [[ "$CREATE_APP" == "true" ]]; then
            log "\nBEGIN APP Makefile TARGET deploy-tf-backend-cf-stack -----------\n"
            log "$(cat .log.txt)"
            log "\nEND APP Makefile TARGET deploy-tf-backend-cf-stack -----------\n"
        fi

        if [[ "$CREATE_APP" != "true" ]]; then
            cat "$projectEnvDir/.log.txt" >> "$mainLogFile"
            rm "$projectEnvDir/.log.txt"
            mv "$mainLogFile" "$projectEnvDir/.log.txt"
        fi
        
    fi
}

# Must be run from project directory, not the create app wizard source code directory
optionally_deploy_cdk2_bootstrap_cf_stack () {
    if [[ "$deployCdk2Backend" == "y" ]]; then

        if [[ "$awsDeployDisabled" == "y" ]]; then
            log "Skipping CDK bootstrapping since awsDeployDisabled=y"
            return
        fi

        # Execute make deploy-cdk2-bootstrap-cf-stack from project root directory
        local currentSimpleDirName="$(get_simple_dir_name)"
        if [[ "/${currentSimpleDirName}" == "$projectEnvPath" ]]; then
            cd .. 1> /dev/null
        fi

        local mainLogFile="$projectEnvDir/.log-${ROOT_CONTEXT}.txt"
        # When Create App Env Wizard is running on its own (not during App Creation), we need to prevent the log
        # file from being overwritten by additional calls to Make.
        if [[ "$CREATE_APP" != "true" ]]; then
            mv "$projectEnvDir/.log.txt" "$mainLogFile"
        fi

        local deployMsg
        deployMsg=$(export IS_VALID_CLI_ACCOUNT_ID=y && make deploy-cdk2-bootstrap-cf-stack region="$AWS_DEFAULT_REGION" 2>&1)
        deployStatus=$?
        if [ $deployStatus -ne 0 ]; then
            displayIssue "Failed to run deploy-cdk2-bootstrap-cf-stack region=\"$AWS_DEFAULT_REGION\". Reason: $deployMsg" "error"
        fi

        if [[ "$CREATE_APP" != "true" ]]; then
            cat "$projectEnvDir/.log.txt" >> "$mainLogFile"
            rm "$projectEnvDir/.log.txt"
        fi

        if [[ "$CREATE_APP" == "true" ]]; then
            log "\nBEGIN APP Makefile TARGET deploy-cdk2-bootstrap-cf-stack -----------\n"
            log "$(cat environment/.log.txt)"
            log "\nEND APP Makefile TARGET deploy-cdk2-bootstrap-cf-stack -----------\n"
        fi

        if [[ ! -z "$AWS_SECONDARY_REGION" ]]; then
            deployMsg=$(export IS_VALID_CLI_ACCOUNT_ID=y && make deploy-cdk2-bootstrap-cf-stack region="$AWS_SECONDARY_REGION" 2>&1)
            deployStatus=$?
            if [ $deployStatus -ne 0 ]; then
                displayIssue "Failed to run deploy-cdk2-bootstrap-cf-stack region=\"$AWS_SECONDARY_REGION\". Reason: $deployMsg" "error"
            fi

            if [[ "$CREATE_APP" == "true" ]]; then
                log "\nBEGIN APP Makefile TARGET (SECONDARY REGION) deploy-cdk2-bootstrap-cf-stack -----------\n"
                log "$(cat environment/.log.txt)"
                log "\nEND APP Makefile TARGET (SECONDARY REGION) deploy-cdk2-bootstrap-cf-stack -----------\n"
            fi

            if [[ "$CREATE_APP" != "true" ]]; then
                cat "$projectEnvDir/.log.txt" >> "$mainLogFile"
                rm "$projectEnvDir/.log.txt"
            fi
        fi

        if [[ "$CREATE_APP" != "true" ]]; then
            mv "$mainLogFile" "$projectEnvDir/.log.txt"
        fi

        if [[ "/${currentSimpleDirName}" == "$projectEnvPath" ]]; then
            cd - 1> /dev/null
        fi
    fi
}

# Must be run from project directory, not the create app wizard source code directory
optionally_push_env_vars_to_remote () {
    if [[ "$deployRemoteEnvVars" == "y" ]]; then
        local lclGitRepoToken=""
        if [[ "$cicd" == "gitlab" ]]; then
            lclGitRepoToken="$gitLabToken"
        fi

        make push-env-vars gitRepoToken="$lclGitRepoToken"

        if [[ "$CREATE_APP" == "true" ]]; then
            log "\nBEGIN APP Makefile TARGET push-env-vars -----------\n"
            log "$(cat .log.txt)"
            log "\nEND APP Makefile TARGET push-env-vars -----------\n"
        fi
    fi
}

# Sets Bash nameref variable to the name of the Infrastructure as Code technology
# param1: the nameref variable
get_iac_name () {
    local -n returnIacName=$1
    if [[ "$iac" == "cf" ]]; then
        returnIacName="CloudFormation"
    elif [[ "$iac" == "terraform" ]]; then
        returnIacName="Terraform"
    elif [[ "$iac" == "cdk2" ]]; then
        returnIacName="CDK v2"
    else
        returnIacName="Unknown IaC Provider"
    fi
}