#!/usr/bin/env bash

# Utility functions that can be reused by "sourcing" them into other scripts.
# Can be run from command line if you pass the function name and its arguments
# as parameters to this script.

# Returns framework environment variable names. These are variables
# needed by the variable resolution framework and do not contain
# any application-specific variables that are not part of the core
# framework
get_framework_env_var_names () {
    echo "APP_NAME AWS_ACCOUNT_ID AWS_DEFAULT_REGION ENV_NAME REMOTE_ENV_VAR_LOC CREATED_BY AWS_PRIMARY_REGION AWS_SECONDARY_REGION TF_S3_BACKEND_NAME AWS_CREDS_TARGET_ROLE"
}

# Verify that the current shell is bash and that the bash shell is at least version 5
validate_bash_version () {
    local substring="bash"
    local curShell=$(ps -p $$ | tail -n +2)

    if [[ ! "${curShell#*"$substring"}" != "$curShell" ]]; then
        displayIssue "The shell must be bash but was \"$curShell\"." "error" "always"
        exit 1
    fi

    local requiredMajorVersion=5
    if [[ "${BASH_VERSINFO:-0}" -lt "$requiredMajorVersion" ]]; then
        displayIssue "You are currently running Bash shell version ${BASH_VERSINFO:-0}. Please upgrade to $requiredMajorVersion or later" "error" "always"
        displayIssue "\n* Mac users can install the latest bash shell with this command:\n    ${CYAN}brew install bash${NC}" "" "always"
        displayIssue "\n* Amazon Linux 2 users can install the latest bash shell with these commands:" "" "always"
        displayIssue "    ${CYAN}cd ~${NC}" "" "always"
        displayIssue "    ${CYAN}wget http://ftp.gnu.org/gnu/bash/bash-5.2.tar.gz${NC}" "" "always"
        displayIssue "    ${CYAN}tar xf bash-5.2.tar.gz${NC}" "" "always"
        displayIssue "    ${CYAN}cd bash-5.2${NC}" "" "always"
        displayIssue "    ${CYAN}./configure${NC}" "" "always"
        displayIssue "    ${CYAN}make${NC}" "" "always"
        displayIssue "    ${CYAN}sudo make install${NC}" "" "always"
        displayIssue "    ${CYAN}sh${NC}" "" "always"
        displayIssue "    ${CYAN}bash -version${NC}\n" "" "always"

        exit 1
    fi
}

validate_jq () {
    if ! command -v jq --version &> /dev/null
    then
        displayIssue "jq could not be found. Please install jq, then run this script again." "error" "always"
        displayIssue "\n* Mac users can install jq with this command:\n    ${CYAN}brew install jq${NC}" "" "always"
        displayIssue "\n* Amazon Linux 2 users can install jq with this command:\n    ${CYAN}sudo yum install jq${NC}" "" "always"
        displayIssue "\n* Ubuntu Linux users can install jq with this command:\n    ${CYAN}sudo apt-get install jq${NC}\n" "" "always"

        exit 1
    fi
}

validate_checkov () {
    if ! command -v checkov --version &> /dev/null
    then
        displayIssue "checkov could not be found. Please install checkov, then run this script again." "error" "always"

        exit 1
    fi
}

setup_logging () {
    local parentDir
    if [[ "$CREATE_APP" == "true" ]]; then
        parentDir="$projectDir"
    else
        parentDir="$projectEnvDir"
    fi
    COIN_LOG_FILE_PATH="$parentDir/.log.txt"
    local time=$(date +"%I:%M:%S %p")
    local sep="----------------------------------------------"
    # Create a new log file and delete any previous logs when a new Make target is executed
    # or the Create COIN App wizard is run
    if [[ "$CREATE_APP" == "true" ]] || [[ "$ROOT_CONTEXT" == "coin_hooks" ]]; then
        echo "" > "$COIN_LOG_FILE_PATH"
    fi

    echo -e "${sep}\n$time - Context: ${ROOT_CONTEXT}\n${sep}\n" >> "$COIN_LOG_FILE_PATH"
}

# Logs statement to a file.
# param1: the statement to log
log () {
    local msg="$1"

    # Strip out colors before logging
    msg=${msg/\\033[0m/""}    # NC (first match)
    msg=${msg/\\033[0m/""}    # NC (second match)
    msg=${msg/\\033[0;36m/""} # CYAN
    msg=${msg/\\033[0;32m/""} # GREEN
    msg=${msg/\\033[1;33m/""} # YELLOW
    msg=${msg/\\033[0;31m/""} # RED
    msg=${msg/\\033[0;35m/""} # PURPLE
    msg=${msg/\\033[0;37m/""} # GRAY

    echo -e "$msg" >> "$COIN_LOG_FILE_PATH"
}

# Write to the console (stdout) and log
# param1 message to display
# param2 optional. If not blank, causes echo to go to stderr
# param3 optional. If set to "always", the message will always be displayed
display () {

    local displayOutput=y
    if [[ "$ROOT_CONTEXT" == "coin_hooks" ]]; then
        displayOutput=n
    elif [[ "$3" == "suppress_when_quiet" ]] && [[ "$COIN_QUIET_MODE" == "y" ]]; then
        displayOutput=n
    fi

    # Do not print anything to the console when running in the context of coin_hooks
    if [[ "$3" == "always" ]] || [[ "$displayOutput" == "y" ]]; then
        if [[ -z "$2" ]]; then
            echo -e "$1"
        else
            echo -e "$1" >&2
        fi
    fi
    
    log "$1"
}

# Displays text in a color
# param1: the statement to log
# param2: the color to display the text in
# Example call of this function: 
#    displayInColor "Hello in color" "$CYAN"
displayInColor () {
    local msg="$1"
    local color="$2"

    if [[ ! -z "$color" ]]; then
        msg="${color}$msg${NC}"
    fi

    display "$msg"
}

# Displays a message to the console only if quiet mode is disabled, but always logs the message.
# param1: the message to display
displayIfNotQuiet () {
    display "$1" "" "suppress_when_quiet"
}

# Displays a message to the console (stderr) and logs the message.
# Using the second parameter can allow you to print error and warning
# messages in color.
# param1: the statement to log
# param2: optional set to "warn" or "error" if you want to print in color
# param3 optional. If set to "always", the message will always be displayed
displayIssue () {
    local msg="$1"
    local prepend
    local color

    if [[ "$2" == "warn" ]]; then
        prepend="\nWARNING: "
        color="${YELLOW}"
    elif [[ "$2" == "error" ]]; then
        prepend="\nERROR: "
        color="${RED}"
    fi

    if [[ ! -z "$2" ]]; then
        msg="${color}${prepend}$msg${NC}"
    fi

    display "$msg" "stderr" "$3"
}

# Set the called script function name into the ROOT_CONTEXT variable. 
# Alternatively, when this script is sourced from another script, the sourcing
# script must pass in a value to use for the ROOT_CONTEXT

COIN_UTIL_SCRIPT_ARGS="$(echo $@ | xargs)" # nosemgrep # xargs will trim whitespace
ROOT_CONTEXT=${COIN_UTIL_SCRIPT_ARGS#"source "}

ROOT_CONTEXT_FIRST_WORD=${ROOT_CONTEXT%% *}
ROOT_CONTEXT_ARGS="$(echo ${ROOT_CONTEXT#"$ROOT_CONTEXT_FIRST_WORD"} | xargs)" # nosemgrep # xargs will trim whitespace
ROOT_CONTEXT="$ROOT_CONTEXT_FIRST_WORD"

scriptDir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# Declare global variable that stores JSON that holds all environment
# values. Clear this variable right away in case it was somehow set
# in the calling shell
ENV_RECONCILED_JSON=""

# Array that holds the key names from the app-env-var-names.txt file
declare ENV_KEYS=()

# Array that holds the key names from the app-env-var-names.txt file
# that can be logged in clear text. This array should only include
# configurations that do not hold secret or sensitive information,
# such as passwords.
declare CLEAR_TEXT_ENV_KEYS=()

# Array that holds commands to run when COIN is called, before COIN does anything else
declare COIN_BEFORE_HOOKS=()

# Array that holds commands to run after the user switches the current environment
declare COIN_AFTER_SWITCH_ENV_HOOKS=()

source "$scriptDir/constants.sh" 1> /dev/null
if [[ -f "$projectEnvDir/Makefile" ]] && [[ ! -f "$projectEnvDir/make-env" ]]; then
    touch "$projectEnvDir/make-env"
fi

setup_logging

# Load custom extensions
log "\nLoading extensions from $scriptDir/extensions.sh\n"
source "$scriptDir/extensions.sh" 1> /dev/null

set_gitlab_curl_command

if [[ "$CREATE_APP" != "true" ]]; then
    log "\nApplication Constant Settings:"
    log "          Application Root Dir: $projectDir"
    log "   Core Environment Script Dir: $projectEnvDir"
    log "                       IaC Dir: $projectIacDir"
    log "           IaC Root Module Dir: $projectIacRootModuleDir"
    log "  IaC Root Module Relative Dir: $projectIacRootModulePath"
    log "  Application Build Script Dir: $projectBuildScriptDir"
    log "              CICD Module Name: $projectCicdModuleName"
    log "CICD (CloudFormation Only) Dir: $projectCicdDir"
    log "                  Before Hooks: ${COIN_BEFORE_HOOKS[*]}"
    log "After Environment Switch Hooks: ${COIN_AFTER_SWITCH_ENV_HOOKS[*]}"
    log "           Clear Text Log Keys: ${CLEAR_TEXT_ENV_KEYS[*]}"
    log "          Node Package Manager: $coinPackageManager"
    log "             gitLabCurlCommand: $gitLabCurlCommand"
    log ""
fi

log "COIN_UTIL_SCRIPT_ARGS were \"$COIN_UTIL_SCRIPT_ARGS\""
log "ROOT_CONTEXT is \"$ROOT_CONTEXT\""
log "ROOT_CONTEXT_ARGS is \"$ROOT_CONTEXT_ARGS\""

validate_bash_version
validate_jq

source "$scriptDir/bash-5-utils.sh" 1> /dev/null

if [[ -f "$scriptDir/gitlab.sh" ]]; then
    source "$scriptDir/gitlab.sh" 1> /dev/null
fi

if [[ ! "$ROOT_CONTEXT" =~ ^(create_app_wizard|extract_deliverable_wizard|generate_deployment_instructions_wizard|print_blank_app_env_vars_json)$ ]]; then

    if [[ "$DR" =~ ^[Yy]$ ]]; then
        DYNAMIC_RESOLUTION="y"
    fi

    if [[ -f "$projectEnvDir/dynamic-lookups.sh" ]]; then
        source "$projectEnvDir/dynamic-lookups.sh" 1> /dev/null
        LOOKUP_VALS_JSON="{}"

        if [[ "${#LOOKUPS[@]}" == "0" ]]; then
            DYNAMIC_RESOLUTION="na"
        fi
    else
        DYNAMIC_RESOLUTION="na"
    fi

    initLoadCurrentEnv="y"
    # For commands that don't require environment values, skip loading it

    if [[ "$ROOT_CONTEXT" == "coin_hooks" ]] && [[ "$ROOT_CONTEXT_ARGS" =~ ^(create-environment|ce|delete-environment|de|get-current-environment|gce|list-local-environments|lle|list-template-files|switch-current-environment|sce)$ ]]; then
        log "\nSkipping loading environment files for coin_hooks since it is not needed for ROOT_CONTEXT_ARGS \"$ROOT_CONTEXT_ARGS\" \n"

        initLoadCurrentEnv="n"
    fi
    if [[ "$ROOT_CONTEXT" =~ ^(get_current_env|get_local_environment_names|get_template_files|switch_local_environment)$ ]]; then
        log "\nSkipping loading environment files since it is not needed for ROOT_CONTEXT \"$ROOT_CONTEXT\" \n"
        initLoadCurrentEnv="n"
    fi
    if [[ "$initLoadCurrentEnv" == "y" ]]; then
        load_env_var_names
        load_env_settings
        log_env
    fi
    
elif [[ "$ROOT_CONTEXT" =~ ^(extract_deliverable_wizard|generate_deployment_instructions_wizard|print_blank_app_env_vars_json)$ ]]; then
    load_env_var_names
fi

if [[ "$EXIT_AFTER_DEBUG" == "y" ]]; then
    exit 1
fi

if [[ -z "$1" ]]; then
    # print out the function names defined in this script
    display "USAGE: Pass one of these function names and its input parameter"
    display "values as arguments to this script to execute it:"
    declare -F | sed "s/declare -f//"
elif [[ "$1" == "export_local_app_env_vars" ]]; then
    export_local_app_env_vars
elif [[ "$1" == "load_env_var_names" ]]; then
    display "load_env_var_names"
    for i in ${!ENV_KEYS[@]}; do
        display "${ENV_KEYS[$i]}"
    done
elif [[ "$1" == source* ]]; then
    :
else
    # This allows you to call a function within this script from a
    # command prompt by passing in the name of the function and any
    # arguments to the function.

    # exit is used here to prevent errors if utility-functions.sh is 
    # modified while it is running. In some cases, this exit causes
    # problems, such as when it could cause your shell to exit
    "$@"; exit
fi
