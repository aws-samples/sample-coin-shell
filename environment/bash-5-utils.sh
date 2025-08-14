#!/usr/bin/env bash

# This script performs steps that require the bash shell to be at
# least version 5. For example, declaring associative arrays and
# using namerefs.

# Utility functions that can be reused by "sourcing" them into other scripts.
# Can be run from command line if you pass the function name and its arguments
# as parameters to this script.

# Logs message and exits with error if the AWS CLI principal's account
# does not match the AWS account number for the application environment.
validate_aws_cli_account () {

    if [[ "$IS_VALID_CLI_ACCOUNT_ID" == "y" ]]; then
        return 0
    fi

    display "\nValidating the AWS CLI logged in principal for account $AWS_ACCOUNT_ID..."

    if [[ -z "$AWS_ACCOUNT_ID" ]] || [[ -z "$AWS_DEFAULT_REGION" ]]; then
        displayIssue ""
        displayIssue "environment values are not set in the current shell." "error"
        displayIssue "To fix this, execute your command from environment/Makefile,"
        displayIssue "which automatically sets environment values, OR export your"
        displayIssue "current environment's values into the shell by running"
        displayIssue "this command in a BASH shell:"
        displayIssue "\nsource environment/utility-functions.sh export_local_app_env_vars\n"
        exit 1
    fi

    local cliAccountId=$(aws sts get-caller-identity --query Account --output text)
    
    if [[ "$AWS_ACCOUNT_ID" != "$cliAccountId" ]]; then
        displayIssue ""
        
        if [[ -z "$AWS_ACCOUNT_ID" ]] || [[ "$AWS_ACCOUNT_ID" == "blank" ]] || [[ "$AWS_ACCOUNT_ID" == "000000000000" ]]; then
            displayIssue "${RED}Please set the AWS_ACCOUNT_ID environment value and try again.${NC}"
        elif [[ -z "$AWS_DEFAULT_REGION" ]] || [[ "$AWS_DEFAULT_REGION" == "blank" ]]; then
            displayIssue "${RED}Please set the AWS_DEFAULT_REGION environment value and try again.${NC}"
        else
            displayIssue "${RED}The AWS CLI must be logged in as a principal in the"
            displayIssue "       \"$AWS_ACCOUNT_ID\" account before proceeding.${NC}"
        fi

        displayIssue "Currently logged into account \"$cliAccountId\".\n"
        return 1
    else
        display "SUCCESS"

        # Cache value in memory so we don't keep checking over and over
        IS_VALID_CLI_ACCOUNT_ID="y"
    fi
}

# Deletes lines in a file between a start marker line and an end marker line.
# usage: delete_file_content_range "myFile.txt" "START_HERE" "END_HERE"
# param1: the path to the file
# param2: the pattern to match for the first line to delete
# param3: the pattern to match for the last line to delete
delete_file_content_range () {
    local filePath="$1"
    local startMarker="$2"
    local endMarker="$3"

    if [[ -z "$filePath" ]] || [[ -z "$startMarker" ]] || [[ -z "$endMarker" ]]; then
        displayIssue "delete_file_content_range - invalid input params" "error"
        displayIssue "usage: delete_file_content_range \"<filePath>\" \"<startMarker>\" \"<endMarker>\""
        return 1
    fi

    if [[ ! -f "$filePath" ]]; then
        displayIssue "delete_file_content_range - file \"$filePath\" does not exist." "error"
        return 1
    fi

    local startLine=$(sed -n "/$startMarker/=" "$filePath")
    if [[ -z "$startLine" ]]; then
        displayIssue "delete_file_content_range did not find starting marker \"$startMarker\" in \"$filePath\"" "error"
        return 1
    fi

    local endLine=$(sed -n "/$endMarker/=" "$filePath")
    if [[ -z "$endLine" ]]; then
        displayIssue "delete_file_content_range did not find ending marker \"$endMarker\" in \"$filePath\"" "error"
        return 1
    fi

    local newContents
    if newContents=$(sed "${startLine},${endLine}d" "$filePath"); then
        echo "$newContents" > "$filePath"
    else
        displayIssue "delete_file_content_range \""$filePath"\" \"$startMarker\" \"$endMarker\" failed" "error" # nosemgrep
        return 1
    fi
}

# Deletes lines in a file that match a pattern.
# usage: delete_file_matching_lines "myFile.txt" "something"
# param1: the path to the file
# param2: the pattern to match
delete_file_matching_lines () {
    local filePath="$1"
    local match="$2"

    if [[ -z "$filePath" ]] || [[ -z "$match" ]]; then
        displayIssue "delete_file_matching_lines - invalid input params" "error"
        displayIssue "usage: delete_file_matching_lines \"<filePath>\" \"<match>\""
        return 1
    fi

    if [[ ! -f "$filePath" ]]; then
        displayIssue "delete_file_matching_lines - file \"$filePath\" does not exist." "error"
        return 1
    fi

    local newContents
    if newContents=$(sed "/$match/d" "$filePath"); then
        echo "$newContents" > "$filePath"
    else
        displayIssue "delete_file_matching_lines \""$filePath"\" \""$match"\" failed" "error" # nosemgrep
        return 1
    fi
}

# Lists the code files in this project that contain environment variable lookups
# param1: optional - the directory to start the search from. Defaults to
#         the application root directory
list_code_template_files () {
    if [[ -z "$1" ]]; then
        cd "$projectDir"
    else
        cd "$1"
    fi

    log "\nlist_code_template_files:"
    log "$(pwd)"
    log "grep -l -R --exclude-dir=environment --exclude-dir=.terraform --exclude-dir=node_modules --exclude-dir=cdk.out 'process.env.\|System.getEnv(\|os.getenv(' ."
    log ""
    
    display "$(grep -l -R --exclude-dir=environment --exclude-dir=.terraform --exclude-dir=node_modules --exclude-dir=cdk.out 'process.env.\|System.getEnv(\|os.getenv(' .)"
}

# Lists the files in this project that contain environment placeholders
# param1: optional - the directory to start the search from. Defaults to
#         the application root directory
get_template_files () {
    if [[ -z "$1" ]]; then
        cd "$projectDir"
    else
        cd "$1"
    fi

    log "\nget_template_files:"
    log "$(pwd)"
    log "grep -l -R $COIN_EXCLUDE_TEMPLATE_SEARCH '###[^#]\{1,50\}###' ."
    log ""
    
    display "$(grep -l -R $COIN_EXCLUDE_TEMPLATE_SEARCH '###[^#]\{1,50\}###' .)" # nosemgrep
}

# Asks a question with a default answer and will not return the 
# answer until it matches the supplied regex
# param1: the name of the variable to set using the Bash nameref feature
# param2: the question to ask
# param3: the default answer to the question
# param4: the regex pattern to match
# param5: the error message to show if the pattern does not match
get_answer () {
    local -n answer=$1
    local question=$2
    local defaultAnswer=$3
    local pattern=$4
    local msg=$5
    local defaultOptionString
    [ -z "$defaultAnswer" ] && defaultOptionString="" || defaultOptionString="[$defaultAnswer] "

    while true
    do
        coinQuestionWithDefault="$(echo -e "$question $defaultOptionString")"
        read -p "$coinQuestionWithDefault" answer
        answer="${answer:=$defaultAnswer}"
        [[ $answer =~ $pattern ]] && return 0
        displayIssue "$msg" "error"
    done
}

# Asks a true or false question with a default answer and will not return the 
# answer until it is either "true" or "false"
# param1: the name of the variable to set using the Bash nameref feature
# param2: the question to ask
# param3: the default answer to the question 
true_or_false () {
    local -n tfAnswer="$1"
    local question="$2"
    local defaultAnswer="$3"
    local pattern="^(true|false)$"
    local msg="answer must be true or false"
    question="${question} (true/false)?"

    get_answer tfAnswer "$question" "$defaultAnswer" "$pattern" "$msg"

    log "\n$question"
    log "user answer: $tfAnswer"
}

# Validate that a value is "true" or "false". Log error and return error
# exit code if not.
# param1: variable name
# param2: variable value
validate_true_or_false () {

    if [[ -z "$1" ]]; then 
        displayIssue "validate_true_or_false - first parameter cannot be empty" "error"
        exit 1
    fi

    if [[ -z "$2" ]]; then 
        displayIssue "validate_true_or_false - value of \"$1\" cannot be empty" "error"
        exit 1
    fi

    local pattern="^(true|false)$"
    [[ $2 =~ $pattern ]] && return 0

    displayIssue "\"$1\" must be \"true\" or \"false\" but was \"$2\"" "error"
    exit 1
}

# Asks a yes or no question with a default answer and will not return the 
# answer until it is either y or n
# param1: the name of the variable to set using the Bash nameref feature
# param2: the question to ask
# param3: the default answer to the question 
yes_or_no () {
    local -n ynAnswer=$1
    local question=$2
    local defaultAnswer=$3
    local pattern="^[yn]$"
    local msg="answer must be y or n"
    question="${question} (y/n)?"

    get_answer ynAnswer "$question" "$defaultAnswer" "$pattern" "$msg"

    log "\n$question"
    log "user answer: $ynAnswer"
}

# Validate that a value is "y" or "n". Log error and return error
# exit code if not.
# param1: variable name
# param2: variable value
validate_yes_or_no () {

    if [[ -z "$1" ]]; then 
        displayIssue "validate_yes_or_no - first parameter cannot be empty" "error"
        exit 1
    fi

    if [[ -z "$2" ]]; then 
        displayIssue "\"$1\" must be \"y\" or \"n\" but was \"$2\"" "error"
        exit 1
    fi

    local pattern="^[yn]$"
    [[ $2 =~ $pattern ]] && return 0

    displayIssue "\"$1\" must be \"y\" or \"n\" but was \"$2\"" "error"
    exit 1
}

# Asks a question with a default answer and will not return the 
# answer until a valid number of characters is entered
# param1: the name of the variable to set using the Bash nameref feature
# param2: the question to ask
# param3: the default answer to the question 
# param4: the minimum valid answer length
# param5: the maximum valid answer length
# param6: optional. if set to "allowWhitespace", it will accept an answer
#         from the user that contains whitespace
length_range () {
    local -n rangeAnswer=$1
    local question=$2
    local defaultAnswer=$3
    local minLength=$4
    local maxLength=$5
    if [[ "$6" == "allowWhitespace" ]]; then
        local pattern="^.{${minLength},${maxLength}}$"
    else
        local pattern="^[^[:space:]]{${minLength},${maxLength}}$"
    fi
    
    local msg="answer must be at least $minLength character(s) and no more than $maxLength. No whitespaces allowed."
    question="${question}"
    get_answer rangeAnswer "$question" "$defaultAnswer" "$pattern" "$msg"

    log "\n$question"
    log "user answer: $rangeAnswer"
}

# Asks a question and will not return until the answer is a valid AWS
# account number
# param1: the name of the variable to set using the Bash nameref feature
# param2: the question to ask
# param3: the default answer to the question 
aws_account_number () {
    local -n accountAnswer=$1
    local question=$2
    local defaultAnswer=$3
    local pattern="^[0-9]{12}$"
    local msg="Value must be a 12 digit number"

    get_answer accountAnswer "$question" "$defaultAnswer" "$pattern" "$msg" 

    log "\n$question"
    log "user answer: $accountAnswer"   
}

# Read input from a terminal and do not print what the user is typing
# param1: Bash nameref for the variable that will be set to the user's input
read_secret () {
    local -n readValue=$1

    # Disable echo.
    stty -echo

    # Read secret.
    read readValue

    # Enable echo.
    stty echo

    # Print a newline because the newline entered by the user after
    # entering the passcode is not echoed. This ensures that the
    # next line of output begins at a new line.
    echo
}

# Custom `select` implementation with support for a default choice
# that the user can make by pressing just ENTER.
# Pass the choices as the first argument with | delimited values ; e.g. 'Yes|No'
# The first choice is the default choice, unless you designate
# one of the choices as the default by passing the default value as the third parameter
# The default choice is printed with a trailing ' [default]'
# Pass the choice values as the second argument with | delimited values ; e.g. 'YES|NO'
# Output is the value of the selected choice
# Example:
#    choice=$(select_with_default 'Yes|No|Abort' 'One|Two|Three' 'Two')
select_with_default () {

    local options
    local values

    IFS='|' read -r -a options <<< "$1"
    IFS='|' read -r -a values <<< "$2"

    local numItems=${#options[@]}
    local item itemIndex i=0 defaultIndex=1

    log "\nselect_with_default options:\n${1}"
    log "\nselect_with_default option values:\n${2}"
    log "\nselect_with_default options count: $numItems"

    if [[ ! -z "$3" ]]; then
        local dli
        for dli in "${!values[@]}";
        do
            if [[ "${values[$dli]}" = "$3" ]];
            then
                defaultIndex="$(("$dli" + 1))"
                break
            fi
        done
    fi

    zeroBasedDefaultIndex="$(("$defaultIndex" - 1))"

    # allow for printing text in yellow
    local py=$(tput setaf 3)
    local pnormal=$(tput sgr0)
    
    # Print numbered menu items, based on the arguments passed.
    for itemIndex in ${!options[@]}; do
        item=${options[$itemIndex]}
        [[ "$itemIndex" == "$zeroBasedDefaultIndex" ]] && item="${item} ${py}[default]${pnormal}"
        printf '%s\n' "$((++i))) $item"
    done >&2 # Print to stderr, as `select` does.

    # Prompt the user for the index of the desired item.
    while :; do
        printf %s "${PS3-#? }" >&2 # Print the prompt string to stderr, as `select` does.
        read -r index
        # Make sure that the input is either empty or that a valid index was entered.
        [[ -z $index ]] && index=$defaultIndex && break  # empty input == default choice  
        (( index >= 1 && index <= numItems )) 2>/dev/null || { display "Invalid selection. Please try again." "stderr"; continue; }
        break
    done

    # Output the selected choice.
    zeroChoiceIndex="$(("$index" - 1))"
    log "user answer: ${values[$zeroChoiceIndex]}"
    printf ${values[$zeroChoiceIndex]}

}

set_reconciled_json () {
    # Loop over environment names and add them to reconciled json
    ENV_RECONCILED_JSON="{}"
    for i in ${!ENV_KEYS[@]}; do
        local varName=${ENV_KEYS[$i]}

        if [[ -v "LOOKUPS[$varName]" ]] && [[ "$DYNAMIC_LOOKUPS_SET" != "y" ]]; then
            continue
        fi  

        # Special syntax needed to get the exit code for a local variable
        local varValue; varValue=$(get_env_var_value "$varName")
        
        if [ $? -ne 0 ]; then
            log "\nExiting from set_reconciled_json since get_env_var_value returned an error exit code"
            exit 1
        fi

        ENV_RECONCILED_JSON=$(echo "$ENV_RECONCILED_JSON" | jq --arg key "$varName" --arg val "$varValue" '. + {($key): $val}')
    done
}

# Compare environment constant values with environment config values.
# If an environment config value overrides a constant value, log a warning.
detect_constant_overrides () {
    for i in ${!ENV_KEYS[@]}; do
        local envVarName=${ENV_KEYS[$i]}
        local envVarValue="${ENV_CONFIGS[$envVarName]}"
        local constVal=""

        if [[ -v "ENV_CONSTANTS[$envVarName]" ]] && [[ ! -z "${ENV_CONSTANTS[$envVarName]}" ]]; then
            constVal="${ENV_CONSTANTS[$envVarName]}"
        fi

        if [[ ! -z "$constVal" ]] && [[ ! -z "$envVarValue" ]] && [[ "$constVal" != "$envVarValue" ]]; then
            if [[ "$constVal" == "blank" ]]; then
                if [[ "$ROOT_CONTEXT" != "create_app_wizard" ]]; then
                    display "\nINFO: environment config value detected for \"$envVarName\", which overrides the blank value set in the environment constants."
                fi
            else
                displayIssue "\"$envVarName\" constant override detected. Override value: \"$envVarValue\". Constant value: \"$constVal\" " "warn"
            fi
        fi
    done

    display ""
}

# Loads settings from JSON files and caches the results in associative arrays
# Sets global variables: ENV_CONSTANTS, ENV_CONFIGS, ENV_RECONCILED_JSON, EXIT_AFTER_DEBUG, IS_COIN_ENV_FILE_FOUND
load_env_settings () {

    if [[ ! -z "$ENV_RECONCILED_JSON" ]]; then
        return
    fi

    # do not ever load environment json files from CICD pipeline, even
    # if they are committed into version control 
    if [[ "$COIN_NO_ENV_FILE" != "true" ]] && [[ "$CI" != "true" ]]; then

        log "\nConfigs will be read from JSON environment config files.\n"

        # Load environment constants, if they are configured
        if [[ -f "$projectEnvDir/$projectEnvConstantsFileName" ]]; then
            while IFS="=" read -r key value
            do
                ENV_CONSTANTS[$key]="$value"
            done < <(jq -r 'to_entries|map("\(.key)=\(.value)")|.[]' "$projectEnvDir/$projectEnvConstantsFileName")
        fi

        # Now load settings from the current environment JSON file
        load_env_var_file_name

        if [[ -f "$COIN_ENV_VAR_FILE_NAME" ]]; then

            if jq empty "$COIN_ENV_VAR_FILE_NAME" 2>/dev/null; then
                log "Environment File at \"$COIN_ENV_VAR_FILE_NAME\" contains structurally valid JSON"
            else
                displayIssue "Environment File at \"$COIN_ENV_VAR_FILE_NAME\" contains structurally invalid JSON" "error"
                exit 1
            fi

            while IFS="=" read -r key value
            do
                ENV_CONFIGS[$key]="$value"
            done < <(jq -r 'to_entries|map("\(.key)=\(.value)")|.[]' "$COIN_ENV_VAR_FILE_NAME")
        
            IS_COIN_ENV_FILE_FOUND="y"

            COIN_SENSITIVE_ENV_VAR_FILE_NAME="${COIN_ENV_VAR_FILE_NAME/.json/-sensitive.json}"
            if [[ -f "$COIN_SENSITIVE_ENV_VAR_FILE_NAME" ]]; then
                while IFS="=" read -r key value
                do
                    ENV_SENSITIVE_CONFIGS[$key]="$value"
                done < <(jq -r 'to_entries|map("\(.key)=\(.value)")|.[]' "$COIN_SENSITIVE_ENV_VAR_FILE_NAME")
            
                IS_COIN_SENSITIVE_ENV_FILE_FOUND="y"
            else
                IS_COIN_SENSITIVE_ENV_FILE_FOUND="n"
            fi

        else
            IS_COIN_ENV_FILE_FOUND="n"

            if [[ "$ROOT_CONTEXT" != @(create_env_wizard|pull_env_vars) ]]; then
                
                if [[ "$IS_CURRENT_ENV_SET" == "y" ]]; then
                    displayIssue "environment settings file \"$COIN_ENV_VAR_FILE_NAME\" could not be found.${NC}" "error"
                    displayIssue "Please ensure that the current environment is set correctly in environment/.current-environment\n"
                fi
                
                # Don't exit for export_local_app_env_vars, since that will break sourcing
                if [[ "$ROOT_CONTEXT" != "export_local_app_env_vars" ]]; then
                    EXIT_AFTER_DEBUG="y"
                fi
                
            fi
        fi

    else
        log "\nConfigs will be read from environment variables only. JSON environment config loading is disabled.\n"
        for i in ${!ENV_KEYS[@]}; do
            ENV_CONFIGS[${ENV_KEYS[$i]}]="${!ENV_KEYS[$i]}"
        done
        IS_COIN_ENV_FILE_FOUND="y"
    fi

    # Create a JSON structure in memory that merges the environment constants with the
    # environment configs. The environment configs take precedence if both have the
    # same variable set.

    set_reconciled_json

    export_local_app_env_vars

    # Now load dynamic lookups if appropriate
    if [[ "$IS_CURRENT_ENV_SET" == "y" ]] || [[ "$CI" == "true" ]] || [[ "$COIN_NO_ENV_FILE" == "true" ]]; then

        # Have to source this a second time so that lookup values can be set to environment variables
        source "$projectEnvDir/dynamic-lookups.sh" 1> /dev/null

        # Log dynamic lookup configurations
        if [[ "$DYNAMIC_RESOLUTION" =~ ^[Yy]$ ]]; then
            log "\nDynamic Lookups are ENABLED"
        else
            log "\nDynamic Lookups are DISABLED"
        fi
        if [[ "$FAIL_ON_LOOKUP_ERROR" != "n" ]]; then
            log "\nDynamic Lookups FAIL_ON_LOOKUP_ERROR is ENABLED"
        else
            log "\nDynamic Lookups FAIL_ON_LOOKUP_ERROR is DISABLED"
        fi
        log "\nDynamic Lookup Configurations:"
        for i in "${!LOOKUPS[@]}"
        do
            log "$i = ${LOOKUPS[$i]}"
        done
        log ""

        # Set dynamic values into the reconciled JSON and environment variables
        # If dynamic resolution is off, cached values will be set if available
        set_all_dynamic_values
        set_reconciled_json
        export_local_app_env_vars

    else
        log "Ignoring dynamic values since IS_CURRENT_ENV_SET=\"$IS_CURRENT_ENV_SET\", CI=\"$CI\", COIN_NO_ENV_FILE=\"$COIN_NO_ENV_FILE\""
    fi

    detect_constant_overrides
}

# Gets the current local environment
get_current_env () {
    if [[ "$CI" == "true" ]] || [[ "$COIN_NO_ENV_FILE" == "true" ]] || [[ "$CREATE_APP" == "true" ]]; then
        echo "$ENV_NAME"
    else
        if [[ ! -f "$projectCurrentEnvFileName" ]]; then
            displayIssue "No current local environment is configured. \"$projectCurrentEnvFileName\" does not exist." "error"
            exit 1
        fi

        head -n 1 "$projectCurrentEnvFileName"
    fi
}

# Sets the current local environment to the first argument supplied and executes
# any hook functions registered to be run when the environment is changed
# param1: the environment to set as current
set_current_env () {
    local envToSet=$1

    [ -z "$envToSet" ] && displayIssue "environment name is required as the first argument to this script" "error" \
    && displayIssue "usage: envToSet <myEnvName>" && exit 1

    echo "$envToSet" > "$projectCurrentEnvFileName"
}

# Returns "y" or "n"
does_current_env_setting_exist () {
    if [[ -f "$projectCurrentEnvFileName" ]]; then
        echo "y"
    else 
        echo "n"
    fi
}

# Looks for "environment name to AWS CLI profile mapping" file at
# environment/.cli-profiles.json. If this file exits, sets the 
# "AWS_PROFILE" environment variable to the profile that is set for 
# the current environment. If the current environment is not configured
# in .cli-profiles.json, looks to see if a "default" profile is set for
# all unmapped environments. The AWS CLI will use the value of 
# the "AWS_PROFILE" to know what AWS Account to communicate with.
# Example .cli-profiles.json
# {
#    "default": "default"
#    "qa":  "qa"
# }
# param1: OPTIONAL. the environment name. Defaults to the current environment name
set_aws_cli_profile () {
    log "\nset_aws_cli_profile was called."
    local profileJsonFile="$projectEnvDir/.cli-profiles.json"
    if [[ -f "$profileJsonFile" ]]; then
        local currentEnv="$1"

        if [[ -z "$currentEnv" ]]; then
            currentEnv=$(get_current_env)
        fi

        local cliProfile="$(cat "$profileJsonFile" | jq -r --arg currentEnv "$currentEnv" '.[$currentEnv] | select(type == "string")')" # nosemgrep

        if [[ -z "$cliProfile" ]]; then
            cliProfile="$(cat "$profileJsonFile" | jq -r '.default | select(type == "string")')" # nosemgrep
        fi

        if [[ -z "$cliProfile" ]]; then
            log "AWS CLI profile could not be found for the \"$currentEnv\" environment.\n"
        elif [[ "$AWS_PROFILE" != "$cliProfile" ]]; then
            display "\nSetting AWS_PROFILE to \"$cliProfile\" based on .cli-profiles.json"
            export AWS_PROFILE="$cliProfile"
        else
            log "AWS_PROFILE was already set to \"$cliProfile\"\n"
        fi
        
    else
        log "INFO: No $projectEnvDir/.cli-profiles.json file was found.\n"
    fi
}

# Creates an empty local environment file with the supplied envirnment name
# param1: the environment name
create_env_var_file () {
    log "\nCreating new empty environment JSON file at $projectEnvDir/.environment-$1.json\n"
    echo "{}" > "$projectEnvDir/.environment-$1.json"
}

# Deletes a local environment file with the supplied envirnment name
# No warning or confirmation is provided before the delete
# param1: the environment name
delete_env_var_file () {
    rm "$projectEnvDir/.environment-$1.json"
}

# Return "y" if a local environment file already exists or "n" if not
# param1: the environment name
does_env_var_file_exist () {
    if [[ -f "$projectEnvDir/.environment-$1.json" ]]; then
        echo "y"
    else
        echo "n"
    fi
}

# Detects the current environment to see which environment should be used
# and then returns the name of the file that holds the variable values
# for that environment
load_env_var_file_name () {

    if [[ ! -z "$COIN_ENV_VAR_FILE_NAME" ]]; then 
        return
    fi

    curEnvSettingExists=$(does_current_env_setting_exist)
    local setMe="setme"

    if [[ "$curEnvSettingExists" == "n" ]]; then
        set_current_env "$setMe"
    fi
    
    local currentEnv=$(get_current_env)
    if [[ "$currentEnv" == "$setMe" ]] || [[ -z "$currentEnv" ]]; then

        local showWarning="y"
        if [[ "$ROOT_CONTEXT" =~ ^(create_env_wizard|switch_local_environment|pull_env_vars)$ ]]; then
            showWarning="n"
        fi

        if [[ "$showWarning" == "y" ]]; then
            displayIssue "The current environment setting is not configured" "warn"
            displayIssue "This is expected if you just downloaded your application's source code."
            displayIssue ""
            displayIssue "The current environment setting can be configured using one of these:"
            displayIssue "  * run \"make ce\" to start the Create New Application Environment Wizard if"
            displayIssue "    you haven't set up an environment yet. "
            displayIssue "  * run \"make sce\" to switch to an existing environment"
            displayIssue "  * run \"make pull-env-vars\" to download an environment"
            displayIssue "    from a remote source"
            displayIssue "  * directly set an existing environment as current by typing its"
            displayIssue "    name into \"$projectCurrentEnvFileName\"."
            displayIssue ""
        else
            log "WARNING: The current environment setting is not configured"
            log "This is expected if you just downloaded your application's source code.\n"
        fi

    else
        IS_CURRENT_ENV_SET="y"
        COIN_ENV_VAR_FILE_NAME="$projectEnvDir/.environment-$currentEnv.json"
    fi
}

# Sets the names of application environment variables into a global ENV_KEYS list.
load_env_var_names () {

    # No need to read the file again if we've already loaded the variable names 
    if [[ ${#ENV_KEYS[@]} -gt 0 ]]; then
        return
    fi

    local requiredEnvVars
    IFS=$'\n' read -d '' -r -a requiredEnvVars < "$projectEnvDir/app-env-var-names.txt"
    local varIndex
    
    # Create list of environment variable names
    for varIndex in ${!requiredEnvVars[@]}; do
        local varName=${requiredEnvVars[$varIndex]}
        
        # ignore any line that begins with -- or #
        [[ "$varName" =~ ^--.*|^#.*|^\/.* ]] && continue
        
        # strip trailing whitespace and anything after that so that we
        # just get the variable name and remove any comments
        varName=${varName%[[:space:]]*}
        ENV_KEYS+=("$varName")
    done

    # try to set Git repo variables from remote origin setting
    if [[ -z "$CREATE_APP" ]]; then
        if [[ -z "$gitProjectName" ]]; then set_git_env_vars_from_remote_origin; fi
        if [[ ! -z "$gitProjectName" ]]; then ENV_KEYS+=("gitProjectName"); fi
        if [[ ! -z "$gitProjectGroup" ]]; then ENV_KEYS+=("gitProjectGroup"); fi
        if [[ ! -z "$gitRepoDomain" ]]; then ENV_KEYS+=("gitRepoDomain"); fi
    fi

}

# Retrieves the description of an environment variable.
# param1: the name of the environment variable to retrieve the description for
get_env_var_description () {
    local envVarName=$1
    [ -z "$envVarName" ] && displayIssue "environment variable name is required as the first argument to this script" "error" \
    && displayIssue "usage: get_env_var_description <myEnvVarName>" && exit 1

    log "\nLooking up env var description for var name: \"$envVarName\""

    local lineNum=$(grep -n "^${envVarName}$" "$projectEnvDir/app-env-var-names.txt" | cut -d : -f 1)

    log "\nlineNum for var name: \"$envVarName\" is \"$lineNum\""

    local description=""
    local lineText=""

    while [ $lineNum -gt 0 ]
    do
        lineNum=$((lineNum - 1))
        lineText="$(sed -n "${lineNum}p" "$projectEnvDir/app-env-var-names.txt")"

        lineText="${lineText#"# "}"
        lineText="${lineText#"#"}"

        if [[ -z "$lineText" ]]; then
            break
        else
            description="${lineText}\n${description}"
        fi
        
    done

    echo -e "$description"
}

# Retrieves the value of an environment variable.
# Throw an error if the variable does not have a value.
# param1: the name of the environment variable to retrieve the value for
get_env_var_value () {
    local envVarName=$1
    [ -z "$envVarName" ] && displayIssue "environment variable name is required as the first argument to this script" "error" \
    && displayIssue "usage: get_env_var_value <myEnvVarName>" && exit 1
    
    local envVarOverrideName="COIN_OVERRIDE_$envVarName"
    local currentEnv=$(get_current_env)
    local envVarValue="${ENV_CONFIGS[$envVarName]}"
    local constVal
    local sensitiveVal

    if [[ -v "LOOKUPS[$envVarName]" ]]; then
        if [[ -z "${ENV_LOOKUP_CONFIGS[$envVarName]}" ]]; then
            envVarValue="blank"
        else
            envVarValue="${ENV_LOOKUP_CONFIGS[$envVarName]}"
        fi
    fi

    if [[ -v "ENV_CONSTANTS[$envVarName]" ]] && [[ ! -z "${ENV_CONSTANTS[$envVarName]}" ]]; then
        constVal="${ENV_CONSTANTS[$envVarName]}"
    fi

    if [[ -v "ENV_SENSITIVE_CONFIGS[$envVarName]" ]] && [[ ! -z "${ENV_SENSITIVE_CONFIGS[$envVarName]}" ]]; then
        sensitiveVal="${ENV_SENSITIVE_CONFIGS[$envVarName]}"
    fi

    if [[ -z "$envVarValue" ]]; then
        if [[ "$envVarName" =~ ^(gitProjectName|gitProjectGroup|gitRepoDomain)$ ]]; then
            envVarValue="${!envVarName}"
        else
            envVarValue="$constVal"
        fi
    elif [[ "$envVarValue" == "sensitive" ]] && [[ ! -z "$sensitiveVal" ]]; then
        envVarValue="$sensitiveVal"
    fi

    if [[ -z "$envVarValue" ]] && [[ ! "$ROOT_CONTEXT" =~ ^(create_env_wizard|delete_env_wizard|pull_env_vars|get_current_env|get_local_environment_names|switch_local_environment)$ ]]; then

        if [[ "$IS_COIN_ENV_FILE_FOUND" == "y" ]]; then
            displayIssue "\"$envVarName\" environment variable is not set in the " "error"
            displayIssue "${RED}  \"$currentEnv\" environment. Set it to a value or \"blank\" if there${NC}"
            displayIssue "${RED}  is no value or remove it from \"app-env-var-names.txt\" if it is not needed.${NC}"
        fi
        exit 1
    fi

    if [[ "$envVarValue" == "sensitive" ]] && [[ ! "$ROOT_CONTEXT" =~ ^(create_env_wizard|delete_env_wizard|pull_env_vars|get_current_env|get_local_environment_names|switch_local_environment)$ ]]; then
        if [[ "$IS_COIN_SENSITIVE_ENV_FILE_FOUND" == "n" ]]; then
            displayIssue "\"$envVarName\" environment variable is set to \"sensitive\" but no $COIN_SENSITIVE_ENV_VAR_FILE_NAME file was found." "error"
            displayIssue "${RED}To fix this, create a \"${COIN_SENSITIVE_ENV_VAR_FILE_NAME}\" file and set a value for \"$envVarName\"${NC}\n"
        else
            displayIssue "\"$envVarName\" environment variable is set to \"sensitive\" but no value was set in ${COIN_SENSITIVE_ENV_VAR_FILE_NAME}." "error"
            displayIssue "${RED}To fix this, set a value for \"$envVarName\" in \"${COIN_SENSITIVE_ENV_VAR_FILE_NAME}\"${NC}\n"
        fi
        exit 1
    fi

    # Support command line overrides
    if [[ ! -z "${!envVarOverrideName}" ]]; then
        log "Command line override detected for \"$envVarName\". Original value was \"$envVarValue\" and override value is \"${!envVarOverrideName}\""
        envVarValue="${!envVarOverrideName}"
    fi

    echo "$envVarValue"
}

# Exports (as environment variables) all values defined in the .environment.json
# file and those set as constants, sensitive values, and dynamic lookups. 
# If calling from command prompt directly, use the "source" keyword.
export_local_app_env_vars () {
    if [[ "{}" != "$ENV_RECONCILED_JSON" ]]; then
        eval "export $(echo "$ENV_RECONCILED_JSON" \
        | jq -r 'to_entries | map("\(.key)=\(.value)") | @sh')"
    fi
}

# Convenience utility to get all COIN environment variables populated
# into the user's current shell. This function can be called from an
# easy-to-remember Makefile command.
# For Mac, will copy env var settings to the clipboard. For other OS, 
# it will print the contents for the user to copy then paste into their 
# current shell.
echo_export_local_app_env_vars () {
    if [[ "{}" != "$ENV_RECONCILED_JSON" ]]; then
        # Attempt to add AWS_PROFILE to exported variables
        local exportJSON="$ENV_RECONCILED_JSON"
        set_aws_cli_profile
        if [[ ! -z "$AWS_PROFILE" ]]; then
            exportJSON=$(echo "$exportJSON" | jq --arg key "AWS_PROFILE" --arg val "$AWS_PROFILE" '. + {($key): $val}')
        fi
        
        if [[ "$OSTYPE" == "darwin"* ]]; then
            echo "export $(echo "$exportJSON" \
            | jq -r 'to_entries | map("\(.key)=\(.value)") | @sh')" | pbcopy
            display "${CYAN}$ENV_NAME environment variables copied to the clipboard. Just paste them into your shell!${NC}\n"
        else
            display "${CYAN}Copy the following and paste into your shell to set all COIN $ENV_NAME env configs:${NC}\n"
            display "export $(echo "$exportJSON" \
            | jq -r 'to_entries | map("\(.key)=\(.value)") | @sh')"
            display ""
        fi
    else
        log "Cannot export app env vars since ENV_RECONCILED_JSON is: $ENV_RECONCILED_JSON"
    fi
}

# Exports (as environment variables) all values defined in the AWS SSM Parameter
# Store for the current environment (the value of $ENV_NAME)
# If calling from command prompt directly, use the "source" keyword.
export_env_vars_from_ssm () {

    local ssmEnvJson=$(aws ssm get-parameters-by-path \
    --region "$AWS_DEFAULT_REGION" \
    --max-items 200 \
    --path "/$APP_NAME/remoteVars/$ENV_NAME/" \
    --with-decryption \
    --query "Parameters[].{key:Name,value:Value}")

    $(echo "$ssmEnvJson" | \
    jq -r ". | map(\"export \" + (.key|ltrimstr(\"/$APP_NAME/remoteVars/$ENV_NAME/\")) + \"=\" + .value + \"\")[]")
}

# Pulls environment variable values from a remote source, e.g. GitLab or SSM Parameter Store
# param1 - optional. Use only for headless mode. This is the name of the environment to pull
# param2 - optional. Use only for headless mode. This is the remote source name, e.g. "ssm" or "gitlab"
pull_env_vars () {
    local importEnv
    local importFrom
    local gitLabToken
    local HEADLESS_PULL="n"

    if [[ ! -z "$1" ]] && [[ ! -z "$2" ]]; then
        # Allow for running in headless mode
        importEnv="$1"
        importFrom="$2"
        gitLabToken="$gltoken"
        HEADLESS_PULL="y"
    else

        local remoteLocNames="AWS SSM Parameter Store|GitLab (requires Maintainer privileges)"
        local remoteLocVals="ssm|gitlab"
        display "Which remote environment do you want to import from?"
        importFrom=$(select_with_default "$remoteLocNames" "$remoteLocVals" "ssm")
        local remoteEnvNames

        if [[ "$importFrom" == "ssm" ]]; then
            remoteEnvNames="$(echo "$(get_ssm_environment_names)")"
        elif [[ "$importFrom" == "gitlab" ]]; then
            
            ask_gitlab_token gitLabToken
            local remoteEnvNames
            get_gitlab_environment_names "remoteEnvNames" "$gitLabToken"
        fi

        if [[ -z "$remoteEnvNames" ]] || [[ "$remoteEnvNames"  == "[]" ]];
        then
            display "No remote environments found"
            return 0
        fi

        remoteEnvNames="$(echo "$remoteEnvNames" | sed -e 's/ /|/g')"

        display "Which environment do you want to import?"
        importEnv=$(select_with_default "$remoteEnvNames" "$remoteEnvNames" "")
    fi

    local envFileExisted=$(does_env_var_file_exist "$importEnv")

    # Backup current environment and set the environment to import as the current environment
    local backupEnvName=$ENV_NAME
    ENV_NAME="$importEnv"
    log "\nSetting ENV_NAME to \"$ENV_NAME\" before importing the environment from the remote store"
    
    COIN_ENV_VAR_FILE_NAME="$projectEnvDir/.environment-$ENV_NAME.json"
    log "Setting COIN_ENV_VAR_FILE_NAME to $COIN_ENV_VAR_FILE_NAME before saving values from the remote store"

    # if [[ "$envFileExisted" == "n" ]]; then
    create_env_var_file "$importEnv"
    # fi
    
    if [[ "$importFrom" == "ssm" ]]; then
        pull_env_vars_from_ssm_to_local_json
    elif [[ "$importFrom" == "gitlab" ]]; then
        pull_env_vars_from_gitlab_to_local_json "$gitLabToken" || exit 1
    fi

    if [[ -f "$COIN_ENV_VAR_FILE_NAME" ]]; then
        display "\nSuccessfully imported \"$importEnv\" environment!\n"

        if [[ "$backupEnvName" != "$importEnv" ]] && [[ "$HEADLESS_PULL" == "n" ]]; then
            local switchToImported
            yes_or_no switchToImported "Would you like to make the imported \"$importEnv\" environment your current environment?" "n"
            if [[ "$switchToImported" == "y" ]]; then
                set_current_env "$importEnv"
                display "Your local current environment is now \"$importEnv\".\n"
            fi
        fi

    else
        # if [[ "$envFileExisted" == "n" ]]; then
        delete_env_var_file "$importEnv"
        # fi
        display ""
        displayIssue "\"$importEnv\" environment could not be imported." "error"
        exit 1
    fi
    
}

# Looks up a dynamic value (if it is not already cached) and sets the environment variable value
# param1: the name of the lookup variable
set_dynamic_value () {
    local dynamicVarName="$1"
    local wholeDvName="$dynamicVarName"
    local parameterExpr=""

    # Since secrets can be JSON, allow specific JSON attributes to be selected
    # The property name should come after "_PROP_" in the lookup variable name
    if [[ "$dynamicVarName" == SECRET_* ]] && [[ "$dynamicVarName" == *_PROP_* ]] ; then
        dynamicVarName="${wholeDvName%_PROP_*}"
        local dynamicPrefix="${dynamicVarName}_PROP_"
        parameterExpr="${wholeDvName#"$dynamicPrefix"}"
    fi

    log "Checking cache for $dynamicVarName"

    # Check for cached value
    local envVarValue=$(echo "$LOOKUP_VALS_JSON" | jq -r --arg placeholder "$dynamicVarName" '.[$placeholder] | select(type == "string")')

    if [[ ! -z "$envVarValue" ]]; then
        log "Found $dynamicVarName cached value."
    elif [[ "$dynamicVarName" == SSM_* ]]; then

        if [[ ! "${LOOKUPS[$dynamicVarName]}" ]]; then
            displayIssue "SSM lookup of config $dynamicVarName must have a non-blank SSM parameter key configured in dynamic-lookups.sh" "error" "always"
            return 1
        fi

        local ssmRegion=$AWS_DEFAULT_REGION
        for regionKey in "${!COIN_REGIONS[@]}"
        do
            if [[ "$dynamicVarName" == *"$regionKey"* ]]; then
                ssmRegion=${COIN_REGIONS[$regionKey]}
            fi
        done
        
        display "\nLooking up \"${LOOKUPS[$dynamicVarName]}\" from region $ssmRegion for config $dynamicVarName\n" "stderr" "always"
        local envVarValue=$(aws ssm --region "$ssmRegion" get-parameter --name ${LOOKUPS[$dynamicVarName]} --with-decryption --query Parameter.Value --output text)

        if [[ -z "$envVarValue" ]]; then
            if [[ "$FAIL_ON_LOOKUP_ERROR" != "n" ]]; then
                displayIssue "SSM lookup of \"${LOOKUPS[$dynamicVarName]}\" from region $ssmRegion failed or returned an empty value.${NC}" "error" "always"
                return 1
            else
                displayIssue "SSM lookup of \"${LOOKUPS[$dynamicVarName]}\" from region $ssmRegion failed or returned an empty value." "warn" "always"
                displayIssue "Value will be defaulted to a blank string" "" "always"
                envVarValue="blank"
            fi 
        fi

        # Add looked up value to in-memory cache
        LOOKUP_VALS_JSON=$(echo "$LOOKUP_VALS_JSON" | jq --arg key "$dynamicVarName" --arg val "$envVarValue" '. + {($key): $val}')
    
    elif [[ "$dynamicVarName" == SECRET_* ]]; then

        if [[ ! "${LOOKUPS[$wholeDvName]}" ]]; then
            displayIssue "SECRET lookup of config $wholeDvName must have a non-blank secret name configured in dynamic-lookups.sh" "error" "always"
            return 1
        fi

        display "\nLooking up \"${LOOKUPS[$wholeDvName]}\" from region $AWS_DEFAULT_REGION for config $wholeDvName\n" "stderr" "always"

        local envVarValue="$(aws secretsmanager get-secret-value --region "$AWS_DEFAULT_REGION" --secret-id "${LOOKUPS[$wholeDvName]}" --query SecretString --output text)"

        if [[ -z "$envVarValue" ]]; then
            if [[ "$FAIL_ON_LOOKUP_ERROR" != "n" ]]; then
                displayIssue "SECRET lookup of \"${LOOKUPS[$wholeDvName]}\" from region $AWS_DEFAULT_REGION failed or returned an empty value." "error" "always"
                return 1
            else
                displayIssue "SECRET lookup of \"${LOOKUPS[$wholeDvName]}\" from region $AWS_DEFAULT_REGION failed or returned an empty value." "warn" "always"
                displayIssue "Value will be defaulted to a blank string" "" "always"
                envVarValue="blank"
            fi 
        fi

        log "Caching value for $dynamicVarName"

        # Add looked up value to in-memory cache
        LOOKUP_VALS_JSON=$(echo "$LOOKUP_VALS_JSON" | jq --arg key "$dynamicVarName" --arg val "$envVarValue" '. + {($key): $val}')

    else
        displayIssue "$dynamicVarName lookup cannot be completed." "error"
        displayIssue "If it is an SSM parameter, rename it to SSM_{$dynamicVarName}."
        displayIssue "If it is secret, rename it to SECRET_{$dynamicVarName}."
        return 1
    fi

    # If the dynamic value was a secret and we only want a single property out of the
    # secret's JSON payload, use jq to pull out the property we want
    if [[ ! -z "$parameterExpr" ]] && [[ "$envVarValue" != "blank" ]]; then
        local tmpEnvVarValue=$(echo "$envVarValue" | jq -r --arg parameterExpr "$parameterExpr" '.[$parameterExpr] | select(type == "string")')
    
        if [[ "$COIN_NO_ENV_FILE" != "true" ]] && [[ "$CI" != "true" ]]; then
            log "$dynamicVarName $parameterExpr property value is $tmpEnvVarValue"
        elif [[ " ${CLEAR_TEXT_ENV_KEYS[*]} " =~ " ${dynamicVarName} " ]]; then
            log "$dynamicVarName $parameterExpr property value is $tmpEnvVarValue"
        else
            log "$dynamicVarName $parameterExpr property value is maskedForCIMode"
        fi
        
        envVarValue=$tmpEnvVarValue
    fi

    # Set the dynamic lookup environment variable value
    echo "$envVarValue" > "./temp-env-var-val.txt"
    export $wholeDvName="$(cat "./temp-env-var-val.txt")"
    rm "./temp-env-var-val.txt"
}

# Loops through all dynamic values and sets them all in the ENV_LOOKUP_CONFIGS associative array
# If dynamic resolution is turned on, writes lookup values to a cache file
set_all_dynamic_values () {

    local dynEnvName=$(get_current_env)
    local lookupCacheFileName="$projectEnvDir/.environment-${dynEnvName}-lookup-cache.json"

    local lookupCacheFileExists
    log "\nChecking for dynamic lookup cache file at \"$lookupCacheFileName\""
    if [[ -f "$lookupCacheFileName" ]]; then
        lookupCacheFileExists="y"
        log "Dynamic lookup cache file FOUND\n"
    else
        lookupCacheFileExists="n"
        log "Dynamic lookup cache file NOT found\n"
    fi

    # If coin_hooks did the dynamic lookups within the last few seconds, dont look them up again
    local freshCacheFile=$(find "$projectEnvDir" -name ".environment-${dynEnvName}-lookup-cache.json" -newermt '5 seconds ago')

    if [[ "$DYNAMIC_RESOLUTION" =~ ^[Yy]$ ]] && [[ -z "$freshCacheFile" ]]; then
        set_aws_cli_profile
        validate_aws_cli_account || return 1
    fi
    
    for lookupKey in "${!LOOKUPS[@]}"
    do
        if [[ "$DYNAMIC_RESOLUTION" =~ ^[Yy]$ ]]; then
            if [[ -z "$freshCacheFile" ]]; then
                set_dynamic_value "$lookupKey"
                ENV_LOOKUP_CONFIGS[$lookupKey]="${!lookupKey}"
            else
                ENV_LOOKUP_CONFIGS[$lookupKey]=$(cat "$lookupCacheFileName" | jq -r --arg placeholder "$lookupKey" '.[$placeholder] | select(type == "string")') # nosemgrep
            fi

        else
            # Try to pull value from cache file
            if [[ "$lookupCacheFileExists" == "y" ]]; then
                local tmpCachedVal=$(cat "$lookupCacheFileName" | jq -r --arg placeholder "$lookupKey" '.[$placeholder] | select(type == "string")') # nosemgrep
                : ${tmpCachedVal:=blank} # nosemgrep # set to "blank" if cached value not found
                ENV_LOOKUP_CONFIGS[$lookupKey]="$tmpCachedVal"
            else
                ENV_LOOKUP_CONFIGS[$lookupKey]="blank"  
            fi 
        fi
    done

    DYNAMIC_LOOKUPS_SET="y"

    # Cache the lookup results to a JSON file
    if [[ "$DYNAMIC_RESOLUTION" =~ ^[Yy]$ ]] && [[ -z "$freshCacheFile" ]]; then
        local i
        local dynCacheJson="{}"

        for i in "${!ENV_LOOKUP_CONFIGS[@]}"
        do
            dynCacheJson=$(echo "$dynCacheJson" | jq --arg key "$i" --arg val "${ENV_LOOKUP_CONFIGS[$i]}" '. + {($key): $val}')
        done

        # Write dynamic lookup values to JSON cache file
        echo "$dynCacheJson" > "$lookupCacheFileName"
        log "\nWrote out new lookup cache file to \"$lookupCacheFileName\"\n"
    fi
}

# This function reads the file that is supplied as the first function argument.
# It then resolves all placeholder values found in that file by
# replacing the ###ENV_VAR_NAME### placeholder with the value of the ENV_VAR_NAME.
# Finally, it sets a nameref variable to the file contents with all variables resolved.
# param1: the name of the file that has placeholders to resolve
# param2: the name of the variable to set using the Bash nameref feature
resolve_placeholders () {

    local filePath=$1
    local -n outputVar=$2
    if [[ -z "$filePath" ]]; then
        displayIssue "The first argument to resolve_placeholders must be the path of the file to resolve" "error"
        exit 1
    fi

    log "\nResolving placeholders in \"$filePath\"...\n"

    set_aws_cli_profile

    local SED_PATTERNS
    local resolvedContent="$(cat "$filePath")"

    # Loop that replaces variable placeholders with values
    local varName
    while read varName
    do
        # check that the env var value can be retrieved or exit if not
        # special syntax needed to get exit code from local variable
        local envVarValue; envVarValue="$(get_env_var_value "$varName")" || exit 1

        if [[ "$envVarValue" == "blank" ]]; then
            envVarValue=""
        fi

        SED_PATTERNS="s|###${varName}###|${envVarValue}|g;"
        if [[ "$COIN_NO_ENV_FILE" != "true" ]] && [[ "$CI" != "true" ]]; then
            log "resolve_placeholders SED Replacement Pattern: $SED_PATTERNS"
        elif [[ " ${CLEAR_TEXT_ENV_KEYS[*]} " =~ " ${varName} " ]]; then
            log "resolve_placeholders SED Replacement Pattern: $SED_PATTERNS"
        else
            log "resolve_placeholders SED Replacement Pattern: s|###${varName}###|maskedForCIMode|g;"
        fi
        
        resolvedContent="$(echo "$resolvedContent" | sed ''"$SED_PATTERNS"'')"

    done <<< "$(IFS=$'\n'; echo -e "${ENV_KEYS[*]}" )"

    # Add support for replacing CUR_DIR_NAME, which is the name of the
    # directory (without path) that the file resides in
    local dirName=$(dirname "$filePath")

    if [[ "$projectUseNestedPathForCurDirName" == "y" ]]; then

        if [[ "$dirName" == "${projectDir}/"* ]]; then
            dirName="${dirName#"${projectDir}/"}" # if dirName is an absolute path, change it to relative by stripping out the path to the app
        fi

        local noStartingSlashProjectIacRootModulePath="${projectIacRootModulePath#"/"}" # remove leading / from projectIacRootModulePath
        dirName=${dirName#"$noStartingSlashProjectIacRootModulePath/"} # remove the leading projectIacRootModulePath from the dirName
    else
        dirName=${dirName%/.}        # strip path ending with /. if it exists
        dirName=${dirName##*/}       # just get directory name without path
        dirName=${dirName:-/}        # to correct for the case where dir=/
    fi

    SED_PATTERNS="s|###CUR_DIR_NAME###|$dirName|g;"
    log "resolve_placeholders SED Replacement Pattern: $SED_PATTERNS\n"
    local command="$(echo -e "echo -e \"$resolvedContent\" | sed '$SED_PATTERNS'")"
    resolvedContent="$(echo "$resolvedContent" | sed ''"$SED_PATTERNS"'')"

    if [[ $resolvedContent =~ ^.*(###.*###) ]]; then
        displayIssue "$filePath contains unresolved placeholder: ${BASH_REMATCH[1]}" "error"

        if [[ "${BASH_REMATCH[1]}" == "###git"* ]]; then
            displayIssue "Placeholder names that start with \"git\" are set based upon the local Git" "error"
            displayIssue "${RED}repo settings. Please ensure that this project is set up in a Git repo and${NC}"
            displayIssue "${RED}that \"git remote -v\" returns a value. If you do not want to set up the Git${NC}"
            displayIssue "${RED}CLI repo settings locally, you can set the git* placeholder values by exporting${NC}"
            displayIssue "${RED}them as environment variables in your shell. Do not use app-env-var-names.txt${NC}"
            displayIssue "${RED}to configure git* variables.${NC}"
        else
            displayIssue "This could be because the placeholder expression has a typo or"
            displayIssue "because the placeholder is not defined in app-env-var-names.txt"
        fi

        exit 1
    fi

    log "\nFinished resolving placeholders in \"$filePath\"\n"

    outputVar="$resolvedContent"
}

# This function reads the file that is supplied as the first function argument.
# It then resolves all placeholder values found in that file by
# using the supplied sed expression(s).
# Finally, it replaces the file contents on disk so that it has the resolved values.
# param1: the name of the file (with path) that has placeholders to resolve
# param2: the sed patterns to use for search/replace
#   example pattern that does search/replace on 2 variables:  "s|placeholder1|placeholder1Value|;s|placeholder2|placeholder2Value|;"
resolve_placeholders_from_pattern_and_write_out_changes () {
    local templateFileName="$1"
    local sedPatterns="$2"

    if [[ -z "$templateFileName" ]]; then
        displayIssue "The first argument to resolve_placeholders_from_pattern_and_write_out_changes must be the path of the file to resolve" "error"
        return 1
    fi

    if [[ -z "$sedPatterns" ]]; then
        displayIssue "The second argument to resolve_placeholders_from_pattern_and_write_out_changes must be sed patterns." "error"
        return 1
    fi

    local resolved
    resolve_placeholders_from_pattern "$templateFileName" resolved "$sedPatterns"

    if [ $? -eq 0 ]; then
        echo "$resolved" > "$templateFileName"
    else
        displayIssue "resolve_placeholders_from_pattern_and_write_out_changes failed for file \"$templateFileName\" and patterns: $sedPatterns" "error"
    fi
}

# This function reads the file that is supplied as the first function argument.
# It then resolves all placeholder values found in that file by
# using the supplied sed expression.
# Finally, it sets a nameref variable to the file contents with all variables resolved.
# param1: the name of the file that has placeholders to resolve
# param2: the name of the variable to set using the Bash nameref feature
# param3: the sed patterns to use for search/replace
#   example pattern that does search/replace on 2 variables:  "s|placeholder1|placeholder1Value|;s|placeholder2|placeholder2Value|;"
resolve_placeholders_from_pattern () {

    local filePath=$1
    local -n outputVar=$2
    local sedPatterns=$3
    if [[ -z "$filePath" ]]; then
        displayIssue "The first argument to resolve_placeholders_from_pattern must be the path of the file to resolve" "error"
        exit 1
    fi

    log "\nResolving placeholders in \"$filePath\"...\n"

    local resolvedContent="$(cat "$filePath")"

    log "resolve_placeholders_from_pattern SED Replacement Pattern: $sedPatterns\n"
    local command="$(echo -e "echo -e \"$resolvedContent\" | sed '$sedPatterns'")"
    resolvedContent="$(echo "$resolvedContent" | sed ''"$sedPatterns"'')"

    if [[ $resolvedContent =~ ^.*(###.*###) ]]; then
        log "WARNING: $filePath contains unresolved placeholder: ${BASH_REMATCH[1]} during sed pattern replacement" "error"
        log "This could be because the placeholder expression has a typo or simply becuase your sed expression does "
        log "not contain a replacement value for the expression"

        # Do not exit. It can be perfectly valid to have an unresolved placeholder for sed pattern replacement
    fi

    log "\nFinished resolving placeholders in \"$filePath\"\n"

    outputVar="$resolvedContent"
}

# Prints out the names and values of all environment settings, including
# dynamically resolved settings, so that devs can easily check if their
# environments are configured correctly.
print_current_environment () {
    display "\n${CYAN}Here are the values from your current environment ($ENV_NAME):${NC}"
    local displayJson=$(echo -e "$ENV_RECONCILED_JSON" | jq --color-output --sort-keys)
    display "$displayJson\n"
}

# Resolve placeholders in a file and print the result to the console
# param1: the name of the file that has placeholders to resolve
print_resolved_placeholders () {
    local filePath=$1
    local resolved
    resolve_placeholders "$filePath" resolved

    display "${CYAN}Resolved Template ($filePath):${NC}\n"

    display "$resolved"
}

# Resolves placeholders in all application template files.
# WARNING - this can leave the files in a changed state, which could cause
#           them to accidentally get committed to version control without 
#           the placeholders
# param1: optional - the resolution mode. Defaults to overwriting template files.
#         If you provide a value of "dryRun" then the template files will be resolved 
#         but their contents on disk will not be overwritten
#         If you provide a value of "backup" then the template files will be resolved 
#         but a backup will be taken first so that the original file can be restored
# param2: optional - the directory to look for templates. Defaults to the application
#         root directory
resolve_template_files () {
    local replaceMode=$1
    local templateRootDir=$2
    local templatesArray=($(get_template_files "$templateRootDir"))
    local failureCount=0
    local successCount=0
    local failedFiles
    local mode
    
    if [[ -z "$replaceMode" ]]; then
        mode="OVERWRITE_FILES"
    elif [[ "dryrun" == "${replaceMode,,}" ]]; then # case-insensitive string comparison
        mode="DRY_RUN"
    elif [[ "backup" == "${replaceMode,,}" ]]; then # case-insensitive string comparison
        mode="BACKUP"
    else
        displayIssue "invalid value of \"$replaceMode\" supplied to resolve_template_files function." "error"
        displayIssue "Valid values are \"\", \"dryRun\", and \"backup\" ."
        exit 1
    fi

    if [[ -z "$templateRootDir" ]]; then
        templateRootDir="$projectDir"
    fi

    display "\nResolving templates in $templateRootDir"

    local i
    for i in ${!templatesArray[@]}; do
        local fileName=${templatesArray[$i]}

        if [[ "$fileName" == *"$BACKUP_SUFFIX" ]]; then
            continue
        fi

        if [[ "$fileName" == *".zip" ]]; then
            continue
        fi

        if [[ "$fileName" == ./* ]]; then
            # Remove leading ./ from file name
            fileName="$(echo -e "$fileName" | sed -e 's,^\./,,')"
        fi

        displayIfNotQuiet "\nResolving $templateRootDir/$fileName"

        local resolved
        if [[ "$mode" == "BACKUP" ]]; then
            backup_then_resolve "$templateRootDir" "$fileName"
            if [ $? -eq 0 ]; then
                successCount=$((successCount+1))
            else
                failureCount=$((failureCount+1))
                failedFiles="${failedFiles}      $templateRootDir/$fileName\n\n"
            fi
        else
            local resolved
            resolve_placeholders "$templateRootDir/$fileName" resolved
            if [ $? -eq 0 ]; then
                successCount=$((successCount+1))

                # check for "dry run" mode and overwrite file if not
                if [[ "$mode" != "DRY_RUN" ]]; then
                    echo "$resolved" > "$templateRootDir/$fileName"
                fi
            else
                failureCount=$((failureCount+1))
                failedFiles="${failedFiles}      $templateRootDir/$fileName\n\n"
            fi
        fi

    done

    if [[ ${#LOOKUPS[@]} -gt 0 ]] && [[ ! "$DYNAMIC_RESOLUTION" =~ ^[Yy]$ ]]; then
        displayIfNotQuiet "\nWARNING: dynamic variable resolution is disabled."
        displayIfNotQuiet "All dynamic variables will be set to an empty string."
        displayIfNotQuiet "You can enable dynamic variable resolution by setting"
        displayIfNotQuiet "the \"DYNAMIC_RESOLUTION\" environment variable to \"y\"\n"
    fi

    displayIfNotQuiet "\nTemplate Resolution Result Summary"
    displayIfNotQuiet "   MODE:    $mode"
    displayIfNotQuiet "   SUCCESS: $successCount"

    if [[ "$failureCount" == "0" ]]; then
        displayIfNotQuiet "   FAILURE: $failureCount"
    else
        displayIfNotQuiet "   ${RED}FAILURE: ${failureCount}${NC}"
    fi
    
    if [[ ! -z "$failedFiles" ]]; then
        display "   Failed Files:"
        display "$failedFiles"
        return 1
    fi
}

# Resolves placeholders in application template files using the supplied sed expression.
# WARNING - this will leave the files in a changed state, which could cause
#           them to accidentally get committed to version control without 
#           the placeholders
# param1: - the directory to look for templates. Defaults to the application
#         root directory
# param2: the sed patterns to use for search/replace
#   example pattern that does search/replace on 2 variables:  "s|placeholder1|placeholder1Value|;s|placeholder2|placeholder2Value|;"
resolve_template_files_from_pattern () {

    local templateRootDir="$1"
    local sedPatterns=$2

    if [[ -z "$templateRootDir" ]]; then
        displayIssue "resolve_template_files_from_pattern - template directory input parameter is required." "error"
        exit 1
    elif [[ ! -d "$templateRootDir" ]]; then
        displayIssue "resolve_template_files_from_pattern - template directory \"$templateRootDir\" does not exist." "error"
        exit 1
    elif [[ -z "$sedPatterns" ]]; then
        displayIssue "resolve_template_files_from_pattern - sedPatterns input parameter is required." "error"
        exit 1
    fi

    local templatesArray=($(get_template_files "$templateRootDir"))
    local failureCount=0
    local successCount=0
    local failedFiles
    local mode="OVERWRITE_FILES"
    
    log "\nresolve_template_files_from_pattern Resolving templates in $templateRootDir"

    local i
    for i in ${!templatesArray[@]}; do
        local fileName=${templatesArray[$i]}

        if [[ "$fileName" == *"$BACKUP_SUFFIX" ]]; then
            continue
        fi

        if [[ "$fileName" == *".zip" ]]; then
            continue
        fi

        log "\nresolve_template_files_from_pattern Resolving $templateRootDir/$fileName"

        local resolved
        resolve_placeholders_from_pattern "$templateRootDir/$fileName" resolved "$sedPatterns"

        if [ $? -eq 0 ]; then
            successCount=$((successCount+1))
            echo "$resolved" > "$templateRootDir/$fileName"
        else
            failureCount=$((failureCount+1))
            failedFiles="${failedFiles}      $templateRootDir/$fileName\n\n"
        fi
        
    done

    log "\nresolve_template_files_from_pattern Template Resolution Result Summary"
    log "   MODE:    $mode"
    log "   SUCCESS: $successCount"
    log "   FAILURE: $failureCount"
    
    if [[ ! -z "$failedFiles" ]]; then
        log "   Failed Files:"
        log "$failedFiles"
        return 1
    fi
}

# Hook that generates a file that can be imported by make. The imported
# file will define make variables for all application environment variables.
# param1: optional - the make target that will be executed
generate_make_env () {

    local substring="bash"
    local curShell=$(ps -p $$ | tail -n +2)
    
    echo "$ENV_RECONCILED_JSON" | jq -r '. | to_entries | map("export " + .key + ":=" + .value)[]' > "$projectEnvDir/make-env"

    set_aws_cli_profile
    if [[ ! -z "$AWS_PROFILE" ]]; then
        echo "export AWS_PROFILE:=$AWS_PROFILE" >> "$projectEnvDir/make-env"
    fi

    if ! grep -q "gitProjectGroup" "$projectEnvDir/make-env"; then
        set_git_env_vars_from_remote_origin
        if [[ ! -z "gitProjectGroup" ]]; then
            echo "export gitProjectGroup:=$gitProjectGroup" >> "$projectEnvDir/make-env"
            echo "export gitProjectName:=$gitProjectName" >> "$projectEnvDir/make-env"
            echo "export gitRepoDomain:=$gitRepoDomain" >> "$projectEnvDir/make-env"
        fi
    fi

    local makeEnvContents=$(cat "$projectEnvDir/make-env")
    log "\nContents written out to make-env file:\n$makeEnvContents\n"
}

# Hook that generates a .env file by converting the environment/app-env-var-names.txt file
# to have key/value pairs
generate_env_file () {

    local substring="bash"
    local curShell=$(ps -p $$ | tail -n +2)

    if [[ -z "$ENV_NAME" ]]; then 
        log "\nSkipping generating $projectConfigsDir/$projectConfigsEnvFileName file since current environment was not loaded\n"
        return 0
    fi

    mkdir -p "$projectConfigsDir"
    
    # Take the app-env-var-names.txt and use it as an .env file. Run sed to set the value of
    # all of the variable names

    cp "$projectEnvDir/app-env-var-names.txt" "$projectConfigsDir/$projectConfigsEnvFileName"

    local SED_PATTERNS
    local resolvedContent="$(cat "$projectConfigsDir/$projectConfigsEnvFileName")"

    # Loop that replaces variable names with varName=varValue
    local varName
    while read varName
    do
        local envVarValue=$(get_env_var_value "$varName")

        if [[ "$envVarValue" == "blank" ]]; then
            envVarValue=""
        fi

        SED_PATTERNS="s|${varName}$|$varName=\"$envVarValue\"|;"
        if [[ "$COIN_NO_ENV_FILE" != "true" ]] && [[ "$CI" != "true" ]]; then
            log "generate_env_file SED Replacement Pattern: $SED_PATTERNS"
        elif [[ " ${CLEAR_TEXT_ENV_KEYS[*]} " =~ " ${varName} " ]]; then
            log "generate_env_file SED Replacement Pattern: $SED_PATTERNS"
        else
            log "generate_env_file SED Replacement Pattern: s|###${varName}###|maskedForCIMode|g;"
        fi

        resolvedContent="$(echo "$resolvedContent" | sed ''"$SED_PATTERNS"'')"
    done <<< "$(IFS=$'\n'; echo "${ENV_KEYS[*]}" )"
    
    echo -e "$resolvedContent" > "$projectConfigsDir/$projectConfigsEnvFileName"
    if [[ "$COIN_NO_ENV_FILE" != "true" ]] && [[ "$CI" != "true" ]]; then
        log "\nContents written out to $projectConfigsDir/$projectConfigsEnvFileName file:\n$resolvedContent\n"
    else
        log "\nContents written out to $projectConfigsDir/$projectConfigsEnvFileName\n"
    fi
}

# Executes hooks defined in constants.sh
coin_hooks () {
    log "\nExecuting COIN hooks..."
    local i
    for i in "${COIN_BEFORE_HOOKS[@]}"
    do
        log "Executing hook: $i"
        eval "$i"
    done

    log "\nFinished executing COIN hooks\n"
}

# Outputs application environment variables that are
# available in the current shell as JSON.
app_env_vars_to_json () {        
    local envVarKeyValuePairs=()
    local i

    for i in ${!ENV_KEYS[@]}; do
        local varName=${ENV_KEYS[$i]}

        if [[ ! -z "${LOOKUPS[$varName]}" ]] || [[ ! -z "${ENV_CONSTANTS[$varName]}" ]]; then 
            continue
        fi

        # check that the env var value can be retrieved or exit if not
        # special syntax needed to get exit code from local variable
        local envVarValue; envVarValue=$(get_env_var_value "$varName") || exit 1
        
        envVarKeyValuePairs+=("${varName}=${envVarValue}")
    done
    
    # Print application environment variable key/value pairs in JSON format
    local appEnvVarJson="{}"

    # Loop over array and append to JSON
    for item in "${envVarKeyValuePairs[@]}"; do
        # Split the item by '=' and read into key and value
        IFS='=' read -r key value <<< "$item"
        
        # Append to JSON using jq
        appEnvVarJson=$(echo "$appEnvVarJson" | jq --arg k "$key" --arg v "$value" '. + {($k): $v}')
    done

    echo "$appEnvVarJson"
}

# Based on the required variables set in app-env-var-names.txt, 
# prints .environment JSON with blank values
print_blank_app_env_vars_json () {  
    local envVarKeyValuePairs=()
    local i
    
    for i in ${!ENV_KEYS[@]}; do
        local varName=${ENV_KEYS[$i]}
        
        if [[ "$varName" == "REMOTE_ENV_VAR_LOC" ]]; then
            local envVarValue="na"
        elif [[ ! -z "${LOOKUPS[$varName]}" ]]; then
            continue
        elif [[ "$varName" =~ ^(gitProjectName|gitProjectGroup|gitRepoDomain)$ ]]; then
            continue
        else
            local envVarValue="blank"
        fi
    
        envVarKeyValuePairs+=("${varName}=${envVarValue}")
    done
    
    # Print application environment variable key/value pairs in JSON format
    local joined
    printf -v joined '%s,' "${envVarKeyValuePairs[@]}"
    echo "${joined%,}" | jq -R 'split(",") | map(split("=")) | map({(.[0]): .[1]}) | add'
}

# Takes a backup of a file then runs resolve_placeholders on the file.
# Does nothing if file does not exist.
# param1: path to directory that contains the file to resolve
# param2: file name where file may contain placeholders to resolve
backup_then_resolve () {
    local directory=$1
    local orginalFileName=$2
    local copyFileName="${orginalFileName}${BACKUP_SUFFIX}"
    
    if [[ ! -f $directory/$orginalFileName ]]; then
        return 0
    fi
    
    local resolved
    resolve_placeholders "$directory/$orginalFileName" resolved
    if [[ -z "$resolved" ]];
    then
        exit 1
    else
        mv "$directory/$orginalFileName" "$directory/$copyFileName"
    fi
    
    echo "$resolved" > "$directory/$orginalFileName"
}

# Deletes a file and replaces it with its backup
# Does nothing if file does not exist.
# param1: path to directory that contains the file to restore
# param2: name of the file to restore
restore_backup () {
    local directory=$1
    local orginalFileName=$2
    local copyFileName="${orginalFileName}${BACKUP_SUFFIX}"

    if [[ -f "$directory/$copyFileName" ]]; then
        displayIfNotQuiet "\nRestoring $directory/$copyFileName"
    fi
    
    if [[ ! -f $directory/$copyFileName ]]; then
        return 0
    fi
    
    rm "$directory/$orginalFileName"
    mv "$directory/$copyFileName" "$directory/$orginalFileName"
}

# Deletes resolved files and replaces then with their original backups.
# param1: optional - the directory to look for templates. Defaults to the application
#         root directory
restore_template_files () {
    local templateRootDir=$1
    local templatesArray=($(get_template_files "$templateRootDir"))

    if [[ -z "$templateRootDir" ]]; then
        templateRootDir="$projectDir"
    fi

    displayIfNotQuiet "\nRestoring $templateRootDir templates from backup"

    local i
    for i in ${!templatesArray[@]}; do
        local fileName=${templatesArray[$i]}
        fileName=${fileName%"$BACKUP_SUFFIX"} # remove .bak suffix

        if [[ "$fileName" == ./* ]]; then
            # Remove leading ./ from file name
            fileName="$(echo -e "$fileName" | sed -e 's,^\./,,')"
        fi
        
        restore_backup "$templateRootDir" "$fileName"
    done

    displayIfNotQuiet "\nTemplate restoration from backup is complete"
}

# Execute arbitrary commands that can utilize application environment variables.
# Note - this function does not perform any template file resolution.
# param1: the command to execute (e.g. "echo hello")
# param2: Optional. Set to a value of "validateAwsAccount" to enable
exec_no_template_command_for_env () {
    local myCommand="$1"

    if [[ "$2" == "validateAwsAccount" ]]; then
        set_aws_cli_profile
        validate_aws_cli_account || return 1
    fi

    if [[ -z "$myCommand" ]]; then
        displayIssue "exec_no_template_command_for_env - command input parameter is required." "error"
        exit 1
    fi
    
    display "\n${CYAN}Executing \"$myCommand\"${NC}"
    
    eval "$myCommand"
    local commandExitCode=$?

    display "\n${CYAN}Finished executing \"$myCommand\"${NC}"
    
    return "$commandExitCode"
}

# Resolves environment variable placeholders in template files in 
# the requested directory (after creating a backup copy of each template 
# file). Next, executes the supplied command from that directory
# and then restores the template files to their original state.
# param1: the path to the directory where the template files live
# param2: the command to execute against the directory (e.g. "cat myfile.txt")
# param3: OPTIONAL - skip template resolution. Set to true if you do not want to resolve placeholders in
#         template files. Defaults to "n"
exec_command_for_env () {
    local myTemplateDir="$1"
    local myCommand="$2"

    local skipTemplateResolution="$3"
    : ${skipTemplateResolution:="n"} # nosemgrep # set to default skip template resolution value if a value was not passed as the third argument

    if [[ -z "$myTemplateDir" ]]; then
        displayIssue "exec_command_for_env - template directory input parameter is required." "error"
        exit 1
    elif [[ ! -d "$myTemplateDir" ]]; then
        displayIssue "exec_command_for_env - template directory \"$myTemplateDir\" does not exist." "error"
        exit 1
    elif [[ -z "$myCommand" ]]; then
        displayIssue "exec_command_for_env - command input parameter is required." "error"
        exit 1
    fi
    
    display "\n${CYAN}Executing \"$myCommand\" on $myTemplateDir${NC}"
    
    if [[ "$skipTemplateResolution" != "y" ]]; then
        resolve_template_files "backup" "$myTemplateDir"
    fi
    
    cd "$myTemplateDir"
    eval "$myCommand"
    local commandExitCode=$?
    cd - &> /dev/null # Switch back to whatever the working directory was before

    if [[ "$skipTemplateResolution" != "y" ]]; then
        restore_template_files "$myTemplateDir"
    fi

    display "\n${CYAN}Finished executing \"$myCommand\" on $myTemplateDir${NC}"
    
    return "$commandExitCode"
}

# Determine if the terraform.tfstate file refers to the current environment. If not, try to swap it out or allow terraform to create a new one.
# param1: the path of the terraform module being validated.
validate_tf_state_for_env () {
    local rootModuleDir="$1"

    if [[ -z "$rootModuleDir" ]]; then
        displayIssue "validate_tf_state_for_env - terraform module directory input parameter is required." "error"
        exit 1
    fi

    if [[ "$projectToggleTerraformStateFiles" == "n" ]]; then
        log "\nThe Terraform state file validation feature is disabled as per constants.sh\n"
        return 0
    fi

    log "\nValidating Terraform state files"

    if [[ ! -f "$rootModuleDir/.terraform/terraform.tfstate" ]]; then
        log "  Short-circuiting validation since $rootModuleDir/.terraform/terraform.tfstate was not found.\n"
        return 0
    fi

    local remoteStateFile="$(jq -r .backend.config.key "$rootModuleDir/.terraform/terraform.tfstate")"
    local tfStateEnv="${remoteStateFile%%/*}" # The remote state file starts with the environment name (e.g. dev/my-module/terraform.tfstate)

    if [[ "$tfStateEnv" == "$ENV_NAME" ]]; then
        log "  validation success: tfstate file already matched the current environment: $ENV_NAME"
        return 0
    fi

    log "  Terraform state file environment ${tfStateEnv} did NOT match current environment ${ENV_NAME}"
    log "  Moving terraform.tfstate to coin-${tfStateEnv}-env-tf-state"
    mv -f "$rootModuleDir/.terraform/terraform.tfstate" "$rootModuleDir/.terraform/coin-${tfStateEnv}-env-tf-state"

    if [[ -f "$rootModuleDir/.terraform/coin-${ENV_NAME}-env-tf-state" ]]; then
        log "  Backup of current environment state file found (coin-${ENV_NAME}-env-tf-state). Renaming it to terraform.tfstate"
        mv "$rootModuleDir/.terraform/coin-${ENV_NAME}-env-tf-state" "$rootModuleDir/.terraform/terraform.tfstate"
    else
        log "  No backup of current environment state file found. A new terraform.tfstate file must be created using 'terraform init'"
    fi
}

# Validates that you are logged in to correct AWS account, then resolves environment variable placeholders in files in the requested 
# root Terraform module directory and then executes the supplied Terraform command
# param1: the name of the module to run. Should be under iac/roots.
# param2: the Terraform command to execute against the module (e.g. "terraform init")
exec_tf_command_for_env () {
    if ! command -v terraform --version &> /dev/null
    then
        displayIssue "terraform could not be found. Please install terraform, then run this script again." "error"
        exit 1
    fi

    local myTemplateDirSimpleName="$1"
    local myCommand="$2"

    if [[ -z "$myTemplateDirSimpleName" ]]; then
        displayIssue "exec_tf_command_for_env - terraform module directory input parameter is required." "error"
        exit 1
    elif [[ -z "$myCommand" ]]; then
        displayIssue "exec_tf_command_for_env - command input parameter is required." "error"
        exit 1
    fi

    # Convert simple module name to a path under iac/roots/
    local rootModuleDir=$projectIacRootModuleDir/$myTemplateDirSimpleName

    if [[ ! -d "$rootModuleDir" ]]; then
        displayIssue "exec_tf_command_for_env - template directory \"$rootModuleDir\" does not exist." "error"
        exit 1
    fi

    validate_tf_state_for_env "$rootModuleDir"

    log "Terraform command is: $myCommand"

    # Check to see if "terraform init" needs to be run and check if it is already in the supplied command
    if [[ ! -f "$rootModuleDir/.terraform/terraform.tfstate" ]]; then

        if [[ "$myCommand" =~ "terraform init" ]]; then
            log "$rootModuleDir/.terraform/terraform.tfstate file not found. Not adding \"terraform init\" to your command since the command already has it." 
        else
            log "$rootModuleDir/.terraform/terraform.tfstate file not found. Adding \"terraform init\" to your command."
            myCommand="terraform init; $myCommand"
        fi
    else
        log "Found existing Terraform state file: $rootModuleDir/.terraform/terraform.tfstate"
    fi

    set_aws_cli_profile
    validate_aws_cli_account || return 1

    exec_command_for_env "$rootModuleDir" "$myCommand"

    # Copy terraform state file so that it can be switched out if the current environment is changed
    cp "$rootModuleDir/.terraform/terraform.tfstate" "$rootModuleDir/.terraform/coin-${ENV_NAME}-env-tf-state"
}

# Resolves environment variable placeholders in files in the requested 
# root Terraform module directory and then executes Terraform for the 
# current Terraform mode (plan, appy, destroy)
# param1: the name of the module to run. Should be under iac/roots.
exec_tf_for_env () {
    if ! command -v terraform --version &> /dev/null
    then
        displayIssue "terraform could not be found. Please install terraform, then run this script again." "error"
        exit 1
    fi

    if [[ -z "$TF_MODE" ]]; then
        TF_MODE="apply"
    fi
    
    local rootModuleName="$1"
    [ -z "$rootModuleName" ] && displayIssue "root module name is required as the first argument to the exec_tf_for_env function" "error" \
    && exit 1
    
    local rootModuleDir=$projectIacRootModuleDir/$rootModuleName

    if [[ ! -d "$rootModuleDir" ]]; then
        displayIssue "exec_tf_for_env - template directory \"$rootModuleDir\" does not exist." "error"
        exit 1
    fi

    validate_tf_state_for_env "$rootModuleDir"

    # Note, the ${*:2} below allows you to optionally supply arguments
    # to Terraform from the calling script
    local tfOptions=${*:2}
    local tfCommand=$(echo "terraform $TF_MODE ${tfOptions}" | xargs) # trim whitespace

    display "\n${CYAN}Executing \"$tfCommand\" on $rootModuleDir${NC}"
    
    [ ! -d "$rootModuleDir" ] && displayIssue "Directory $rootModuleDir DOES NOT EXIST when executing the exec_tf_for_env function" "error" && exit 1
    
    set_aws_cli_profile
    validate_aws_cli_account || return 1

    if [[ ! "$TF_MODE" =~ ^(plan|apply|destroy|validate|console)$ ]]; then
        displayIssue "invalid TF_MODE value \"$TF_MODE\". Must be one of: plan|apply|destroy|validate|console" "error"
        exit 1
    fi

    resolve_template_files "backup" "$rootModuleDir"

    if [ $? -eq 0 ]; then
        cd "$rootModuleDir"
        display "Terraform backend for root module $rootModuleName:"
        display "$resolvedTf"
        terraform init
        
        display "TF_MODE is $TF_MODE"
        
        if [[ "$TF_MODE" == "apply" ]] || [[ "$TF_MODE" == "destroy" ]]; then
            terraform $TF_MODE -auto-approve $tfOptions # nosemgrep
        else 
            terraform $TF_MODE $tfOptions # nosemgrep
        fi

    fi

    local iacExitCode=$?

    restore_template_files "$rootModuleDir"

    display "\n${CYAN}Finished executing \"$tfCommand\" on $rootModuleDir${NC}"
    
    # Copy terraform state file so that it can be switched out if the current environment is changed
    cp "$rootModuleDir/.terraform/terraform.tfstate" "$rootModuleDir/.terraform/coin-${ENV_NAME}-env-tf-state"

    return "$iacExitCode"
}

# Gets the names of Terraform modules and prints them in a pipe-delimited string
# Example of how to convert the output of this function to an array:
# local tfModuleNames="$(get_terraform_module_names)"
# local moduleNames
# IFS='|' read -r -a moduleNames <<< "$tfModuleNames"
# for moduleName in "${moduleNames[@]}"; do
#     echo "$moduleName"
# done
get_terraform_module_names () {
    cd "${projectDir}${projectIacRootModulePath}" > /dev/null

    # Find directories under IaC root that contain a backend.tf file

    local fullString=""
    while read fname; do
        local modName="${fname/\/backend.tf/}" # remove trailing /backend.tf
        local escapedWhiteSpaceModName=$(echo "$modName" | sed 's/ /\\ /g') # escape whitespace in file path (if any)
        fullString="${fullString}|${escapedWhiteSpaceModName}" # append string with module name
    done < <(find . -name "backend.tf" | sed -e 's,^\./,,')

    cd - > /dev/null

    # Trim leading white space
    local trimmed="$(echo "$fullString" | sed -e 's/^[|]*//')"
    echo "$trimmed"
}

# Run checkov against a Terraform module
# param1: the name of the module to run. Should be under iac/roots.
exec_checkov () {
    local myTemplateDirSimpleName="$1"

    if [[ -z "$myTemplateDirSimpleName" ]]; then
        displayIssue "checkov - terraform module directory input parameter is required." "error"
        exit 1
    fi

    log "Beginning checkov scan for the \"$myTemplateDirSimpleName\" module..."
    validate_checkov

    local fullModDir="${projectDir}${projectIacRootModulePath}/${myTemplateDirSimpleName}"

    log "Generated files will be placed under $fullModDir"

    log "Generating tf.plan"
    exec_tf_command_for_env "$myTemplateDirSimpleName" "terraform plan -out \"$fullModDir/tf.plan\""

    log "Converting tf.plan to JSON"
    exec_tf_command_for_env "$myTemplateDirSimpleName" "terraform show -json \"$fullModDir/tf.plan\" > \"$fullModDir/tf.json\""

    local stamp="$(date +%Y-%m-%dT%H-%M-%S)"
    local checkovFile="$fullModDir/checkov-$stamp.txt"
    
    log "Executing checkov like so:"
    log "checkov -f \"$fullModDir/tf.json\" > \"$checkovFile\""

    local checkovOutput="$(checkov -f "$fullModDir/tf.json" > "$checkovFile")"

    log "Deleting tf.plan and tf.json files"
    rm -f "$fullModDir/tf.plan"
    rm -f "$fullModDir/tf.json"

    displayInColor "\ncheckov scan results written to $checkovFile\n" "$GREEN"
}

# Run checkov scan on all Terraform modules
exec_checkov_all () {

    local tfModuleNames="$(get_terraform_module_names)"

    local moduleNames
    IFS='|' read -r -a moduleNames <<< "$tfModuleNames"

    for moduleName in "${moduleNames[@]}"; do
        exec_checkov "$moduleName"
    done
}

# Prints the name of all of the root Terraform modules in your project
print_root_terraform_modules () {

    local tfModuleNames="$(get_terraform_module_names)"

    local moduleNames
    IFS='|' read -r -a moduleNames <<< "$tfModuleNames"

    display "Here are this project's root Terraform modules:"

    for moduleName in "${moduleNames[@]}"; do
        display "    $moduleName"
    done
}

# Run yarn install or npm install
exec_package_manager_install () {
    display "\nUtilizing \"$coinPackageManager\" as the package manager as per \"coinPackageManager\" setting in constants.sh"
    display "\nExecuting \"$coinPackageManager install\""
    if [[ "$coinPackageManager" == "npm" ]]; then
        npm install
    else
        yarn install
    fi
}

# Sets global projectCdk variable
# param1: the IaC root module directory
set_project_cdk () {
    local lclRootModDir="$1"

    [ -z "$lclRootModDir" ] && displayIssue "IaC root module directory is required as the first argument to the set_project_cdk function" "error" \
    && exit 1

    if [[ "$lclRootModDir" == "global" ]]; then
        display "Using global CDK installation\n"
        projectCdk="cdk"
        return 0
    fi

    local runInstall="n"
    if [[ ! -d "$lclRootModDir/node_modules" ]]; then
        runInstall="y"
    elif [[ ! -f "$lclRootModDir/node_modules/aws-cdk/bin/cdk" ]] && [[ ! -f "$lclRootModDir/node_modules/.bin/cdk" ]]; then
        runInstall="y"
    fi

    if [[ "$runInstall" == "y" ]]; then
        cd "$lclRootModDir"
        display "\nRunning package manager install to try to use application's CDK version if configured.\n"
        exec_package_manager_install
        cd -
    fi
    
    projectCdk="$lclRootModDir/node_modules/aws-cdk/bin/cdk"
    display "\nLooking for CDK binary at: $projectCdk"
    
    if [[ -f "$projectCdk" ]]; then
        display "Found CDK binary at: $projectCdk\n"
    else
        display "No CDK binary found at: $projectCdk"

        # For yarn workspace support
        projectCdk="$lclRootModDir/node_modules/.bin/cdk"
        display "\nLooking for CDK binary at: $projectCdk"

        if [[ -f "$projectCdk" ]]; then
            display "Found CDK binary at: $projectCdk\n"
        else

            if ! command -v cdk --version &> /dev/null
            then
                displayIssue "cdk could not be found. Please install cdk, then run this script again." "error"
                log "Exiting from set_project_cdk since CDK binary is not installed"
                exit 1
            else
                display "Using global CDK installation\n"
                projectCdk="cdk"
            fi
        fi
    fi
}

# Validates that you are logged in to correct AWS account, then sets environment variables, 
# then resolves environment variable placeholders in files in the requested 
# root CDK module directory (optional, based on project settings) and then executes the supplied CDK command
# Note - this function will set the path to the CDK executable based on project settings
# param1: the name of the module to run. Should be under iac/roots.
# param2: the CDK command to execute against the module (e.g. "cdk synth STACK_ID --exclusively")
exec_cdk_command_for_env () {

    local myTemplateDirSimpleName="$1"
    local myCommand="$2"

    if [[ -z "$myTemplateDirSimpleName" ]]; then
        displayIssue "exec_cdk_command_for_env - CDK module directory input parameter is required." "error"
        exit 1
    elif [[ -z "$myCommand" ]]; then
        displayIssue "exec_cdk_command_for_env - command input parameter is required." "error"
        exit 1
    fi

    # Convert simple module name to a path under iac/roots/
    local rootModuleDir=$projectIacRootModuleDir/$myTemplateDirSimpleName

    if [[ ! -d "$rootModuleDir" ]]; then
        displayIssue "exec_cdk_command_for_env - template directory \"$rootModuleDir\" does not exist." "error"
        exit 1
    fi

    set_project_cdk "$rootModuleDir"

    set_aws_cli_profile
    validate_aws_cli_account || return 1

    # Since we can use environment variables from CDK code, we may not need to resolve template file placeholders
    skipTemplateResolution="y"
    if [[ "$projectCdkResolveTemplates" == "y" ]]; then
        skipTemplateResolution="n"
    fi

    # pick the right location for CDK by replacing "cdk " in the command string with the path to CDK
    myCommand="${myCommand/cdk /$projectCdk }"

    exec_command_for_env "$rootModuleDir" "$myCommand" "$skipTemplateResolution"
}

# Resolves environment variable placeholders in the requested root CDK
# module files then executes CDK deployment
# Note - set the environment variable AWS_DEFAULT_REGION to configure the region
#      - see COIN command line overrides feature introduced 6/17/24
#        Override variable should be COIN_OVERRIDE_AWS_DEFAULT_REGION
# param1: the name of the root module
# param2: optional. Additional command line customizations such as stack names or context
exec_cdk_for_env () {

    if [[ -z "$CDK_MODE" ]]; then
        CDK_MODE="deploy"
    fi
    
    local rootModuleName="$1"
    [ -z "$rootModuleName" ] && displayIssue "root module name is required as the first argument to the exec_cdk_for_env function" "error" \
    && exit 1
    
    local rootModuleDir="$projectIacRootModuleDir/$rootModuleName"

    if [[ "$projectCdkClearCache" == "y" ]] && [[ "$CDK_MODE" == "deploy" ]]; then
        display "Clearing CDK context before running deploy. See 'projectCdkClearCache' in constants.sh to disable."
        rm "$rootModuleDir/cdk.context.json" 2> /dev/null || true
        # cdk context --clear
    fi
    
    display "\n${CYAN}Executing \"cdk $CDK_MODE\" on $rootModuleDir${NC}"
    local cdkArgs=""
    if [[ ! -z "$2" ]]; then
        display "CDK args: $2"
        cdkArgs=" $2"
    else
        display "using default CDK args: --all"
        cdkArgs=" --all"
    fi

    [ ! -d "$rootModuleDir" ] && displayIssue "Directory $rootModuleDir DOES NOT EXIST when executing the exec_cdk_for_env function" "error" && exit 1

    cd "$rootModuleDir"

    set_aws_cli_profile
    validate_aws_cli_account || return 1

    if [[ ! "$CDK_MODE" =~ ^(deploy|destroy|diff|cdk-nag|synth)$ ]]; then
        displayIssue "invalid CDK_MODE value \"$CDK_MODE\". Must be \"deploy\" or \"destroy\" or \"diff\" or \"synth\" or \"cdk-nag\"" "error"
        exit 1
    fi

    if [[ "projectCdkResolveTemplates" == "y" ]]; then
        resolve_template_files "backup" "$rootModuleDir"
    else
        log "\nCOIN template resolution is disabled as per projectCdkResolveTemplates setting from constants.sh"
    fi
    
    local cdkDiff
    set_project_cdk "$rootModuleDir"
    
    if [ $? -eq 0 ]; then
        
        if [ "$CDK_MODE" == "destroy" ]; then
            display "\nExecuting \"$projectCdk destroy -f${cdkArgs}\""
            $projectCdk destroy -f${cdkArgs} 2>&1 | tee -a "$COIN_LOG_FILE_PATH" # nosemgrep
        else
            exec_package_manager_install
            
            if [[ "$CDK_MODE" == "cdk-nag" ]]; then
                display "\nExecuting \"$projectCdk synth${cdkArgs}\" for cdk-nag"
                # Ignore stdout of synth, write cdk-nag errors from stderr to console and log file
                $projectCdk synth${cdkArgs} > /dev/null 2> >(tee -a "$COIN_LOG_FILE_PATH" >&2) # nosemgrep
            elif [[ "$CDK_MODE" == "synth" ]]; then
                display "\nExecuting \"$projectCdk synth${cdkArgs}\""
                $projectCdk synth${cdkArgs} 2>&1 | tee -a "$COIN_LOG_FILE_PATH" # nosemgrep
            elif [[ "$CDK_MODE" == "diff" ]]; then
                display "\nExecuting \"$projectCdk diff${cdkArgs}\""
                $projectCdk diff${cdkArgs} 2>&1 | tee -a "$COIN_LOG_FILE_PATH" # nosemgrep
            elif [[ "$COIN_CDK_SKIP_DIFF" == "y" ]]; then
                display "\nExecuting \"$projectCdk deploy${cdkArgs} --require-approval never\""
                $projectCdk deploy${cdkArgs} --require-approval never 2>&1 | tee -a "$COIN_LOG_FILE_PATH" # nosemgrep
            else
                display "\nExecuting \"$projectCdk diff${cdkArgs} --fail\""
                $projectCdk diff${cdkArgs} --fail && cdkDiff="n" || cdkDiff="y" # nosemgrep

                if [[ "$cdkDiff" == "y" ]]; then
                    display "\nExecuting \"$projectCdk deploy${cdkArgs} --require-approval never\""
                    $projectCdk deploy${cdkArgs} --require-approval never 2>&1 | tee -a "$COIN_LOG_FILE_PATH" # nosemgrep
                fi
            fi

        fi

    fi

    local iacExitCode=${PIPESTATUS[0]}
    if [[ "$cdkDiff" == "n" ]]; then
        iacExitCode=0
    fi

    if [[ "projectCdkResolveTemplates" == "y" ]]; then
        restore_template_files "$rootModuleDir"
    fi

    display "\n${CYAN}Finished executing \"cdk $CDK_MODE\" on $rootModuleDir${NC}"
    display "\nCommand Response Code: $iacExitCode"

    return "$iacExitCode"
}

# Resolves environment variable placeholders in the requested root CloudFormation
# module files then executes "cloudformation deploy"
# param1: root module name
exec_cf_for_env () {
    
    local rootModuleName=$1
    [ -z "$rootModuleName" ] && displayIssue "root module name is required as the first argument to the exec_cf_for_env function" "error" \
    && exit 1
    
    local rootModuleDir=$projectIacRootModuleDir/$rootModuleName

    display "\n${CYAN}Executing CloudFormation command(s) on $rootModuleDir${NC}"

    [ ! -d "$rootModuleDir" ] && displayIssue "Directory $rootModuleDir DOES NOT EXIST" "error" && exit 1

    set_aws_cli_profile
    validate_aws_cli_account || return 1

    resolve_template_files "backup" "$rootModuleDir"

    if [ $? -eq 0 ]; then
        cd "$rootModuleDir"

        if [[ ! -f "cf.yml" ]]; then
            displayIssue "Failed to find CloudFormation template file \"cf.yml\". Please check the template file name for the $rootModuleName module." "error"
        fi

        display "\nExecuting \"cloudformation deploy\""

        if [[ -f "parameters.json" ]]; then
            aws cloudformation deploy \
            --template-file cf.yml \
            --parameter-overrides file://parameters.json \
            --stack-name "$APP_NAME-$ENV_NAME-$rootModuleName" \
            --capabilities CAPABILITY_NAMED_IAM \
            --no-fail-on-empty-changeset \
            --tags App="$APP_NAME" Env="$ENV_NAME"
        else
            aws cloudformation deploy \
            --template-file cf.yml \
            --stack-name "$APP_NAME-$ENV_NAME-$rootModuleName" \
            --capabilities CAPABILITY_NAMED_IAM \
            --no-fail-on-empty-changeset \
            --tags App="$APP_NAME" Env="$ENV_NAME"
        fi
    fi

    local iacExitCode=$?

    restore_template_files "$rootModuleDir"

    display "\n${CYAN}Finished executing CloudFormation command(s) on $rootModuleDir${NC}"

    return "$iacExitCode"
}

# Performs cloudformation destroy on the supplied root module
# param1: root module name
destroy_root_cf_stack_by_name () {
    local rootModuleName=$1
    [ -z "$rootModuleName" ] && displayIssue "root module name is required as the first argument to the destroy_root_cf_stack_by_name function" "error" \
    && exit 1
    
    local rootModuleDir=$projectIacRootModuleDir/$rootModuleName

    [ ! -d "$rootModuleDir" ] && displayIssue "Directory $rootModuleDir DOES NOT EXIST" "error" && exit 1

    set_aws_cli_profile
    validate_aws_cli_account || return 1

    cd "$rootModuleDir"

    display "\nExecuting \"cloudformation delete-stack --stack-name $APP_NAME-$ENV_NAME-$rootModuleName\""

    aws cloudformation delete-stack \
	--stack-name "$APP_NAME-$ENV_NAME-$rootModuleName"

    aws cloudformation wait stack-delete-complete --stack-name "$APP_NAME-$ENV_NAME-$rootModuleName"
}

# Resolves environment variable placeholders in the CICD IAM Role
# CloudFormation template then executes "cloudformation deploy"
# param1: optional the AWS region to deploy to. Defaults to $AWS_DEFAULT_REGION
deploy_cicd_iam_role_cf_stack () {
    local cicdIamRoleDir=$projectCicdDir/iam-role

    [ ! -d "$cicdIamRoleDir" ] && displayIssue "Directory $cicdIamRoleDir DOES NOT EXIST" "error" && exit 1

    display "\nDeploying CICD IAM role CloudFormation stack..."

    set_aws_cli_profile
    validate_aws_cli_account

    resolve_template_files "backup" "$cicdIamRoleDir"

    if [ $? -eq 0 ]; then
        cd "$cicdIamRoleDir"

        local region=$1
        : ${region:=$AWS_DEFAULT_REGION} # nosemgrep # set to default region if region was not passed as the first argument

        display "\nExecuting \"cloudformation deploy\" for region: \"$region\""

        if [[ -f "parameters.json" ]]; then
            aws cloudformation deploy \
            --template-file iam-role.yml \
            --parameter-overrides file://parameters.json \
            --stack-name "$APP_NAME-$ENV_NAME-cicd-role" \
            --capabilities CAPABILITY_NAMED_IAM \
            --no-fail-on-empty-changeset \
            --tags App="$APP_NAME" Env="$ENV_NAME" \
            --region "$region"
        else
            aws cloudformation deploy \
            --template-file iam-role.yml \
            --stack-name "$APP_NAME-$ENV_NAME-cicd-role" \
            --capabilities CAPABILITY_NAMED_IAM \
            --no-fail-on-empty-changeset \
            --tags App="$APP_NAME" Env="$ENV_NAME" \
            --region "$region"
        fi

        if [ $? -eq 0 ]; then
            local cmdResult="SUCCESS"
        else
            local cmdResult="${RED}FAILURE${NC}"
        fi
    else
        local cmdResult="${RED}FAILURE${NC}"
    fi

    restore_template_files "$cicdIamRoleDir"

    display "\nFinished deploying CICD IAM role CloudFormation stack"
    display "Result: $cmdResult"
}

# Executes cdk bootstrap for the current environment's AWS
# account and region.
# param1: optional. the region to deploy the CDK v2 bootstrap stack to
#         This overrides the current environment's region setting
deploy_cdk_bootstrap_cf_stack () {
    local cdkRegion=$1
    if [[ -z "$cdkRegion" ]]; then
        cdkRegion="$AWS_DEFAULT_REGION"
    fi

    display "\n${CYAN}Deploying CDK v2 bootstrap CloudFormation stack to account $AWS_ACCOUNT_ID region $cdkRegion...${NC}"

    set_aws_cli_profile
    validate_aws_cli_account || return 1

    if [ $? -eq 0 ]; then

        display "\nExecuting \"cdk bootstrap\"\n"

        # Look for an IaC module that declares a dependency on aws-cdk-lib
        local iacModuleWithCdkDependency
        while read file
        do
            local packageJson="$(grep aws-cdk-lib "$file")"
            if [[ ! -z "$packageJson" ]]; then
                iacModuleWithCdkDependency="${file/"/package.json"/""}"
                break
            fi
        done <<< "$(find "$projectIacRootModuleDir" -maxdepth 2 -name "package.json")"

        if [[ -z "$iacModuleWithCdkDependency" ]]; then
            iacModuleWithCdkDependency="global"
        fi
        
        set_project_cdk "$iacModuleWithCdkDependency"
        $projectCdk bootstrap "aws://$AWS_ACCOUNT_ID/$cdkRegion" # nosemgrep

        if [ $? -eq 0 ]; then
            local cmdResult="SUCCESS"
        else
            local cmdResult="${RED}FAILURE${NC}"
        fi

    else
        local cmdResult="${RED}FAILURE${NC}"
    fi

    display "\n${CYAN}Finished deploying CDK v2 bootstrap CloudFormation stack to account $AWS_ACCOUNT_ID region $cdkRegion${NC}"
    display "Result: $cmdResult"
}

# Runs cloudformation delete-stack --stack-name CDKToolkit
# param1: optional. the region to delete the CDK v2 bootstrap stack from
#         This overrides the current environment's region setting
destroy_cdk_bootstrap_cf_stack () {
    local cdkRegion=$1
    if [[ -z "$cdkRegion" ]]; then
        cdkRegion="$AWS_DEFAULT_REGION"
    fi

    set_aws_cli_profile
    validate_aws_cli_account || return 1

    display "\nExecuting \"cloudformation delete-stack --stack-name CDKToolkit --region $cdkRegion\""

    aws cloudformation delete-stack --stack-name CDKToolkit --region "$cdkRegion"

    aws cloudformation wait stack-delete-complete --stack-name CDKToolkit --region "$cdkRegion"
}

# Resolves environment variable placeholders in the Terraform backend
# CloudFormation template then executes "cloudformation deploy"
# param1: optional the AWS region to deploy to. Defaults to $AWS_DEFAULT_REGION
# param2: optional the parameter values file name. Defaults to "parameters.json"
deploy_tf_backend_cf_stack () {
    local bootstrapDir=$projectIacDir/bootstrap

    [ ! -d "$bootstrapDir" ] && displayIssue "Directory $bootstrapDir DOES NOT EXIST" "error" && exit 1

    display "${CYAN}Deploying Terraform back end CloudFormation stack...${NC}"

    set_aws_cli_profile
    validate_aws_cli_account || return 1

    resolve_template_files "backup" "$bootstrapDir"

    if [ $? -eq 0 ]; then
        cd "$bootstrapDir"

        local region=$1
        : ${region:=$AWS_DEFAULT_REGION} # nosemgrep # set to default region if region was not passed as the first argument

        local paramValuesFileName=$2
        : ${paramValuesFileName:="parameters.json"} # nosemgrep  # set to default if paramValuesFileName was not passed as the second argument

        display "\nExecuting \"cloudformation deploy\" for region: \"$region\""

        if [[ -f "$paramValuesFileName" ]]; then
            display "Using parameter values from $paramValuesFileName"
            aws cloudformation deploy \
            --template-file tf-backend-cf-stack.yml \
            --parameter-overrides "file://${paramValuesFileName}" \
            --stack-name "$TF_S3_BACKEND_NAME" \
            --capabilities CAPABILITY_NAMED_IAM \
            --no-fail-on-empty-changeset \
            --tags App="$APP_NAME" Env="$ENV_NAME" \
            --region "$region"
        else
            aws cloudformation deploy \
            --template-file tf-backend-cf-stack.yml \
            --stack-name "$TF_S3_BACKEND_NAME" \
            --capabilities CAPABILITY_NAMED_IAM \
            --no-fail-on-empty-changeset \
            --tags App="$APP_NAME" Env="$ENV_NAME" \
            --region "$region"
        fi

        if [ $? -eq 0 ]; then
            local cmdResult="SUCCESS"
        else
            local cmdResult="${RED}FAILURE${NC}"
        fi
    else 
        local cmdResult="${RED}FAILURE${NC}"
    fi

    restore_template_files "$bootstrapDir"

    display "\n${CYAN}Finished deploying Terraform back end CloudFormation stack${NC}"
    display "Result: $cmdResult"
}

# Resolves environment variable placeholders in the Terraform backend
# CloudFormation template then executes "cloudformation delete-stack"
# param1: optional the AWS region to delete from. Defaults to $AWS_DEFAULT_REGION
destroy_tf_backend_cf_stack () {
    local bootstrapDir=$projectIacDir/bootstrap

    [ ! -d "$bootstrapDir" ] && displayIssue "Directory $bootstrapDir DOES NOT EXIST" "error" && exit 1

    set_aws_cli_profile
    validate_aws_cli_account || return 1

    local region=$1
    : ${region:=$AWS_DEFAULT_REGION} # nosemgrep # set to default region if region was not passed as the first argument

    cd "$bootstrapDir"

    display "\nExecuting \"cloudformation delete-stack --stack-name $TF_S3_BACKEND_NAME\" in region: \"$region\""

    aws cloudformation delete-stack \
	--stack-name "$TF_S3_BACKEND_NAME" \
    --region "$region"

    aws cloudformation wait stack-delete-complete --stack-name "$TF_S3_BACKEND_NAME"

    display "\nDone deleting stack \"$TF_S3_BACKEND_NAME\" in region: \"$region\""
}

# Examines remote origin Git setting to set a Bash nameref variable with the Git repo provider
# This function should only be called when the current working directory is the project's
# home directory.
# param1: the Bash nameref variable to set with the Git repo provider
set_git_repo_type_from_remote_origin () {
    local -n repoProv=$1
    local gitRemote=$(git remote get-url --push origin 2> /dev/null)

    if [[ -z "$gitRemote" ]]; then
        :
    elif [[ $gitRemote == *"gitlab"* ]]; then
        repoProv="gitlab"
        set_gitlab_env_vars_from_remote_origin
    fi
}

# Examines remote origin Git setting to pull environment variable settings
set_git_env_vars_from_remote_origin () {

    if [[ ! -z "$CREATE_APP" ]]; then return 0; fi
    if [[ ! -d "$projectDir/.git" ]]; then return 0; fi

    local gitRemote=$(git remote get-url --push origin 2> /dev/null)
    local doneProcessing="n"

    if [[ -z "$gitRemote" ]]; then
        doneProcessing="y"
    elif [[ $gitRemote == *"gitlab"* ]]; then
        set_gitlab_env_vars_from_remote_origin
        doneProcessing="y"
    fi

    if [[ "$doneProcessing" == "n" ]]; then
        local gitServiceProvider=$(custom_git_provider_resolver "$gitRemote")
        log "custom_git_provider_resolver returned \"$gitServiceProvider\""

        if [[ "$gitServiceProvider" == "gitlab" ]]; then
            set_gitlab_env_vars_from_remote_origin
        elif [[ "$defaultGitProvider" == "gitlab" ]]; then
            set_gitlab_env_vars_from_remote_origin
        else
            displayIssue "Could not detect how to parse git remote to set environment variables" "warn"
        fi

    fi
}

# Retrieves AWS SSM Parameter Store environment names as a space-delimited string
get_ssm_environment_names () {
    get_env_var_value "AWS_DEFAULT_REGION" 1> /dev/null || exit 1
    get_env_var_value "APP_NAME" 1> /dev/null || exit 1

    local ssmEnvJson=$(aws ssm get-parameters-by-path \
    --region "$AWS_DEFAULT_REGION" \
    --max-items 300 \
    --recursive \
    --path "/$APP_NAME/remoteVars/" \
    --query "Parameters[].Name")

    ssmEnvJson=$(echo "$ssmEnvJson" \
    | jq -r "map( (ltrimstr(\"/$APP_NAME/remoteVars/\") | sub(\"/.*\"; \"\") ) ) | unique[]")

    echo "$ssmEnvJson"
}

# Detects which local environments exist by checking for environment-<env>.json files 
# and returns the results as a space-delimited string
get_local_environment_names () {
    local suffix=".json"
    # note - do not surround the echoed string below with quotes or that will break current functionality for selecting from existing environments
    echo $(find "$projectEnvDir" -type f -name ".environment-*" -not -name "*sensitive*" -not -name "*lookup-cache*" | sed -e "s:^$projectEnvDir/.environment-::" -e "s/$suffix$//") # nosemgrep
}

# Presents user with a choice of local environments and sets the 
# chosen environment to a Bash nameref variable
# param1: the name of the variable to set using the Bash nameref feature
# param2: the description of the choice action to show the user
choose_local_environment () {
    local -n envChoice=$1
    local selectDescription=$2
    local localEnvs="$(get_local_environment_names | sed -e 's/ /|/g')"

    if [[ -z "$localEnvs" ]]; then
        displayIssue "You have no local environments." "error"
        exit 1
    fi

    echo "$selectDescription"
    envChoice=$(select_with_default "$localEnvs" "$localEnvs" "")
}

# Searches your local environment json files and gives you a choice of which to
# make your current local environment
switch_local_environment () {
    local switchTo
    choose_local_environment switchTo "Select a local environment to switch to:"
    set_current_env "$switchTo"
    display "\n${GREEN}Your local environment is now \"$switchTo\"${NC}\n"

    if [[ "${#COIN_AFTER_SWITCH_ENV_HOOKS[@]}" != "0" ]]; then
        log "\nReloading utility-functions to use new environment \"$switchTo\"\n"
        # Clear cache for old environment and re-source utility functions so that 
        # all variables reference the selected environment
        ENV_RECONCILED_JSON=""
        COIN_ENV_VAR_FILE_NAME=""
        source "$scriptDir/utility-functions.sh" "source reload_for_environment" 1> /dev/null

        log "\nExecuting COIN_AFTER_SWITCH_ENV_HOOKS for new environment \"$switchTo\"..."
        local i
        for i in "${COIN_AFTER_SWITCH_ENV_HOOKS[@]}"
        do
            log "Executing hook: $i"
            eval "$i"
        done

        log "\nFinished executing COIN_AFTER_SWITCH_ENV_HOOKS for new environment \"$switchTo\"\n"
    else
        log "\nINFO: no COIN_AFTER_SWITCH_ENV_HOOKS hooks were configured.\n"
    fi
}

# Detects which remote environment variable store to query and returns the results
# as a space-delimited string
get_remote_environment_names () {
    get_env_var_value "REMOTE_ENV_VAR_LOC" 1> /dev/null || exit 1
    
    if [[ "$REMOTE_ENV_VAR_LOC" == "ssm" ]]; then
        echo "$(get_ssm_environment_names)"
    elif [[ "$REMOTE_ENV_VAR_LOC" == "gitlab" ]]; then
        local gitEnvNames
        get_gitlab_environment_names gitEnvNames ""
        echo "$gitEnvNames"
    elif [[ "$REMOTE_ENV_VAR_LOC" == "na" ]]; then
        displayIssue "cannot get remote environment names since REMOTE_ENV_VAR_LOC is \"$REMOTE_ENV_VAR_LOC\"" "error"
    else
        displayIssue "get_remote_environment_names does not currently support REMOTE_ENV_VAR_LOC = \"$REMOTE_ENV_VAR_LOC\"" "error"
    fi
}

# Pulls application environment variables from the AWS SSM Parameter Store and
# saves them in the local .environment.json file.
pull_env_vars_from_ssm_to_local_json () {

    local ssmEnvJson=$(aws ssm get-parameters-by-path \
    --region "$AWS_DEFAULT_REGION" \
    --max-items 200 \
    --path "/$APP_NAME/remoteVars/$ENV_NAME/" \
    --with-decryption \
    --query "Parameters[].{key:Name,value:Value}")

    echo "$ssmEnvJson" | jq "map( {(.key|ltrimstr(\"/$APP_NAME/remoteVars/$ENV_NAME/\")) : .value } ) | add" > "$COIN_ENV_VAR_FILE_NAME"
}

# Sets application environment variables into AWS SSM Parameter Store
set_ssm_remote_vars_for_env () {
    display "\nPosting environment variables to AWS SSM Parameter Store"
    display "environment_scope is $ENV_NAME"

    for i in ${!ENV_KEYS[@]}; do
        local varName=${ENV_KEYS[$i]}

        if [[ "$COIN_DYNAMIC_ONLY" == "y" ]] && [[ ! -v "LOOKUPS[$varName]" ]]; then
            log "COIN_DYNAMIC_ONLY enabled, skipping $varName"
            continue
        fi

        # check that the env var value can be retrieved or exit if not
        # special syntax needed to get exit code from local variable
        local envVarValue; envVarValue="$(get_env_var_value "$varName")" || exit 1
        local paramName="/$APP_NAME/remoteVars/$ENV_NAME/$varName"
        
        display "Posting $varName with key $paramName to region $AWS_DEFAULT_REGION"
        aws ssm put-parameter \
        --region "$AWS_DEFAULT_REGION" \
        --name "$paramName" \
        --type "SecureString" \
        --value "$envVarValue" \
        --overwrite 1> /dev/null || displayIssue "could not create or update $varName with environment_scope ${ENV_NAME}" "error"

        # note - you can't use overwrite and tags together so tagging is done separately
        aws ssm add-tags-to-resource \
        --region "$AWS_DEFAULT_REGION" \
        --resource-type "Parameter" \
        --resource-id "$paramName" \
        --tags "[{\"Key\":\"App\",\"Value\":\"$APP_NAME\"},{\"Key\":\"Env\", \"Value\":\"$ENV_NAME\"}]" \
        1> /dev/null || displayIssue "could not tag ${paramName}" "error"

    done

    display "\nDone posting environment variables to AWS SSM Parameter Store\n"
}

# Deletes application environment variables from AWS SSM Parameter Store
delete_ssm_remote_vars_for_env () {
    # check that the env var value can be retrieved or exit if not
    get_env_var_value "APP_NAME" 1> /dev/null || exit 1
    get_env_var_value "ENV_NAME" 1> /dev/null || exit 1
    get_env_var_value "AWS_DEFAULT_REGION" 1> /dev/null || exit 1

    local paramPath="/$APP_NAME/remoteVars/$ENV_NAME/"
    local deleteSure

    if [[ "$HEADLESS" == "y" ]]; then
        if [[ "$deleteRemoteEnv" == "y" ]]; then
            deleteSure="y"
        else
            deleteSure="n"
            log "Skipping deleting remote vars from SSM due to deleteRemoteEnv config"
        fi
    else
        yes_or_no deleteSure "Are you sure you want to delete SSM variables with path ${paramPath} ?" "n"
    fi
    
    if [[ "$deleteSure" == "y" ]]; then
        display "\nDeleting SSM variables with path ${paramPath} from region $AWS_DEFAULT_REGION..."
        aws ssm get-parameters-by-path --path "$paramPath" --region "$AWS_DEFAULT_REGION" --recursive | \
        jq '.Parameters[].Name' | \
        xargs -I'{}' aws ssm delete-parameter --name {}
        display "Deletion complete.\n"
    fi
}

# Sends current local environment variable settings to remote storage
# so that they can be referenced by the CICD pipeline or other members
# of the development team
# param1 - optional. The token to use to contact the Git repository
push_env_vars () {
    # check that the env var value can be retrieved or exit if not
    # special syntax needed to get exit code for local variable
    local envVarLoc; envVarLoc=$(get_env_var_value REMOTE_ENV_VAR_LOC) || exit 1

    if [[ "$envVarLoc" == "gitlab" ]]; then        
        set_gitlab_cicd_vars_for_env "$1"
    elif [[ "$envVarLoc" == "ssm" ]]; then
        set_ssm_remote_vars_for_env
    elif [[ "$envVarLoc" == "NA" ]] || [[ "$envVarLoc" == "na" ]]; then
        display "Skipping exporting environment variables since REMOTE_ENV_VAR_LOC=$envVarLoc"
    else
        displayIssue "no implementation found to export environment variables to location: ${envVarLoc}" "error"
        exit 1
    fi
}

# Prints a table of CloudTrail logs for IAM permission denied events
# over a date range. Useful for debugging IAM role permissions
# param1: optional - the start date to search logs from. Defaults to today.
#         example value: 2023-01-15
# param2: optional - the end date to search logs to. Defaults to tomorrow.
#         example value: 2023-01-16
print_auth_errors () {

    set_aws_cli_profile
    validate_aws_cli_account || return 1

    local startDate=$1
    if [[ -z "$startDate" ]]; then
        # default to today
        startDate=$(date +%Y-%m-%d)
    fi

    local endDate=$2
    if [[ -z "$endDate" ]]; then 
        # default to tomorrow
        endDate=$(date -v+1d +%Y-%m-%d)
    fi

    display "\nLooking up IAM permission-denied logs in CloudTrail between ${startDate} and ${endDate}"
    display "This may take 1 to 5 minutes...\n"

    ( echo "Time,Identity ARN,Event ID,Service,Action,Error,Message";
    aws cloudtrail lookup-events --start-time "${startDate}T00:00:00Z" --end-time "${endDate}T00:00:00Z" --query "Events[*].CloudTrailEvent" --output text \
        | jq -r ". | select(.eventType == \"AwsApiCall\" and .errorCode != null
        and (.errorCode | ascii_downcase | (contains(\"accessdenied\") or contains(\"unauthorized\"))))
        | [.eventTime, .userIdentity.arn, .eventID, .eventSource, .eventName, .errorCode, .errorMessage] | @csv"
    ) | column -t -s'",'
}

# Print out the app configuration state for easy debugging
log_env () {

    if [[ "$ROOT_CONTEXT" == "coin_hooks" ]]; then
        return 0
    fi

    log "\n---BEGIN DEBUG:\n"

    log "HERE ARE THE ENV_KEYS:"
    for i in ${!ENV_KEYS[@]}; do
        log ${ENV_KEYS[$i]}
    done

    log "\nHERE ARE THE ENV_CONSTANTS:"
    for i in ${!ENV_CONSTANTS[@]}; do
        log "$i = ${ENV_CONSTANTS[$i]}"
    done
    log ""

    local tempEnvName; tempEnvName=$(get_env_var_value "ENV_NAME")
    log "\nENV_NAME is \"$tempEnvName\""

    log "\nHERE ARE THE ENV_CONFIGS:"
    for i in ${!ENV_CONFIGS[@]}; do
        if [[ "$COIN_NO_ENV_FILE" != "true" ]] && [[ "$CI" != "true" ]]; then
            log "$i = ${ENV_CONFIGS[$i]}"
        elif [[ " ${CLEAR_TEXT_ENV_KEYS[*]} " =~ " ${i} " ]]; then
            log "$i = ${ENV_CONFIGS[$i]}"
        else
            log "$i = (masked for CI mode)"
        fi
    done

    log "\nHERE ARE THE COMMAND LINE OVERRIDES:"
    for i in ${!ENV_KEYS[@]}; do
        local envVarOverrideName="COIN_OVERRIDE_${ENV_KEYS[$i]}"
        if [[ ! -z "${!envVarOverrideName}" ]]; then
            log "${ENV_KEYS[$i]} = ${!envVarOverrideName}"
        fi
    done

    log "\nHERE ARE THE SENSITIVE ENV_CONFIGS:"
    for i in ${!ENV_SENSITIVE_CONFIGS[@]}; do
        log "$i = ${ENV_SENSITIVE_CONFIGS[$i]}"
    done

    if [[ "$COIN_NO_ENV_FILE" != "true" ]] && [[ "$CI" != "true" ]]; then
        log "\nENV_RECONCILED_JSON:"
        log "$ENV_RECONCILED_JSON"
    fi

    log "\nCOIN_ENV_VAR_FILE_NAME is \"$COIN_ENV_VAR_FILE_NAME\""

    log "EXIT_AFTER_DEBUG=\"$EXIT_AFTER_DEBUG\"\n"

    log "END DEBUG---\n"
}

# Converts spinal/snake case to CamelCase
spinalcase_to_camelcase() {
    IFS=- read -ra str <<<"$1"
    printf '%s' "${str[@]^}"
}

# Returns the name of the current working directory without any path
get_simple_dir_name() {
    echo "${PWD##*/}"
}

# Prints the AWS CLI identity and session expiration time, if available
get_caller_identity () {
    echo -e "\nThis is who you are for AWS CLI commands:"
    aws sts get-caller-identity | jq --color-output --sort-keys

    cliExpires=$(aws configure export-credentials | jq -r '.Expiration')
    if [[ "$cliExpires" == "null" ]]; then
        echo -e "\nCannot determine session expiration since you are not logged in using an AWS_PROFILE\n"
    else
        echo -e -n "\n${CYAN}current session expires: ${NC}"
        cliExpiresNoOffset=${cliExpires%+*}
        mills=$(TZ=UTC date -j -f "%Y-%m-%dT%H:%M:%S" "$cliExpiresNoOffset" "+%s")
        date -r "$mills" +'%I:%M %p %Z'
        echo ""
    fi
}

# Determine whether IaC technology is CDK or Terraform or CloudFormation, etc.
detect_and_set_iac_type() {
    if [[ " ${ENV_KEYS[*]} " =~ " TF_S3_BACKEND_NAME " ]]; then
        iac="terraform"
    fi

    cdkJsonFile=$(find "$projectIacDir" -type f -name 'cdk.json')
    if [[ ! -z "$cdkJsonFile" ]]; then
        iac="cdk2"
    fi

    if [[ ! "$iac" ]]; then
        iac="cf"
    fi
}

# Creates COIN upgrade JSON based on the current project
# param1: optional - if argument is supplied with a value of "destructive", the COIN upgrade will overwrite files that
#                    the application developers may have changed
get_coin_upgrade_configs () {

    # Throw error if no current environment is defined
    get_current_env 1> /dev/null || exit 1

    # Throw error if not all environment settings are defined
    print_current_environment 1> /dev/null || exit 1

    detect_and_set_iac_type

    if [[ "$1" == "destructive" ]]; then
        destructiveUpgrade="y"
    else
        destructiveUpgrade="n"
    fi

    local uj="{\n"
    uj="${uj}\t\"APP_NAME\":\"$APP_NAME\",\n"
    uj="${uj}\t\"AWS_ACCOUNT_ID\":\"$AWS_ACCOUNT_ID\",\n"
    uj="${uj}\t\"AWS_DEFAULT_REGION\":\"$AWS_DEFAULT_REGION\",\n"

    if [[ -z "$AWS_SECONDARY_REGION" ]]; then
        local hasSecondaryRegion="n"
        uj="${uj}\t\"AWS_SECONDARY_REGION\":\"blank\",\n"
    else
        local hasSecondaryRegion="y"
        uj="${uj}\t\"AWS_SECONDARY_REGION\":\"$AWS_SECONDARY_REGION\",\n"
    fi

    if [[ -f "$projectDir/.gitlab-ci.yml" ]]; then
        uj="${uj}\t\"cicd\":\"gitlab\",\n"
    else
        uj="${uj}\t\"cicd\":\"\",\n"
    fi

    if [[ -d "$projectIacRootModuleDir/$projectCicdModuleName" ]]; then
        uj="${uj}\t\"useCicd\":\"y\",\n"
    # special code for CloudFormation since it hasn't been updated yet to have its cicd stack under the IaC dir
    elif [[ "$iac" == "cf" ]] && [[ -d "$projectDir/$projectCicdModuleName" ]]; then
        uj="${uj}\t\"useCicd\":\"y\",\n"
    else 
        uj="${uj}\t\"useCicd\":\"n\",\n"
    fi

    if [[ -z "$CREATED_BY" ]]; then
        CREATED_BY="$(whoami)"
    fi
    uj="${uj}\t\"CREATED_BY\":\"$CREATED_BY\",\n"

    uj="${uj}\t\"createRemoteGitRepo\":\"n\",\n"
    uj="${uj}\t\"deployCdk2Backend\":\"n\",\n"
    uj="${uj}\t\"deployRemoteEnvVars\":\"n\",\n"
    uj="${uj}\t\"deployCicdResources\":\"n\",\n"
    uj="${uj}\t\"deployTfBackend\":\"n\",\n"
    uj="${uj}\t\"ENV_NAME\":\"$ENV_NAME\",\n"

    if [[ "$destructiveUpgrade" == "y" ]]; then
        uj="${uj}\t\"firstIacModuleName\":\"example\",\n"
    else
        uj="${uj}\t\"firstIacModuleName\":\"not_used_during_upgrade\",\n"
    fi
    
    uj="${uj}\t\"gitRepoDomain\":\"$gitRepoDomain\",\n"

    # handle upgrades for apps that are not committed to Git
    if [[ -z "$gitProjectName" ]]; then
        gitProjectName="${projectDir##*/}"
        uj="${uj}\t\"gitRepoProvider\":\"na\",\n"
    else
        uj="${uj}\t\"gitRepoProvider\":\"gitlab\",\n"
    fi

    uj="${uj}\t\"gitProjectGroup\":\"$gitProjectGroup\",\n"
    uj="${uj}\t\"gitProjectName\":\"$gitProjectName\",\n"
    uj="${uj}\t\"hasSecondaryRegion\":\"$hasSecondaryRegion\",\n"
    uj="${uj}\t\"iac\":\"$iac\",\n"
    appParentDir="$(dirname "$projectDir")/"
    uj="${uj}\t\"appParentDir\":\"$appParentDir\",\n"
    uj="${uj}\t\"REMOTE_ENV_VAR_LOC\":\"$REMOTE_ENV_VAR_LOC\",\n"

    if [[ -z "$TF_S3_BACKEND_NAME" ]]; then
        uj="${uj}\t\"TF_S3_BACKEND_NAME\":\"blank\",\n"
    else
        uj="${uj}\t\"TF_S3_BACKEND_NAME\":\"$TF_S3_BACKEND_NAME\",\n"
    fi

    uj="${uj}\t\"destructiveUpgrade\":\"$destructiveUpgrade\"\n"
    uj="${uj}}\n"

    echo -e "$uj"
}

# Upgrades the COIN files/scripts for this application
# param1: optional - if argument is supplied with a value of "destructive", the COIN upgrade will overwrite files that
#                    the application developers may have changed
upgrade_coin () {

    if [[ -z  "$COIN_HOME" ]]; then
        displayIssue "You must set the COIN_HOME environment variable to the directory on your computer where you have cloned COIN before you can upgrade." "error"
        displayInColor "\nExample Command:\n" "$RED"
        displayInColor "\texport COIN_HOME=/code/create-coin-app\n" "$RED"
        exit 0
    fi

    if [[ ! -f "$COIN_HOME/create-app.sh" ]]; then
        displayIssue "The COIN_HOME environment variable is not set to a valid location. Please confirm the setting and try again." "error"
        exit 0
    fi

    upgradeCoinNow="y"

    if [[ -d "$projectDir/.git" ]]; then
        local coinUpgradeDiffOutput; coinUpgradeDiffOutput=$(git diff --quiet && git diff --cached --quiet)
        if [ $? -eq 0 ]; then
            local coinAppToUpgradeHasLocalChanges="n"
        else
            local coinAppToUpgradeHasLocalChanges="y"
        fi

        if [[ "$HEADLESS" != "y" ]]; then
            if [[ "$coinAppToUpgradeHasLocalChanges" == "y" ]]; then
                displayIssue "Your Git project has uncommitted local changes. It is recommended that you commit or stash any local changes before upgrading COIN. This will make it easy for you to review the local changes made by the COIN upgrade before merging them.\n" "warn"
                yes_or_no upgradeCoinNow "Do you wish to ignore this warning and continue with the upgrade?" "n"
            else
                yes_or_no upgradeCoinNow "Are you sure you want to upgrade your project to use the latest COIN files?" "n"
            fi
        fi
    
    elif [[ "$HEADLESS" != "y" ]]; then
        yes_or_no upgradeCoinNow "Are you sure you want to upgrade your project to use the latest COIN files?" "n"
    fi

    if [[ "$upgradeCoinNow" == "y" ]]; then 
        echo "$(get_coin_upgrade_configs "$1")" > "$projectDir/temp-coin-upgrade-headless.json"

        if jq empty "$projectDir/temp-coin-upgrade-headless.json" 2>/dev/null; then
            log "COIN upgrade configs are structurally valid JSON"
        else
            displayIssue "COIN internal error - project upgrade configurations contain structurally invalid JSON" "error"
            local upgradeJson="$(cat "$projectDir/temp-coin-upgrade-headless.json")"
            display "$upgradeJson"
            exit 1
        fi

        cd "$COIN_HOME" 1> /dev/null
        ./create-app.sh "$projectDir/temp-coin-upgrade-headless.json"
        local upgradeExitCode=$?
        rm "$projectDir/temp-coin-upgrade-headless.json"
        cd - 1> /dev/null

        if [[ "$upgradeExitCode" == "0" ]]; then
            log "App upgrade was successful!"
        else
            log "App upgrade failed with status code $upgradeExitCode"
        fi

        return "$upgradeExitCode"
    fi
}

# Associative array that holds the key value pairs pulled from the environment constants json file
declare -A ENV_CONSTANTS=()

# Associative array that holds key value pairs pulled from the current environment json file
declare -A ENV_CONFIGS=()

# Associative array that holds key value pairs pulled from the sensitve current environment json file
declare -A ENV_SENSITIVE_CONFIGS=()

# Associative array that holds key value pairs pulled from dynamic lookups
declare -A ENV_LOOKUP_CONFIGS=()

# Associative array that holds key value pairs for dynamic lookups
# The key is the environment property name
# The value provides information on the name to dynamically look up
# See dynamic-lookups.sh for details
declare -A LOOKUPS=()

# Associative array with key names being upper case regions and values of actual region names
declare -A COIN_REGIONS=()
COIN_REGIONS["AP_EAST_1"]="ap-east-1"
COIN_REGIONS["AP_NORTHEAST_1"]="ap-northeast-1"
COIN_REGIONS["AP_NORTHEAST_2"]="ap-northeast-2"
COIN_REGIONS["AP_NORTHEAST_3"]="ap-northeast-3"
COIN_REGIONS["AP_SOUTH_1"]="ap-south-1"
COIN_REGIONS["AP_SOUTH_2"]="ap-south-2"
COIN_REGIONS["AP_SOUTHEAST_1"]="ap-southeast-1"
COIN_REGIONS["AP_SOUTHEAST_2"]="ap-southeast-2"
COIN_REGIONS["AP_SOUTHEAST_3"]="ap-southeast-3"
COIN_REGIONS["AP_SOUTHEAST_4"]="ap-southeast-4"
COIN_REGIONS["EU_CENTRAL_1"]="eu-central-1"
COIN_REGIONS["EU_CENTRAL_2"]="eu-central-2"
COIN_REGIONS["EU_NORTH_1"]="eu-north-1"
COIN_REGIONS["EU_SOUTH_1"]="eu-south-1"
COIN_REGIONS["EU_SOUTH_2"]="eu-south-2"
COIN_REGIONS["EU_WEST_1"]="eu-west-1"
COIN_REGIONS["EU_WEST_2"]="eu-west-2"
COIN_REGIONS["EU_WEST_3"]="eu-west-3"
COIN_REGIONS["US_EAST_1"]="us-east-1"
COIN_REGIONS["US_EAST_2"]="us-east-2"
COIN_REGIONS["US_WEST_1"]="us-west-1"
COIN_REGIONS["US_WEST_2"]="us-west-2"
