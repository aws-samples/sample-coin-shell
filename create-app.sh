#!/usr/bin/env bash

# Get original values for stdin and stderr for later reference
exec 21>&1
exec 22>&2

# Global variables
CREATE_APP="true"
choiceCacheArray=()
choiceEnvCacheArray=()
createAppScriptDir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
defaultDir=$(pwd)
choiceCacheFilePath=$createAppScriptDir/.choice-cache.json

source "$createAppScriptDir/environment/utility-functions.sh" "source create_app_wizard" 1> /dev/null

# Load valid AWS regions while supporting customizations/overrides
if [[ -f "$createAppScriptDir/environment/aws-regions-custom.sh" ]]; then
    source "$createAppScriptDir/environment/aws-regions-custom.sh"
else
    source "$createAppScriptDir/environment/aws-regions.sh"
fi

source "$createAppScriptDir/create-app-env-questions.sh"

# load user customizations
source "$createAppScriptDir/create-app-defaults.sh" 1> /dev/null

# Sets Bash nameref variable to "true" if the project directory is valid or
# "false" otherwise
# param1: the project parent directory path
# param2: the name of the project directory (without path)
# param3: the nameref variable
is_valid_app_dir () {
    local lclAppParentDir="$1"
    local lclAppDir="${lclAppParentDir}$2"
    local -n returnVar="$3"
    returnVar="true"

    if [[ -z "$lclAppParentDir" ]]; then
        returnVar="false"
    elif [[ ! "$lclAppParentDir" == */ ]]; then
        display "The directory name must end with /"
        returnVar="false"
    elif [[ "$lclAppParentDir" == "$projectDir/" ]]; then
        display "The new app must be created outside of the $projectDir directory"
        returnVar="false"
    elif [[ ! -d "$lclAppDir" ]]; then
        coinAppExists=n
        coinConfigExists=n
    elif [[ "$(ls -A ${lclAppDir})" ]]; then
        coinAppExists=y

        if [[ "$HEADLESS" != "y" ]]; then
            display "\n${YELLOW}WARNING: The app directory $lclAppDir is not empty.${NC}"
            display "Files created by this wizard will overwrite files of"
            display "the same name in the $lclAppDir directory."
            display "Use a Git diffing tool to ensure that you do not lose"
            display "valuable changes."

            local defaultOverwrite=n
            local overwrite
            display ""
            yes_or_no overwrite "Proceed using $lclAppDir" "$defaultOverwrite"
            if [[ ! $overwrite =~ ^[Yy]$ ]]; then
                returnVar="false"
            fi
        fi

        if [[ -d "${lclAppDir}/environment" ]]; then
            coinConfigExists=y # This variable tracks whether an existing directory already had COIN files in it to start with
        else
            coinConfigExists=n
        fi

    fi

    log "\ncoinAppExists=${coinAppExists}"
    log "coinConfigExists=${coinConfigExists}\n"
}

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

    eval "export $(cat "$1" | jq -r 'to_entries | map("\(.key)=\(.value)") | @sh')" # nosemgrep
}

# Write user choices to JSON cache file used by subsequent wizard run default values
write_choices_to_cache_file () {

    # Reinstate original stdout and stderr that may have been redirected
    exec 1>&21
    exec 2>&22

    # Enable echo. This may have been disabled when reading secret values
    if [[ "$HEADLESS" != "y" ]]; then
        stty echo
    fi
    
    populate_create_app_choice_cache_array
    local choiceCacheJson="{}"

    # Loop over array and append to JSON
    for item in "${choiceCacheArray[@]}"; do
        # Split the item by '=' and read into key and value
        IFS='=' read -r key value <<< "$item"
        
        # Append to JSON using jq
        choiceCacheJson=$(echo "$choiceCacheJson" | jq --arg k "$key" --arg v "$value" '. + {($k): $v}')
    done

    echo "$choiceCacheJson" > "$choiceCacheFilePath"
}

# Check to see if the user has the latest COIN code from Git
check_for_updates () {
    display "\nChecking for updates..."
    git fetch || { displayIssue "Failed to get COIN updates." "error"; exit 1; }
    local UPSTREAM=${1:-'@{u}'}
    local LOCAL=$(git rev-parse @)
    local REMOTE=$(git rev-parse "$UPSTREAM")
    local BASE=$(git merge-base @ "$UPSTREAM")
    local codeState

    if [ $LOCAL = $REMOTE ]; then
        codeState="UP_TO_DATE"
        display "You are running the latest version of Create COIN App!\n"
    elif [ $LOCAL = $BASE ]; then

        display "${YELLOW}There is a newer version of Create COIN App available.${NC}"
        local doGitPull
        local pullStatus
        if [[ ! -z "$HEADLESS" ]]; then
            doGitPull="y"
        else
            yes_or_no doGitPull "Do you want to pull down the latest changes" "y"
        fi

        if [[ "$doGitPull" == "y" ]]; then 
            
            if pullStatus=$(git pull); then
                display "You are now running the latest version of Create COIN App!"
                display "${CYAN}Please rerun this script now to create your application.${NC}\n"
                exit 0
            else
                display  "Failed to update Create COIN App!\n" "error"
                exit 1
            fi
            
        fi
        display ""
        codeState="NEED_TO_PULL"
    elif [ $REMOTE = $BASE ]; then
        displayIssue "You have made local changes to Create COIN App that have not yet been merged.\n" "warn"
        codeState="NEED_TO_PUSH"
    else
        displayIssue "Your local version of Create COIN App has diverged from the Git origin.\n" "warn"
        codeState="DIVERGED"
    fi
}

# Populates ENV_KEYS list.
# param1: the generated application's environment directory path
load_app_placeholder_resolution_state () {
    local appEnvDirPath="$1"

    [ -z "$appEnvDirPath" ] && displayIssue "appEnvDirPath is required as the first argument to this script" "error" \
    && displayIssue "usage: load_app_placeholder_resolution_state \"<appEnvDirPath>\"" && exit 1

    local wizardEnvDir="$projectEnvDir"

    # Temporarily change the projectEnvDir to the generated application's
    # environment directory since the load_env_var_names function uses that
    projectEnvDir="$1"

    log "\nGenerated Application app-env-var-names.txt:"
    log "$(cat "$projectEnvDir/app-env-var-names.txt")"
    log ""

    load_env_var_names

    # Restore projectEnvDir to its original value
    projectEnvDir="$wizardEnvDir"

    log "\nHERE ARE THE ENV_KEYS:"
    for i in ${!ENV_KEYS[@]}; do
        log "  ${ENV_KEYS[$i]}"

        ENV_CONFIGS[${ENV_KEYS[$i]}]="${!ENV_KEYS[$i]}"
    done
    log ""
}

# Wizard that asks the user questions about the application so that
# a template of the application can be created
create_app () {
    if [[ "$defaultDir" == "$projectDir" ]]; then
        defaultDir=$(dirname "$defaultDir")
    fi
    
    defaultDir=$defaultDir/
    
    display "\nWelcome to the Create COIN App wizard!\n"

    if [[ "$HEADLESS" == "y" ]]; then

        display "Running in headless mode\n"

        AWS_PRIMARY_REGION="$AWS_DEFAULT_REGION"

        local isValidAppParentDir
        is_valid_app_dir "$appParentDir" "$gitProjectName" "isValidAppParentDir"
        if [[ "$isValidAppParentDir" == "false" ]]; then
            displayIssue "invalid value \"$appParentDir\" for \"appParentDir\"" "error"
            exit 1
        fi

        if [[ "$coinAppExists" == "y" ]] && [[ -d "$appParentDir/$gitProjectName/.git" ]]; then
            coinAppGitDirExists="y"
        fi

        # "destructiveUpgrade" is a variable passed in when someone runs "make upgrade-coin" on their project.
        # If it has any value, we know that we are in an app upgrade situation
        local isAppUpgrade="n"
        if [[ -z "$destructiveUpgrade" ]]; then
            destructiveUpgrade="n"
        else
            isAppUpgrade="y"
        fi
        validate_yes_or_no "destructiveUpgrade" "$destructiveUpgrade"
        log "destructiveUpgrade=${destructiveUpgrade}"

        validate_yes_or_no "createRemoteGitRepo" "$createRemoteGitRepo"
        validate_yes_or_no "deployCdk2Backend" "$deployCdk2Backend"
        validate_yes_or_no "deployCicdResources" "$deployCicdResources"
        validate_yes_or_no "deployRemoteEnvVars" "$deployRemoteEnvVars"
        validate_yes_or_no "deployTfBackend" "$deployTfBackend"
        validate_yes_or_no "useCicd" "$useCicd"
        validate_yes_or_no "hasSecondaryRegion" "$hasSecondaryRegion"

        if [[ "$hasSecondaryRegion" == "y" ]]; then
            if [[ -z "$AWS_SECONDARY_REGION" ]] || [[ "$AWS_SECONDARY_REGION" == "blank" ]]; then
                displayIssue "\"AWS_SECONDARY_REGION\" should be set if \"hasSecondaryRegion\" is set to \"y\"." "error"
                exit 1
            elif [[ ! "$AWS_SECONDARY_REGION" =~ $awsJoinedRegionCodesRegex ]]; then
                displayIssue "\"AWS_SECONDARY_REGION\" value is invalid: \"$AWS_SECONDARY_REGION\"." "error"
                displayIssue "Must be one of the following values: $awsJoinedRegionCodes"
                exit 1
            fi
        fi

        if [[ "$hasSecondaryRegion" == "n" ]] && [[ "$AWS_SECONDARY_REGION" != "blank" ]]; then
            displayIssue "\"AWS_SECONDARY_REGION\" should be set to \"blank\" if \"hasSecondaryRegion\" is set to \"n\"." "error"
            exit 1
        fi

        if [[ "$createRemoteGitRepo" == "y" ]]; then

            if [[ -z "$gitRepoProvider" ]]; then
                displayIssue "\"gitRepoProvider\" should be set if \"createRemoteGitRepo\" is set to \"y\"." "error"
                exit 1
            fi

            if [[ -z "$gitRepoDomain" ]]; then
                displayIssue "\"gitRepoDomain\" should be set if \"createRemoteGitRepo\" is set to \"y\"." "error"
                exit 1
            fi

            if [[ "$gitRepoProvider" == "gitlab" ]] && [[ -z "$gitProjectGroup" ]]; then
                displayIssue "\"gitProjectGroup\" should be set if \"createRemoteGitRepo\" is set to \"y\" and \"gitRepoProvider\" is set to \"gitlab\"." "error"
                exit 1
            fi

        fi

        if [[ "$deployRemoteEnvVars" == "y" ]] && [[ "$cicd" == "gitlab" ]]; then
            if [[ -z "$gltoken" ]]; then
                displayIssue "No value found for GitLab personal access token." "error"
                displayIssue "You must set \"gltoken\" as an environment variable with the token value"
                displayIssue "or set \"deployRemoteEnvVars\" to \"n\"."
                exit 1
            fi
        fi

        if [[ "$deployCdk2Backend" == "y" ]] && [[ "$iac" != "cdk2" ]]; then
            displayIssue "\"deployCdk2Backend\" should be set to \"n\" if \"iac\" is not set to \"cdk2\"." "error"
            exit 1
        fi

        if [[ "$deployTfBackend" == "y" ]] && [[ "$iac" != "terraform" ]]; then
            displayIssue "\"deployTfBackend\" should be set to \"n\" if \"iac\" is not set to \"terraform\"." "error"
            exit 1
        fi

        if [[ "$useCicd" == "y" ]]; then
            if [[ "$cicd" != "gitlab" ]]; then
                displayIssue "cicd must be \"gitlab\"" "error"
                exit 1
            fi
        fi

        local awsAcctPattern="^[0-9]{12}$"
        if [[ ! $AWS_ACCOUNT_ID =~ $awsAcctPattern ]]; then
            displayIssue "invalid \"AWS_ACCOUNT_ID\" value: \"$AWS_ACCOUNT_ID\". Must be a 12-digit number." "error"
            exit 1
        fi

        if [[ "$iac" != "terraform" ]] && [[ "$iac" != "cdk2" ]] && [[ "$iac" != "cf" ]]; then
            displayIssue "invalid \"iac\" value: \"$iac\". Must be \"terraform\" or \"cdk2\" or \"cf\"." "error"
            exit 1
        fi

        if [[ "$REMOTE_ENV_VAR_LOC" != "ssm" ]] && [[ "$REMOTE_ENV_VAR_LOC" != "gitlab" ]] && [[ "$REMOTE_ENV_VAR_LOC" != "na" ]]; then
            displayIssue "invalid \"REMOTE_ENV_VAR_LOC\" value: \"$REMOTE_ENV_VAR_LOC\". Must be \"ssm\" or \"gitlab\" or \"na\"." "error"
            exit 1
        fi

        [[ ! "$APP_NAME" =~ ^[^[:space:]]{1,10}$ ]] && \
        displayIssue "\"APP_NAME\" value is invalid: \"$APP_NAME\"." "error" && \
        displayIssue "Must not include whitespace and length (${#APP_NAME}) must be between 1 and 10." && \
        exit 1
        
        [[ ! "$AWS_DEFAULT_REGION" =~ $awsJoinedRegionCodesRegex ]] && \
        displayIssue "\"AWS_DEFAULT_REGION\" value is invalid: \"$AWS_DEFAULT_REGION\"." "error" && \
        displayIssue "Must be one of the following values: $awsJoinedRegionCodes" && \
        exit 1

        [[ ! "$CREATED_BY" =~ ^.{1,90}$ ]] && \
        displayIssue "\"CREATED_BY\" value is invalid: \"$CREATED_BY\"." "error" && \
        displayIssue "Length (${#CREATED_BY}) must be between 1 and 90." && \
        exit 1

        [[ ! "$ENV_NAME" =~ ^[^[:space:]]{1,6}$ ]] && \
        displayIssue "\"ENV_NAME\" value is invalid: \"$ENV_NAME\"." "error" && \
        displayIssue "Must not include whitespace and length (${#ENV_NAME}) must be between 1 and 6." && \
        exit 1

        [[ ! "$firstIacModuleName" =~ ^[^[:space:]]{1,50}$ ]] && \
        displayIssue "\"firstIacModuleName\" value is invalid: \"$firstIacModuleName\"." "error" && \
        displayIssue "Must not include whitespace and length (${#firstIacModuleName}) must be between 1 and 50." && \
        exit 1

        [[ ! "$gitRepoDomain" =~ ^[^[:space:]]{0,60}$ ]] && \
        displayIssue "\"gitRepoDomain\" value is invalid: \"$gitRepoDomain\"." "error" && \
        displayIssue "Must not include whitespace and length (${#gitRepoDomain}) must be between 0 and 60." && \
        exit 1

        [[ ! "$gitProjectGroup" =~ ^[^[:space:]]{0,50}$ ]] && \
        displayIssue "\"gitProjectGroup\" value is invalid: \"$gitProjectGroup\"." "error" && \
        displayIssue "Must not include whitespace and length (${#gitProjectGroup}) must be between 0 and 50." && \
        exit 1

        [[ ! "$gitProjectName" =~ ^[^[:space:]]{1,75}$ ]] && \
        displayIssue "\"gitProjectName\" value is invalid: \"$gitProjectName\"." "error" && \
        displayIssue "Must not include whitespace and length (${#gitProjectName}) must be between 1 and 75." && \
        exit 1

        [[ ! "$TF_S3_BACKEND_NAME" =~ ^[^[:space:]]{1,75}$ ]] && \
        displayIssue "\"TF_S3_BACKEND_NAME\" value is invalid: \"$TF_S3_BACKEND_NAME\"." "error" && \
        displayIssue "Must not include whitespace and length (${#TF_S3_BACKEND_NAME}) must be between 1 and 75." && \
        exit 1

        # Allow coinAwsCliProfileName to have an empty value or blank, which disables profile mapping or any other value to enable profile mapping
        [[ ! -z "$coinAwsCliProfileName" ]] && [[ ! "$coinAwsCliProfileName" =~ ^[^[:space:]]{1,90}$ ]] && \
        displayIssue "\"coinAwsCliProfileName\" value is invalid: \"$coinAwsCliProfileName\"." "error" && \
        displayIssue "Must not include whitespace and length (${#coinAwsCliProfileName}) must be between 1 and 90. Set to \"blank\" to disable profile mapping" && \
        exit 1

        ask_custom_create_app_questions_headless_input_validation

        ########## END OF HEADLESS MODE INPUT VALIDATION ################################################################################

        if [[ "$COIN_CREATE_APP_DRY_RUN" == "y" ]]; then
            display "\nCOIN_CREATE_APP_DRY_RUN is ON. Exiting without creating app.\n"
            exit 0
        else
            log "\nCOIN_CREATE_APP_DRY_RUN is OFF. Proceeding to create app.\n"
        fi

        if [[ "$coinAwsCliProfileName" == "blank" ]]; then
            coinAwsCliProfileName=""
        fi
        create_aws_cli_profile

        if [[ "$AWS_ACCOUNT_ID" == "000000000000" ]] || [[ "$isAppUpgrade" == "y" ]]; then
            awsDeployDisabled="y"
        else
            awsDeployDisabled="n"
        fi

        if [[ "$awsDeployDisabled" == "n" ]]; then
            validate_aws_cli_account || return 1
        fi

    else # Block for interactive mode
        destructiveUpgrade="n"
        log "destructiveUpgrade=${destructiveUpgrade}"
        local choiceCacheJson=""
        if [[ -f "$choiceCacheFilePath" ]]; then
            local useChoiceCache
            yes_or_no useChoiceCache "Would you like to load default selections from previous run" "y"
            if [[ $useChoiceCache =~ ^[Yy]$ ]]; then
                choiceCacheJson=$(<$choiceCacheFilePath)
                log "\nChoice Cache JSON:"
                log "$choiceCacheJson"

                if jq empty "$choiceCacheFilePath" 2>/dev/null; then
                    log "User choices cache file at \"$choiceCacheFilePath\" contains structurally valid JSON"
                else
                    displayIssue "User choices cache file at \"$choiceCacheFilePath\" contains structurally invalid JSON" "error"
                    exit 1
                fi
            fi
        fi

        ask_aws_account_number
        ask_aws_region "AWS_DEFAULT_REGION"
        if [[ "$awsDeployDisabled" == "n" ]]; then
            validate_aws_cli_account || return 1
        fi
        ask_if_has_secondary_region
        if [[ "$hasSecondaryRegion" == "y" ]]; then
            AWS_PRIMARY_REGION="$AWS_DEFAULT_REGION"
            ask_aws_region "AWS_SECONDARY_REGION"
        fi
        ask_git_project_name
        
        # --------------------------------------------------------------
        appParentDir=""
        local defaultProjectParentDir="$(echo "$choiceCacheJson" | jq -r '.defaultProjectParentDir | select(type == "string")')"
        defaultProjectParentDir="${defaultProjectParentDir:=$defaultDir}"
        log "defaultProjectParentDir is \"$defaultProjectParentDir\""

        if [[ "$defaultProjectParentDir" = "//" ]]; then
            defaultProjectParentDir="/coin-generated-apps/"
        fi

        local defaultOptionString="[$defaultProjectParentDir] "
        
        local isValidAppParentDir="false"
        local whereCreated="Where should the \"$gitProjectName\" directory be created? $defaultOptionString"
        display ""
        while [[ $isValidAppParentDir == "false" ]];
        do
            log "$whereCreated"
            read -p "$whereCreated" appParentDir
            appParentDir="${appParentDir:=$defaultProjectParentDir}"
            is_valid_app_dir "$appParentDir" "$gitProjectName" "isValidAppParentDir"
        done

        if [[ "$coinAppExists" == "y" ]] && [[ -d "$appParentDir/$gitProjectName/.git" ]]; then
            coinAppGitDirExists="y"
            gitRepoProvider=""
            cd "$appParentDir/$gitProjectName" 1> /dev/null
            set_git_repo_type_from_remote_origin gitRepoProvider
            cd - 1> /dev/null
        fi
        
        # --------------------------------------------------------------

        ask_if_create_git_repo
        optionally_ask_which_git_repo_provider
        optionally_ask_git_project_group "$defaultGitLabProjectGroup"
        ask_app_name
        ask_environment_name
        ask_which_iac
        optionally_inform_tf_backend_name

        if [[ "$coinAppExists" == "n" ]] ||  [[ "$coinConfigExists" == "n" ]] || [[ "$destructiveUpgrade" == "y" ]]; then
            ask_iac_first_module_name
        fi
        
        ask_generate_cicd_pipeline
        ask_which_cicd_tech
        optionally_ask_git_repo_domain "$defaultGitLabDomain"
        optionally_ask_git_project_group "$defaultGitLabProjectGroup"
        ask_where_to_store_remote_env_vars

        if [[ "$REMOTE_ENV_VAR_LOC" == "gitlab" ]]; then
            if [[ -z "$gitProjectGroup" ]]; then
                ask_git_project_group "$defaultGitLabProjectGroup"
            fi

            if [[ -z "$gitProjectName" ]]; then
                gitProjectName=$(dirname "$projectDir")
                gitProjectName="${gitProjectName##*/}" # strip full path so just the project directory name is used
            fi

            if [[ -z "$gitRepoDomain" ]]; then
                ask_git_repo_domain "$defaultGitLabDomain"
            fi
        fi

        optionally_ask_created_by
        optionally_ask_if_create_aws_cli_profile_mapping
        ask_if_deploy_cicd_resources
        optionally_ask_push_env_vars
        ask_if_deploy_terraform_backend_cf_stack
        ask_if_deploy_cdk2_bootstrap_cf_stack

        ask_custom_create_app_questions

    fi # end headless mode conditional block

    # --------------------------------------------------------------

    # From here on, we stop asking questions and start taking actions

    local appDir="${appParentDir}${gitProjectName}"
    local appEnvDir="${appDir}/environment"
    
    mkdir -p "$appDir"

    if [[ "$coinAppExists" == "y" ]] && [[ "$coinConfigExists" == "y" ]]; then
        display "${CYAN}\nUpgrading existing application at $appDir ...${NC}"
        if [[ "$destructiveUpgrade" == "y" ]]; then
            displayIssue "\nDestructive upgrade mode enabled - this wizard may overwrite files you have changed.\n" "warn"
        fi
    else
        display "${CYAN}\nGenerating new application at $appDir ...${NC}"
    fi

    # If the Git repository already exists, we should first fetch its contents before we
    # change anything. This will ensure that we do not get any merge conflicts
    repoAlreadyExists="n"
    mainBranchAlreadyExists="n"
    if [[ "$createRemoteGitRepo" == "y" ]] && [[ "$gitRepoProvider" == "gitlab" ]]; then

        log "Checking to see if Git repository already exists"
        cd "$appDir" 1> /dev/null

        if [[ ! -d ".git" ]]; then

            git init -b main

            gitlabCreateHost="${gitRemoteOriginPrefix}$gitRepoDomain"
            log "adding git remote origin - git@${gitlabCreateHost}:$gitProjectGroup/$gitProjectName.git"
            git remote add origin "git@${gitlabCreateHost}:$gitProjectGroup/$gitProjectName.git"

            fail_if_gitlab_repo_exists || { repoAlreadyExists="y"; }
            
            if [[ "$repoAlreadyExists" == "n" ]]; then
                log "Git repository does not already exist"
            else
                display "GitLab repository already exists. Fetching contents."
                git fetch

                # Check if main branch exists on the remote repo
                log "Checking if main branch exists..."
                local mainBranchExists="$(git ls-remote --heads git@${gitlabCreateHost}:$gitProjectGroup/$gitProjectName.git refs/heads/main | wc -l | xargs)" # nosemgrep
                log "code returned from main branch check: \"${mainBranchExists}\""

                if [[ "$mainBranchExists" == "0" ]]; then
                    log "GitLab remote repository does not have a main branch"
                else
                    log "GitLab remote repository has a main branch. Pulling contents."
                    mainBranchAlreadyExists="y"
                    git pull origin main
                    git branch --set-upstream-to=origin/main main
                fi

            fi   

        else
            log "Git repository already exists since .git directory was found under the $appDir directory."
        fi

        cd - 1> /dev/null
    
    fi
    
    # Copy environment files to new app directory
    display "    Copying environment files"
    mkdir -p "$appEnvDir/docs/images"

    if [[ ! -f "$appEnvDir/.cli-profiles.json" ]] && [[ ! -z "$coinAwsCliProfileName" ]] && [[ "$coinAwsCliProfileName" != "blank" ]]; then
        jq -n --arg key "$ENV_NAME" --arg val "$coinAwsCliProfileName" '. + {($key): $val}' > "$appEnvDir/.cli-profiles.json"
        log "\n      created $appEnvDir/.cli-profiles.json\n"
    else
        log "\n      skipped creating $appEnvDir/.cli-profiles.json since the file already exists or coinAwsCliProfileName=\"${coinAwsCliProfileName}\"\n"
    fi

    log "      $appEnvDir/docs/images"
    cp -r "$projectDir/docs/images/." "$appEnvDir/docs/images"

    if [[ -f "$projectDir/.choice-cache.json" ]]; then
        log "      $appEnvDir/.choice-cache.json"
        cp "$projectDir/.choice-cache.json" "$appEnvDir/.choice-cache.json"
    fi

    log "      $appEnvDir/bash-5-utils.sh"
    cp "$projectDir/environment/bash-5-utils.sh" "$appEnvDir/bash-5-utils.sh"

    log "      $appEnvDir/aws-regions.sh"
    cp "$projectDir/environment/aws-regions.sh" "$appEnvDir/aws-regions.sh"

    log "      $appEnvDir/constants.sh"
    cp "$projectDir/environment/constants.sh" "$appEnvDir/constants.sh"

    log "      $appEnvDir/gitlab.sh"
    cp "$projectDir/environment/gitlab.sh" "$appEnvDir/gitlab.sh"

    log "      $appEnvDir/create-app-env-questions.sh"
    cp "$projectDir/create-app-env-questions.sh" "$appEnvDir/create-app-env-questions.sh"

    log "      $appEnvDir/delete-app-environment.sh"
    cp "$projectDir/environment/delete-app-environment.sh" "$appEnvDir/delete-app-environment.sh"

    log "      $appEnvDir/create-iac-module.sh"
    cp "$projectDir/environment/create-iac-module.sh" "$appEnvDir/create-iac-module.sh"

    log "      $appEnvDir/create-app-environment.sh"
    cp "$projectDir/environment/create-app-environment.sh" "$appEnvDir/create-app-environment.sh"

    log "      $appEnvDir/extract-deliverable.sh"
    cp "$projectDir/environment/extract-deliverable.sh" "$appEnvDir/extract-deliverable.sh"

    log "      $appEnvDir/generate-deployment-instructions.sh"
    cp "$projectDir/environment/generate-deployment-instructions.sh" "$appEnvDir/generate-deployment-instructions.sh"

    if [[ "$destructiveUpgrade" == "n" ]] && [[ "$coinAppExists" == "y" ]] && [[ -f "$appEnvDir/dynamic-lookups.sh" ]]; then
        log "      upgrade-mode: skipping overwriting existing file - $appEnvDir/dynamic-lookups.sh"
    else
        log "      $appEnvDir/dynamic-lookups.sh"
        cp "$projectDir/environment/dynamic-lookups.sh" "$appEnvDir/dynamic-lookups.sh"
    fi

    # Note that this would overwrite any application custom extensions during an upgrade. However, we want to make sure
    # that apps get the latest extensions that are defined by the framework
    log "      $appEnvDir/extensions.sh"
    cp "$projectDir/environment/extensions.sh" "$appEnvDir/extensions.sh"

    local utilFuncFileName="$appEnvDir/utility-functions.sh"
    log "      $utilFuncFileName"
    cp "$projectDir/environment/utility-functions.sh" "$utilFuncFileName"
    
    local envVarValueJsonFile=".environment-$ENV_NAME.json"
    if [[ "$destructiveUpgrade" == "n" ]] && [[ "$coinAppExists" == "y" ]] && [[ -f "$appEnvDir/.current-environment" ]]; then
        log "      upgrade-mode: skipping overwriting existing file - $appEnvDir/.current-environment"
    else
        log "      $appEnvDir/.current-environment"
        echo "$ENV_NAME" > "$appEnvDir/.current-environment"
    fi
    
    log "      $appEnvDir/README.md\n"
    cp "$projectDir/environment/README.md" "$appEnvDir/README.md"

    if [[ "$iac" == "terraform" ]]; then
        delete_file_content_range "$appEnvDir/README.md" "BEGIN_CDK2_PREREQ" "END_CDK2_PREREQ"
        delete_file_matching_lines "$appEnvDir/README.md" "_TERRAFORM_PREREQ"    
    elif [[ "$iac" == "cdk2" ]]; then
        delete_file_content_range "$appEnvDir/README.md" "BEGIN_TERRAFORM_PREREQ" "END_TERRAFORM_PREREQ"
        delete_file_matching_lines "$appEnvDir/README.md" "_CDK2_PREREQ"
    else
        delete_file_content_range "$appEnvDir/README.md" "BEGIN_CDK2_PREREQ" "END_CDK2_PREREQ"
        delete_file_content_range "$appEnvDir/README.md" "BEGIN_TERRAFORM_PREREQ" "END_TERRAFORM_PREREQ"
    fi
    
    # Dynamically replace a string in $appEnvDir/create-app-environment.sh to set
    # the users choices as initial defaults for new environment creation
    if [[ "$coinAppExists" == "n" ]] || [[ "$coinConfigExists" == "n" ]] || [[ "$destructiveUpgrade" == "y" ]]; then
        display "    Configuring application environment variable names"
    fi

    # Create a new .choice-cache.json file for the generated application based on the user entries
    populate_create_app_env_choice_cache_array
    local choiceCacheJson="{}"

    # Loop over array and append to JSON
    for item in "${choiceEnvCacheArray[@]}"; do
        # Split the item by '=' and read into key and value
        IFS='=' read -r key value <<< "$item"
        
        # Append to JSON using jq
        choiceCacheJson=$(echo "$choiceCacheJson" | jq --arg k "$key" --arg v "$value" '. + {($k): $v}')
    done

    echo "$choiceCacheJson" > "$appEnvDir/.choice-cache.json"
    
    # Append variables to environment variable names file based on user choices
    local appEnvVarNamesFile=$projectDir/environment/app-env-var-names.txt
    local appEnvVarNamesBackupFile=$projectDir/environment/app-env-var-names-original.txt
    local projectAppEnvVarNamesFile=$appEnvDir/app-env-var-names.txt

    if [[ "$coinAppExists" == "n" ]] || [[ "$coinConfigExists" == "n" ]] || [[ "$destructiveUpgrade" == "y" ]]; then
        log "      copying \"$appEnvVarNamesFile\" to \"$appEnvVarNamesBackupFile\""
        cp "$appEnvVarNamesFile" "$appEnvVarNamesBackupFile"
    else
        log "      upgrade-mode: skipping copying \"$appEnvVarNamesFile\" to \"$appEnvVarNamesBackupFile\""
    fi

    local isCustomChoiceEnvVars="false"

    # This array is globally scoped and provides the ability to dynamically
    # add required application environment variables based on 
    # user choices while running this wizard.
    OPT_IN_ENV_VAR_KEYS=()

    if [[ ! -z "$CREATED_BY" ]]; then
        isCustomChoiceEnvVars="true"

        log "    Adding CREATED_BY to app env var names"
        local cbMsg="\n# The name or ID of the person who created the application environment\n"
        cbMsg="${cbMsg}CREATED_BY"
        echo -e "$cbMsg" >> "$appEnvVarNamesFile"
        OPT_IN_ENV_VAR_KEYS+=("CREATED_BY")
    fi

    if [[ "$hasSecondaryRegion" == "y" ]]; then
        isCustomChoiceEnvVars="true"

        log "    Adding AWS_PRIMARY_REGION and AWS_SECONDARY_REGION to app env var names"
        local regionMsg="\n# Primary AWS region to deploy application resources to\n"
        regionMsg="${regionMsg}# Example: us-east-1\n"
        regionMsg="${regionMsg}AWS_PRIMARY_REGION"
        regionMsg="${regionMsg}\n\n# Secondary AWS region to deploy application resources to\n"
        regionMsg="${regionMsg}AWS_SECONDARY_REGION"
        echo -e "$regionMsg" >> "$appEnvVarNamesFile"
        OPT_IN_ENV_VAR_KEYS+=("AWS_PRIMARY_REGION")
        OPT_IN_ENV_VAR_KEYS+=("AWS_SECONDARY_REGION")
    fi

    if [[ "$iac" == "terraform" ]]; then
        isCustomChoiceEnvVars="true"

        log "    Adding TF_S3_BACKEND_NAME to app env var names"
        local tfMsg="\n# The name of the S3 bucket that holds Terraform state files\n"
        tfMsg="${tfMsg}TF_S3_BACKEND_NAME"
        echo -e "$tfMsg" >> "$appEnvVarNamesFile"
        OPT_IN_ENV_VAR_KEYS+=("TF_S3_BACKEND_NAME")
    fi

    if [[ "$useCicd" == "y" ]] && [[ "$cicd" == "gitlab" ]]; then
        isCustomChoiceEnvVars="true"

        log "    Adding AWS_CREDS_TARGET_ROLE to app env var names"
        local ciMsg="\n# ARN of the IAM role assumed by a CICD pipeline\n"
        ciMsg="${ciMsg}# CICD Role Example: arn:aws:iam::<my-account-num>:role/<my-role-name>\n"
        ciMsg="${ciMsg}AWS_CREDS_TARGET_ROLE"
        echo -e "$ciMsg" >> "$appEnvVarNamesFile"
        OPT_IN_ENV_VAR_KEYS+=("AWS_CREDS_TARGET_ROLE")

        AWS_CREDS_TARGET_ROLE="arn:aws:iam::${AWS_ACCOUNT_ID}:role/${APP_NAME}-${ENV_NAME}-cicd-role"    
    fi

    if [[ "$isCustomChoiceEnvVars" == true ]]; then
        log "      user's wizard choices will cause the app env var names file to be augmented"
    fi

    if [[ "$destructiveUpgrade" == "n" ]] && [[ "$coinAppExists" == "y" ]] && [[ -f "$projectAppEnvVarNamesFile" ]]; then
        log "      upgrade-mode: skipping overwriting existing file - $projectAppEnvVarNamesFile"
    else
        log "      copying \"$appEnvVarNamesFile\" to \"$projectAppEnvVarNamesFile\""
        cp "$appEnvVarNamesFile" "$projectAppEnvVarNamesFile"
    fi

    load_app_placeholder_resolution_state "$appEnvDir"

    # Populate environment constants
    if [[ "$coinAppExists" == "n" ]] || [[ "$coinConfigExists" == "n" ]] || [[ "$destructiveUpgrade" == "y" ]]; then
        display "    Configuring application environment constants"
    fi
    ENV_CONSTANTS['APP_NAME']="$APP_NAME"

    # BEGIN - Create environment variables JSON file
    if [[ "$coinAppExists" == "n" ]] || [[ "$coinConfigExists" == "n" ]] || [[ "$destructiveUpgrade" == "y" ]]; then

        # Make a backup copy of the environment JSON file if it already exists
        # and we are running this wizard against an existing project for the purposes
        # of a COIN upgrade
        if [[ -f "$appEnvDir/$envVarValueJsonFile" ]]; then

            local envBackupFileName="$appEnvDir/${envVarValueJsonFile/.json/-copy.json}"

            if [[ ! -f "$envBackupFileName" ]]; then
                mv "$appEnvDir/$envVarValueJsonFile" "$envBackupFileName"
            else
                local envJsonCopyDate="$(date '+%Y-%m-%dT%T')"
                envBackupFileName="$appEnvDir/${envVarValueJsonFile/.json/-copy-$envJsonCopyDate.json}"
                mv "$appEnvDir/$envVarValueJsonFile" "$envBackupFileName"
            fi

            displayIssue "\nCreating a backup of $appEnvDir/$envVarValueJsonFile at $envBackupFileName to protect you from losing your changes.\n" "warn"
        fi

        display "    Configuring application environment JSON settings"
        app_env_vars_to_json > "$appEnvDir/$envVarValueJsonFile"
        log "      deleting \"$appEnvVarNamesFile\""
        rm "$appEnvVarNamesFile"
        log "      moving \"$appEnvVarNamesBackupFile\" to \"$appEnvVarNamesFile\""
        mv "$appEnvVarNamesBackupFile" "$appEnvVarNamesFile"

        # Move some configurations from environment-specific to constants
        local envConstantsJson="{}"
        local envConfigsJson="$(cat "$appEnvDir/$envVarValueJsonFile")"

        envConstantsJson=$(echo "$envConstantsJson" | jq --arg key "APP_NAME" --arg val "$APP_NAME" '. + {($key): $val}')
        envConfigsJson=$(echo "$envConfigsJson" | jq 'del( .APP_NAME )')
            
        echo "$envConstantsJson" > "$appEnvDir/environment-constants.json"
        echo "$envConfigsJson" > "$appEnvDir/$envVarValueJsonFile"

        log "\nGenerated Application Environment Constants:"
        log "$envConstantsJson"

        log "\nGenerated Application \"$ENV_NAME\" Environment Configs:"
        log "$envConfigsJson\n"
    else
        log "    upgrade-mode: undoing changes to \"$appEnvVarNamesFile\""
        git checkout -- "$appEnvVarNamesFile"
        log "    upgrade-mode: skipping Configuring application environment JSON settings"
    fi
    # END - Create environment variables JSON file

    # Write out the Git hash of Create COIN App that was used to generate
    # the application
    display "    Marking coin app version"
    echo "$(git rev-parse HEAD)" > "$appEnvDir/coin-app-version"

    # Copy project-root files to new app directory
    display "    Creating application root directory files"
    local projectRootTemplateDir=$projectDir/project-root
    mkdir -p "$appDir" #ANTHONY
    mkdir -p "$appDir/build-script"

    log "      $appDir/build-script"
    cp -r "$projectDir/build-script/." "$appDir/build-script"

    log "      $appDir/.gitignore"
    cp "$projectRootTemplateDir/.gitignore" "$appDir/.gitignore"

    log "      $appDir/.gitleaksignore"
    cp "$projectRootTemplateDir/code-scan-settings/.gitleaksignore" "$appDir/.gitleaksignore"

    if [[ "$destructiveUpgrade" == "n" ]] && [[ "$coinAppExists" == "y" ]] && [[ -f "$appDir/README.md" ]]; then
        log "      upgrade-mode: skipping overwriting existing file - $appDir/README.md"
    else
        log "      $appDir/README.md"
        local resolvedReadme
        resolve_placeholders "$projectRootTemplateDir/template-README.md" resolvedReadme
        echo "$resolvedReadme" > "$appDir/README.md"
    fi 

    # Copy customized Makefile based on user choices to the project-root folder.
    # This Makefile will have NO dependencies on the environment utilities
    display "    Customizing Makefile"
    local rootMakeDir=$projectRootTemplateDir/local-command-runner/make
    local rootEnvMakeFilePath=$appDir/Makefile
    local customerRootEnvMakeFilePath=$appDir/Makefile-4-customer

    if [[ "$destructiveUpgrade" == "n" ]] && [[ "$coinAppExists" == "y" ]] && [[ -f "$rootEnvMakeFilePath" ]]; then
        log "      upgrade-mode: skipping overwriting existing file - $rootEnvMakeFilePath"
    else
        log "      $rootEnvMakeFilePath"
        cp "$rootMakeDir/Makefile" "$rootEnvMakeFilePath"
    fi
    
    if [[ "$destructiveUpgrade" == "n" ]] && [[ "$coinAppExists" == "y" ]] && [[ "$coinConfigExists" == "y" ]]; then
        log "      upgrade-mode: skipping creating temporary file - $appDir/make-env"
    else
        log "      $appDir/make-env"
        cp "$rootMakeDir/make-env" "$appDir/make-env"
    fi
    
    if [[ "$destructiveUpgrade" == "n" ]] && [[ "$coinAppExists" == "y" ]] && [[ -f "$customerRootEnvMakeFilePath" ]]; then
        log "      upgrade-mode: skipping overwriting existing file - $customerRootEnvMakeFilePath"
    else
        log "      $customerRootEnvMakeFilePath"
        cp "$rootMakeDir/Makefile-4-customer" "$customerRootEnvMakeFilePath"
    fi

    # Not copying CICD commands to root Makefile since CICD
    # is usually not a deliverable
    # if [[ "$useCicd" == "y" ]]; then
    #     cat "$rootMakeDir/cicd/Makefile" >> "$rootEnvMakeFilePath"
    # fi

    if [[ "$destructiveUpgrade" == "y" ]] || [[ "$coinAppExists" == "n" ]] || [[ "$coinConfigExists" == "n" ]] && [[ "$hasSecondaryRegion" == "y" ]]; then  
        echo "AWS_PRIMARY_REGION = ###AWS_PRIMARY_REGION###" >> "$customerRootEnvMakeFilePath"
        echo "AWS_SECONDARY_REGION = ###AWS_SECONDARY_REGION###" >> "$customerRootEnvMakeFilePath"
    fi

    if [[ "$destructiveUpgrade" == "n" ]] && [[ "$coinAppExists" == "y" ]] && [[ "$coinConfigExists" == "y" ]]; then
        log "      upgrade-mode: skipping updating IaC configs for existing file - $customerRootEnvMakeFilePath"
    elif [[ "$iac" == "terraform" ]]; then
        echo "TF_S3_BACKEND_NAME = ###TF_S3_BACKEND_NAME###" >> "$customerRootEnvMakeFilePath"

        echo -e "\n# Run one-time wizard to resolve placeholders with values of your choice" >> "$customerRootEnvMakeFilePath"
        echo "init:" >> "$customerRootEnvMakeFilePath"
        echo -e "\t./init.sh" >> "$customerRootEnvMakeFilePath"

        if [[ "$hasSecondaryRegion" == "y" ]]; then
            cat "$rootMakeDir/terraform/bootstrap/cross-region-replication/Makefile" >> "$customerRootEnvMakeFilePath"
        else
            cat "$rootMakeDir/terraform/bootstrap/single-region/Makefile" >> "$customerRootEnvMakeFilePath"
        fi

        cat "$rootMakeDir/terraform/Makefile" >> "$customerRootEnvMakeFilePath"
    elif [[ "$iac" == "cdk2" ]]; then

        echo -e "\n# Run one-time wizard to resolve placeholders with values of your choice" >> "$customerRootEnvMakeFilePath"
        echo "init:" >> "$customerRootEnvMakeFilePath"
        echo -e "\t./init.sh" >> "$customerRootEnvMakeFilePath"

        cat "$rootMakeDir/cdk2/Makefile" >> "$customerRootEnvMakeFilePath"
    elif [[ "$iac" == "cf" ]]; then

        echo -e "\n# Run one-time wizard to resolve placeholders with values of your choice" >> "$customerRootEnvMakeFilePath"
        echo "init:" >> "$customerRootEnvMakeFilePath"
        echo -e "\t./init.sh" >> "$customerRootEnvMakeFilePath"

        cat "$rootMakeDir/cloudformation/Makefile" >> "$customerRootEnvMakeFilePath"
    fi

    if [[ "$coinAppExists" == "n" ]] || [[ "$coinConfigExists" == "n" ]] || [[ "$destructiveUpgrade" == "y" ]]; then
        resolve_placeholders_from_pattern_and_write_out_changes "$customerRootEnvMakeFilePath" "s|COIN_IAC_FIRST_MODULE_PLACEHOLDER|$firstIacModuleName|;"
    fi
    
    # Copy customized Makefile based on user choices to the environment folder.
    # This Makefile will use the environment utilities
    local makeDir=$projectDir/environment/local-command-runner/make
    local envMakeFilePath=$appEnvDir/Makefile
    cp "$makeDir/Makefile" "$envMakeFilePath"

    if [[ "$useCicd" == "y" ]]; then
        if [[ "$iac" == "terraform" ]]; then
            cat "$makeDir/terraform/cicd/Makefile" >> "$envMakeFilePath"
        elif [[ "$iac" == "cdk2" ]]; then
            cat "$makeDir/cdk2/cicd/Makefile" >> "$envMakeFilePath"
        else
            cat "$makeDir/cicd/Makefile" >> "$envMakeFilePath" # WHy isn't there a cloudformation folder here?
        fi
    fi

    # BEGIN - update project's root Makefile with IaC-specific commands
    if [[ "$iac" == "terraform" ]]; then

        # upgrade-mode should update environment/Makefile, just not root Makefile
        # cat "$makeDir/terraform/Makefile" >> "$envMakeFilePath"

        # Put commands from terraform-utils into the "COIN General Utilities" help section
        # and commands from wizard into the "COIN WIZARDS" help section
        local generalUtilsStartLine=$(sed -n "/@ COIN General Utilities/=" "$makeDir/Makefile")
        ((generalUtilsStartLine++)) # Increments line number
        local wizardsStartLine=$(sed -n "/@ COIN Wizards/=" "$makeDir/Makefile")
        ((wizardsStartLine++)) # Increments line number
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i "" "${generalUtilsStartLine}r $makeDir/terraform/terraform-utils/Makefile" "$envMakeFilePath"
            sed -i "" "${wizardsStartLine}r $makeDir/terraform/wizard/Makefile" "$envMakeFilePath"
        else
            sed -i "${generalUtilsStartLine}r $makeDir/terraform/terraform-utils/Makefile" "$envMakeFilePath"
            sed -i "${wizardsStartLine}r $makeDir/terraform/wizard/Makefile" "$envMakeFilePath"
        fi

        if [[ "$coinAppExists" == "n" ]] || [[ "$coinConfigExists" == "n" ]] || [[ "$destructiveUpgrade" == "y" ]]; then

            if [[ "$hasSecondaryRegion" == "y" ]]; then
                cat "$makeDir/terraform/bootstrap/cross-region-replication/Makefile" >> "$rootEnvMakeFilePath"
            else
                cat "$makeDir/terraform/bootstrap/single-region/Makefile" >> "$rootEnvMakeFilePath"
            fi

            cat "$makeDir/terraform/firstIacModule/Makefile" >> "$rootEnvMakeFilePath-temp-iac"
            resolve_placeholders_from_pattern_and_write_out_changes "$rootEnvMakeFilePath-temp-iac" "s|COIN_IAC_FIRST_MODULE_PLACEHOLDER|$firstIacModuleName|;"
            cat "$rootEnvMakeFilePath-temp-iac" >> "$rootEnvMakeFilePath"
            rm "$rootEnvMakeFilePath-temp-iac"
        fi

    elif [[ "$iac" == "cdk2" ]]; then

        # upgrade-mode should update environment/Makefile, just not root Makefile

        # Put commands from cdk-utils into the "COIN General Utilities" help section
        # and commands from wizard into the "COIN WIZARDS" help section
        local generalUtilsStartLine=$(sed -n "/@ COIN General Utilities/=" "$makeDir/Makefile")
        ((generalUtilsStartLine++)) # Increments line number
        local wizardsStartLine=$(sed -n "/@ COIN Wizards/=" "$makeDir/Makefile")
        ((wizardsStartLine++)) # Increments line number
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i "" "${generalUtilsStartLine}r $makeDir/cdk2/cdk-utils/Makefile" "$envMakeFilePath"
            sed -i "" "${wizardsStartLine}r $makeDir/cdk2/wizard/Makefile" "$envMakeFilePath"
        else
            sed -i "${generalUtilsStartLine}r $makeDir/cdk2/cdk-utils/Makefile" "$envMakeFilePath"
            sed -i "${wizardsStartLine}r $makeDir/cdk2/wizard/Makefile" "$envMakeFilePath"
        fi

        if [[ "$coinAppExists" == "n" ]] || [[ "$coinConfigExists" == "n" ]] || [[ "$destructiveUpgrade" == "y" ]]; then
            cat "$rootMakeDir/cdk2/bootstrap/Makefile" >> "$rootEnvMakeFilePath"
        fi

        if [[ "$coinAppExists" == "n" ]] || [[ "$coinConfigExists" == "n" ]] || [[ "$destructiveUpgrade" == "y" ]]; then
            cat "$makeDir/cdk2/firstIacModule/Makefile" >> "$rootEnvMakeFilePath-temp-iac"
            resolve_placeholders_from_pattern_and_write_out_changes "$rootEnvMakeFilePath-temp-iac" "s|COIN_IAC_FIRST_MODULE_PLACEHOLDER|$firstIacModuleName|;"
            cat "$rootEnvMakeFilePath-temp-iac" >> "$rootEnvMakeFilePath"
            rm "$rootEnvMakeFilePath-temp-iac"
        fi

    elif [[ "$iac" == "cf" ]]; then

        if [[ "$coinAppExists" == "n" ]] || [[ "$coinConfigExists" == "n" ]] || [[ "$destructiveUpgrade" == "y" ]]; then
            cat "$makeDir/cloudformation/Makefile" >> "$rootEnvMakeFilePath-temp-iac"
            resolve_placeholders_from_pattern_and_write_out_changes "$rootEnvMakeFilePath-temp-iac" "s|COIN_IAC_FIRST_MODULE_PLACEHOLDER|$firstIacModuleName|;"
            cat "$rootEnvMakeFilePath-temp-iac" >> "$rootEnvMakeFilePath"
            rm "$rootEnvMakeFilePath-temp-iac"
        fi
    fi
    # END - update project's root Makefile with IaC-specific commands

    # Copy CICD IAM role files to the project
    if [[ "$destructiveUpgrade" == "y" ]] || [[ "$coinAppExists" == "n" ]] || [[ "$coinConfigExists" == "n" ]] && [[ "$useCicd" == "y" ]]; then
        display "    Setting up CICD"
        
        if [[ "$cicd" == "gitlab" ]]; then

            if [[ "$REMOTE_ENV_VAR_LOC" == "na" ]]; then
                local glPipelineDir="na"
            else
                local glPipelineDir="all"
            fi

            if [[ "$iac" == "terraform" ]]; then

                if [[ "$glPipelineDir" != "na" ]]; then

                    # perform variable resolution on .gitlab-ci.yml
                    cp "$projectDir/cicd/gitlab/terraform/.gitlab-ci.yml" "$appDir/.gitlab-ci.yml"
                    local resolvedGl
                    resolve_placeholders "$appDir/.gitlab-ci.yml" "resolvedGl"
                    echo "$resolvedGl" > "$appDir/.gitlab-ci.yml"

                    resolve_placeholders_from_pattern_and_write_out_changes "$appDir/.gitlab-ci.yml" "s|COIN_IAC_FIRST_MODULE_PLACEHOLDER|$firstIacModuleName|;"

                    # The GitLab collapsible section start/end feature does not work with the resolve_placeholders
                    # function. Therefore, we have to manually replace collapsible section placeholders here
                    if [[ "$OSTYPE" == "darwin"* ]]; then
                        sed -i '' 's|START_INSTALL_PACKAGES|- echo -e "\\e[0Ksection_start:`date +%s`:packages[collapsed=true]\\r\\e[0KInstall Packages"|g' "$appDir/.gitlab-ci.yml"
                        sed -i '' 's|END_INSTALL_PACKAGES|- echo -e "\\e[0Ksection_end:`date +%s`:packages\\r\\e[0K"|g' "$appDir/.gitlab-ci.yml"
                    else
                        sed -i 's|START_INSTALL_PACKAGES|- echo -e "\\e[0Ksection_start:`date +%s`:packages[collapsed=true]\\r\\e[0KInstall Packages"|g' "$appDir/.gitlab-ci.yml"
                        sed -i 's|END_INSTALL_PACKAGES|- echo -e "\\e[0Ksection_end:`date +%s`:packages\\r\\e[0K"|g' "$appDir/.gitlab-ci.yml"
                    fi
                fi
                
                cp "$projectDir/cicd/gitlab/terraform/.gitlab-ci-sast.yml" "$appDir/.gitlab-ci-sast.yml"
                resolve_placeholders_from_pattern_and_write_out_changes "$appDir/.gitlab-ci-sast.yml" "s|COIN_IAC_FIRST_MODULE_PLACEHOLDER|$firstIacModuleName|;"

            elif [[ "$iac" == "cdk2" ]]; then

                if [[ "$glPipelineDir" != "na" ]]; then

                    # perform variable resolution on .gitlab-ci.yml
                    cp "$projectDir/cicd/gitlab/cdk2/.gitlab-ci.yml" "$appDir/.gitlab-ci.yml"
                    local resolvedGl
                    resolve_placeholders "$appDir/.gitlab-ci.yml" "resolvedGl"
                    echo "$resolvedGl" > "$appDir/.gitlab-ci.yml"

                    resolve_placeholders_from_pattern_and_write_out_changes "$appDir/.gitlab-ci.yml" "s|COIN_IAC_FIRST_MODULE_PLACEHOLDER|$firstIacModuleName|;"

                    # The GitLab collapsible section start/end feature does not work with the resolve_placeholders
                    # function. Therefore, we have to manually replace collapsible section placeholders here
                    if [[ "$OSTYPE" == "darwin"* ]]; then
                        sed -i '' 's|START_INSTALL_PACKAGES|- echo -e "\\e[0Ksection_start:`date +%s`:packages[collapsed=true]\\r\\e[0KInstall Packages"|g' "$appDir/.gitlab-ci.yml"
                        sed -i '' 's|END_INSTALL_PACKAGES|- echo -e "\\e[0Ksection_end:`date +%s`:packages\\r\\e[0K"|g' "$appDir/.gitlab-ci.yml"
                    else
                        sed -i 's|START_INSTALL_PACKAGES|- echo -e "\\e[0Ksection_start:`date +%s`:packages[collapsed=true]\\r\\e[0KInstall Packages"|g' "$appDir/.gitlab-ci.yml"
                        sed -i 's|END_INSTALL_PACKAGES|- echo -e "\\e[0Ksection_end:`date +%s`:packages\\r\\e[0K"|g' "$appDir/.gitlab-ci.yml"
                    fi
                fi
    
                cp "$projectDir/cicd/gitlab/cdk2/.gitlab-ci-sast.yml" "$appDir/.gitlab-ci-sast.yml"
                resolve_placeholders_from_pattern_and_write_out_changes "$appDir/.gitlab-ci-sast.yml" "s|COIN_IAC_FIRST_MODULE_PLACEHOLDER|$firstIacModuleName|;"
            
            elif [[ "$iac" == "cf" ]]; then

                if [[ "$glPipelineDir" != "na" ]]; then

                    # perform variable resolution on .gitlab-ci.yml
                    cp "$projectDir/cicd/gitlab/cloudformation/.gitlab-ci.yml" "$appDir/.gitlab-ci.yml"
                    local resolvedGl
                    resolve_placeholders "$appDir/.gitlab-ci.yml" "resolvedGl"
                    echo "$resolvedGl" > "$appDir/.gitlab-ci.yml"

                    resolve_placeholders_from_pattern_and_write_out_changes "$appDir/.gitlab-ci.yml" "s|COIN_IAC_FIRST_MODULE_PLACEHOLDER|$firstIacModuleName|;"

                    # The GitLab collapsible section start/end feature does not work with the resolve_placeholders
                    # function. Therefore, we have to manually replace collapsible section placeholders here
                    if [[ "$OSTYPE" == "darwin"* ]]; then
                        sed -i '' 's|START_INSTALL_PACKAGES|- echo -e "\\e[0Ksection_start:`date +%s`:packages[collapsed=true]\\r\\e[0KInstall Packages"|g' "$appDir/.gitlab-ci.yml"
                        sed -i '' 's|END_INSTALL_PACKAGES|- echo -e "\\e[0Ksection_end:`date +%s`:packages\\r\\e[0K"|g' "$appDir/.gitlab-ci.yml"
                    else
                        sed -i 's|START_INSTALL_PACKAGES|- echo -e "\\e[0Ksection_start:`date +%s`:packages[collapsed=true]\\r\\e[0KInstall Packages"|g' "$appDir/.gitlab-ci.yml"
                        sed -i 's|END_INSTALL_PACKAGES|- echo -e "\\e[0Ksection_end:`date +%s`:packages\\r\\e[0K"|g' "$appDir/.gitlab-ci.yml"
                    fi
                fi
    
                cp "$projectDir/cicd/gitlab/cloudformation/.gitlab-ci-sast.yml" "$appDir/.gitlab-ci-sast.yml"
                resolve_placeholders_from_pattern_and_write_out_changes "$appDir/.gitlab-ci-sast.yml" "s|COIN_IAC_FIRST_MODULE_PLACEHOLDER|$firstIacModuleName|;"
            fi

        fi

    elif [[ "$destructiveUpgrade" == "n" ]] && [[ "$coinAppExists" == "y" ]] && [[ "$useCicd" == "y" ]]; then
        log "    upgrade-mode: skipping Setting up CICD"
    fi

    # BEGIN - Copy IaC files to the project
    display "    Configuring IaC"
    if [[ "$coinAppExists" == "y" ]] && [[ "$coinConfigExists" == "y" ]] && [[ "$destructiveUpgrade" == "n" ]]; then
        log "upgrade-mode: skipping Configuring IaC since create-app is running in upgrade mode"
    elif [[ "$iac" == "terraform" ]]; then
        mkdir -p "$appDir/iac/roots/$firstIacModuleName"

        if [[ "$hasSecondaryRegion" == "y" ]]; then
            cp -r "$projectDir/iac/terraform/bootstrap/cross-region-replication/." "$appDir/iac/bootstrap"
        else
            cp -r "$projectDir/iac/terraform/bootstrap/single-region/." "$appDir/iac/bootstrap"
        fi

        cp -r "$projectDir/iac/terraform/templates" "$appDir/iac"

        # Copy Terraform documentation into environment directory
        cp "$projectDir/docs/DEV_GUIDE_TERRAFORM.md" "$appEnvDir/docs/DEV_GUIDE_TERRAFORM.md"

        # Create first IaC module for the application
        cp -r "$projectDir/iac/terraform/roots/iac-module-template/." "$appDir/iac/roots/$firstIacModuleName"

        # Put iac-module-template module under the app's environment directory so that it can be used as a new module template
        cp -r "$projectDir/iac/terraform/roots/iac-module-template" "$appEnvDir" 
        
        cp "$projectDir/iac/terraform/roots/README.md" "$appDir/iac/roots/README.md"

        local cicdDir=$projectDir/iac/terraform/roots/cicd
        local projectCicdDir=$appDir/iac/roots/cicd
        if [[ "$useCicd" == "y" ]]; then
            mkdir -p "$appDir/iac/roots/cicd"
            cp "$cicdDir/_globals.tf" "$projectCicdDir/_globals.tf"
            cp "$cicdDir/backend.tf" "$projectCicdDir/backend.tf"
            cp "$cicdDir/terraform.tfvars" "$projectCicdDir/terraform.tfvars"
            cp "$cicdDir/variables.tf" "$projectCicdDir/variables.tf"
        fi

        if [[ "$useCicd" == "y" ]]; then
            # Copy gitlab-cicd-role files
            cp "$cicdDir/gitlab-cicd-role/gitlab-cicd-role.tf" "$projectCicdDir/gitlab-cicd-role.tf"
            cat "$cicdDir/gitlab-cicd-role/terraform.tfvars" >> "$projectCicdDir/terraform.tfvars"
            cat "$cicdDir/gitlab-cicd-role/variables.tf" >> "$projectCicdDir/variables.tf"
        fi
        
        if [[ -d "$appDir/iac/roots/$firstIacModuleName" ]]; then
            cd "$appDir/iac/roots/$firstIacModuleName" 1> /dev/null
            terraform fmt 1> /dev/null
            cd - 1> /dev/null
        fi
        if [[ -d "$appDir/iac/roots/cicd" ]]; then
            cd "$appDir/iac/roots/cicd" 1> /dev/null
            terraform fmt 1> /dev/null
            cd - 1> /dev/null
        fi
        
    elif [[ "$iac" == "cdk2" ]]; then
        mkdir -p "$appDir/iac/roots/$firstIacModuleName"

        # Create first IaC module for the application
        cp -r "$projectDir/iac/cdk2/roots/iac-module-template/." "$appDir/iac/roots/$firstIacModuleName"

        # Put iac-module-template module under the app's environment directory so that it can be used as a new module template
        cp -r "$projectDir/iac/cdk2/roots/iac-module-template" "$appEnvDir"

        cp "$projectDir/iac/cdk2/roots/README.md" "$appDir/iac/roots/README.md"

        # Copy CDK documentation into environment directory
        cp "$projectDir/docs/DEV_GUIDE_CDK.md" "$appEnvDir/docs/DEV_GUIDE_CDK.md"

        local cicdDir=$projectDir/iac/cdk2/roots/cicd
        local projectCicdDir=$appDir/iac/roots/cicd
        local projectConstructsDir=$projectCicdDir/src/constructs
        local configFile="$projectCicdDir/src/utils/config.ts"
        local stackFile="$projectCicdDir/src/cicd-stack.ts"

        if [[ "$useCicd" == "y" ]]; then
            cp -r "$cicdDir" "$appDir/iac/roots"
        fi

        if [[ "$useCicd" == "y" ]]; then
            # delete cicd marker comments
            delete_file_matching_lines "$configFile" "_GITLAB_ROLE_CICD_PROPS_"
            delete_file_matching_lines "$stackFile" "_GITLAB_ROLE_CICD_CONSTRUCT"
        else
            # delete cicd configs and construct references
            if [[ -f "$configFile" ]]; then
                delete_file_content_range "$configFile" "BEGIN_GITLAB_ROLE_CICD_PROPS_API" "END_GITLAB_ROLE_CICD_PROPS_API"
                delete_file_content_range "$configFile" "BEGIN_GITLAB_ROLE_CICD_PROPS_VALUE" "END_GITLAB_ROLE_CICD_PROPS_VALUE"
            fi
            
            if [[ -f "$stackFile" ]]; then
                delete_file_matching_lines "$stackFile" "gitlab-cicd-iam-role-construct" # delete import statement
                delete_file_content_range "$stackFile" "BEGIN_GITLAB_ROLE_CICD_CONSTRUCT" "END_GITLAB_ROLE_CICD_CONSTRUCT"
            fi
            
            # delete construct files
            if [[ -f "$projectConstructsDir/gitlab-cicd-iam-role-construct.ts" ]]; then
                rm "$projectConstructsDir/gitlab-cicd-iam-role-construct.ts"
            fi
            
        fi
        
    elif [[ "$iac" == "cf" ]]; then
        mkdir -p "$appDir/iac/roots/$firstIacModuleName"

        cp "$projectDir/iac/cloudformation/roots/README.md" "$appDir/iac/roots/README.md"

        # Create first IaC module for the application
        cp -r "$projectDir/iac/cloudformation/roots/iac-module-template/." "$appDir/iac/roots/$firstIacModuleName"
        
        # Copy over new module template files so that app developers can easily create new modules
        cp -r "$projectDir/iac/cloudformation/roots/iac-module-template" "$appEnvDir"

        if [[ "$useCicd" == "y" ]]; then
            mkdir -p "$appDir/iac/roots/cicd"
            cp -r "$projectDir/cicd/gitlab/iam-role/cloudformation/." "$appDir/iac/roots/cicd"
        fi

    fi
    # END - Copy IaC files to the project

    # BEGIN Convert project make-env file to inline Makefile configs
    if [[ "$coinAppExists" == "n" ]] || [[ "$coinConfigExists" == "n" ]] || [[ "$destructiveUpgrade" == "y" ]]; then
        makeEnvContent=$(cat "$appDir/make-env")
        makeEnvContent="${makeEnvContent//$'\n'/\\n}" # escape newlines so that sed will work
        makeEnvContent="${makeEnvContent//$':='/' = '}" # replace ":=" syntax with " = "

        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' "s|APP_ENV_VARS_PLACEHOLDER|$makeEnvContent|g" "$customerRootEnvMakeFilePath"
        else
            sed -i "s|APP_ENV_VARS_PLACEHOLDER|$makeEnvContent|g" "$customerRootEnvMakeFilePath"
        fi
        rm "$appDir/make-env"
    fi
    # END Convert project make-env file to inline Makefile configs

    cd "$appDir"

    firstIacModuleNameUpper="$(spinalcase_to_camelcase "$firstIacModuleName")"

    if [[ "$coinAppExists" == "n" ]] || [[ "$coinConfigExists" == "n" ]] || [[ "$destructiveUpgrade" == "y" ]]; then
        log "\nResolving placeholders in $firstIacModuleName module...\n"
        resolve_template_files_from_pattern "$appDir/iac/roots/$firstIacModuleName" "s|###COIN_IAC_MOD_CAMELCASE###|$firstIacModuleNameUpper|;s|###COIN_IAC_MOD_SPINALCASE###|$firstIacModuleName|;"
        log "\nDONE Resolving placeholders in $firstIacModuleName module\n"
    fi
    
    take_custom_create_app_actions

    if [[ "$coinAppExists" == "n" ]]; then
        display "\n${CYAN}Finished generating application. Executing selected deployment steps...${NC}\n"
    fi
    
    if [[ "$createRemoteGitRepo" == "y" ]]; then
        if [[ "$repoAlreadyExists" == "n" ]] || [[ ! -d ".git" ]]; then

            if [[ ! -d ".git" ]]; then
                display "\n${CYAN}Creating Git Repository...${NC}\n"
                git init -b main
            else
                display "\n${CYAN}Adding COIN files to existing Git Repository...${NC}\n"
            fi

            git add .

            if [[ "$gitRepoProvider" == "gitlab" ]]; then

                local gitlabHost="${gitRemoteOriginPrefix}$gitRepoDomain"

                if [[ "$repoAlreadyExists" == "n" ]]; then
                    git remote add origin "git@${gitlabHost}:$gitProjectGroup/$gitProjectName.git"
                    display "Creating repository on GitLab..."
                    display "Note - this step requires Maintainer privileges in GitLab"
                    log "GitLab origin is git@${gitlabHost}:$gitProjectGroup/$gitProjectName.git"
                fi
  
            fi

            take_custom_git_config_actions

            if [[ "$repoAlreadyExists" == "n" ]]; then
                log "Creating a new Git repository and pushing the application code to the main branch"
                git commit -m "initial"
                git push origin HEAD
                git branch --set-upstream-to=origin/main main
                display "\n${CYAN}Finished creating Git Repository${NC}\n"
            else

                if [[ "$mainBranchAlreadyExists" == "n" ]]; then
                    git commit -m "initial"
                else
                    git commit -m "add/update COIN files"
                fi

                git push --set-upstream origin main
                display "\n${CYAN}Finished adding COIN files to existing Git Repository${NC}\n"
            fi

        else
            display "\nINFO: Skipping Git repository creation since the .git directory already exists.\n"
        fi
    
    fi

    # Run make commands to deploy things
    cd "$appEnvDir"
    
    optionally_push_env_vars_to_remote
    optionally_deploy_terraform_back_end_cf_stack
    optionally_deploy_cdk2_bootstrap_cf_stack
    optionally_deploy_cicd_resources

    take_custom_create_app_deployment_actions

    changeVerb="created"
    if [[ "$coinAppExists" == "y" ]] && [[ "$coinConfigExists" == "y" ]]; then
        changeVerb="upgraded"
    fi

    display "\n${GREEN}Congratulations! Your application has been $changeVerb at ${appDir}${NC}\n"
    if [[ "$coinAppExists" == "n" ]] || [[ "$coinConfigExists" == "n" ]] || [[ "$destructiveUpgrade" == "y" ]]; then
        display "Your entries have been saved to your project's environment/$envVarValueJsonFile file."
        display "This file can be modified by you as necessary.\n"
    fi

    if [[ "$coinAppExists" == "n" ]] || [[ "$coinConfigExists" == "n" ]] && [[ -d "$appDir/iac/roots/$firstIacModuleName" ]]; then
        iacName=""
        get_iac_name iacName
        display "A $iacName module has been created for you under your project's /iac/roots/$firstIacModuleName directory"
    fi

    if [[ "$coinAppExists" == "n" ]] || [[ "$coinConfigExists" == "n" ]]; then

        display "\n${CYAN}Possible Next Steps:${NC}"

        display "  * Let your teammates know how to download the new application."
        display "    They can configure their own application environment by running \"make ce\" from the command line."

        if [[ "$AWS_ACCOUNT_ID" == "000000000000" ]]; then
            display "  * Update your project's environment/$envVarValueJsonFile file and set a real AWS account number instead of all 0's."
        fi

        display "  * Familiarize yourself with the helpful utilities in the environment/Makefile."
        display "    * To see a list of available Make target names, just type \"make\" on the command line"
        display "    * You can add new environment-specific placeholders by editing your project's \"environment/app-env-var-names.txt\" file"
        display "  * Create a new IaC module with a custom name by entering \"make cim\" on the command line"
        display "  * When you are ready to deliver the solution to your customer, you can use the"
        display "    Extract Deliverable Wizard by running \"make extract-deliverable\" from"
        display "    your project's environment directory."

        if [[ -d "$appDir/iac/roots/$firstIacModuleName" ]]; then
            display "  * You can deploy the $firstIacModuleName module to AWS by running \"make deploy-$firstIacModuleName\"."
            display "    * Update or replace the $firstIacModuleName module to include your application's code."  
        fi

    else
        display "\n${YELLOW}To complete the upgrade, review your project's Git changes to ensure that you have not lost any project-specific changes, then commit and merge the upgraded COIN files.${NC}"
    fi

    display ""
}

validate_bash_version
log "\nSet CREATE_APP to \"$CREATE_APP\"\n"

if [[ ! -z "$1" ]]; then

    log "\nHeadless file input:"
    log "$(cat "$1")"

    export_wizard_answers "$1"
    export HEADLESS="y"
fi

# Add an event handler for when the script exits
trap write_choices_to_cache_file EXIT

check_for_updates
create_app