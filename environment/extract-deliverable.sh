#!/usr/bin/env bash

# Use this script to create an application milestone deliverable for sharing with others.
# For example, if we want to share a version 0.1 of our application code for someone
# else to look at, we can use this script to copy the sharable files into 
# a separate directory and remove any non-versioned files and directories, such as
# ".git", "node_modules" and ".terraform".

# Get original values for stdin and stderr for later reference
exec 21>&1
exec 22>&2

EXTRACT_BRANCH_NAME="$1"
if [[ "$EXTRACT_BRANCH_NAME" == *.json ]]; then
    EXTRACT_BRANCH_NAME=""
fi

# Exports (as environment variables) all values defined in the supplied .json
# file so that this wizard can run in headless mode.
# param1: a working path (absolute or relative) to the JSON file 
#         containing wizard answers
# Example input:
# {
#     "freshPull": "y",
#     "DELIVERABLE_NAME": "bats-deliverable",
#     "EXTRACT_BRANCH_NAME": "main",
#     "freshPullDir": "/tmp/git_clones",
#     "deliverableParentDir": "/tmp/customer-deliverables",
#     "deleteDeliverableDir": "y"
#     "includeEnv": "n",
#     "includeCicd": "n",
#     "includeMakefile": "y",
#     "generateResolveScript": "y",
#     "includeBuildScript": "y"
# }
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

    validate_yes_or_no "freshPull" "$freshPull"
    validate_yes_or_no "includeEnv" "$includeEnv"
    validate_yes_or_no "deleteDeliverableDir" "$deleteDeliverableDir"
    
    if [[ "$freshPull" == "y" ]]; then

        [[ ! "$EXTRACT_BRANCH_NAME" =~ ^[^[:space:]]{1,80}$ ]] && \
        displayIssue "\"EXTRACT_BRANCH_NAME\" value is invalid: \"$EXTRACT_BRANCH_NAME\"." "error" && \
        displayIssue "Must not include whitespace and length (${#EXTRACT_BRANCH_NAME}) must be between 1 and 80." && \
        exit 1

        [[ ! "$freshPullDir" =~ ^[^[:space:]]{1,150}$ ]] && \
        displayIssue "\"freshPullDir\" value is invalid: \"$freshPullDir\"." "error" && \
        displayIssue "Must not include whitespace and length (${#freshPullDir}) must be between 1 and 150." && \
        exit 1

        is_valid_clone_dir "$appRootParentDir" "$freshPullDir" isValidCloneDir
        if [[ $isValidCloneDir == "false" ]]; then
            exit 1
        fi
    fi

    [[ ! "$DELIVERABLE_NAME" =~ ^[^[:space:]]{1,50}$ ]] && \
    displayIssue "\"DELIVERABLE_NAME\" value is invalid: \"$DELIVERABLE_NAME\"." "error" && \
    displayIssue "Must not include whitespace and length (${#DELIVERABLE_NAME}) must be between 1 and 50." && \
    exit 1

    [[ ! "$deliverableParentDir" =~ ^[^[:space:]]{1,150}$ ]] && \
    displayIssue "\"deliverableParentDir\" value is invalid: \"$deliverableParentDir\"." "error" && \
    displayIssue "Must not include whitespace and length (${#deliverableParentDir}) must be between 1 and 150." && \
    exit 1

    is_valid_deliverable_dir "$deliverableParentDir" "$DELIVERABLE_NAME" isValidDeliverableParentDir

    if [[ $is_valid_deliverable_dir == "false" ]]; then
        exit 1
    fi

    if [[ -d "${appRootDir}${projectIacRootModulePath}${projectCicdPath}" ]]; then 
        validate_yes_or_no "includeCicd" "$includeCicd"
    fi

    if [[ "$includeEnv" == "n" ]]; then
        if [ -f "${appRootDir}/Makefile-4-customer" ] || [ -f "${appRootDir}/Makefile" ]; then
            validate_yes_or_no "includeMakefile" "$includeMakefile"
        fi
        validate_yes_or_no "generateResolveScript" "$generateResolveScript"
    fi

    if [ -d "${appRootDir}/build-script" ]; then
        validate_yes_or_no "includeBuildScript" "$includeBuildScript"
    fi
}

# Sets Bash nameref variable to "true" if the deliverable directory is valid or
# "false" otherwise
# param1: the deliverable parent directory path
# param2: the name of the deliverable-version directory (without path)
# param3: the nameref variable that will be set to "true" or "false"
is_valid_deliverable_dir () {
    local deliverableParentDir="$1"
    local deliverableDir="${deliverableParentDir}$2"
    local -n returnVar=$3
    returnVar="true"
    
    if [[ -z "$deliverableParentDir" ]]; then
        returnVar="false"
    elif [[ ! "$deliverableParentDir" == */ ]]; then
        displayIssue "The directory name must end with /"
        returnVar="false"
    elif [[ "$deliverableParentDir" == "${appRootDir}/" ]]; then
        displayIssue "The new deliverable must be created outside of the ${appRootDir} directory"
        returnVar="false"
    elif [[ ! -d "$deliverableDir" ]]; then
        :
    elif [[ "$(ls -A ${deliverableDir})" ]]; then
        displayIssue "\nThe deliverable directory \"$deliverableDir\" cannot already exist."

        if [[ "$HEADLESS" != "y" ]]; then
            yes_or_no deleteDeliverableDir "Would you like to delete this directory" "y"
        fi
        
        if [[ "$deleteDeliverableDir" == "y" ]]; then
            rm -rf "$deliverableDir"
        else
            returnVar="false"
        fi
    fi
}

# Sets Bash nameref variable to "true" if the clone directory is valid or
# "false" otherwise
# param1: the current application root parent directory
# param2: the clone parent directory path
# param2: the nameref variable that will be set to "true" or "false"
is_valid_clone_dir () {
    local appRootParentDir="$1"
    local cloneDir="$2"
    local -n returnVar=$3
    returnVar="true"
    
    if [[ -z "$cloneDir" ]]; then
        displayIssue "value is required" "error"
        returnVar="false"
    elif [[ "$appRootParentDir" == "$cloneDir" ]] || [[ "$appRootParentDir" == "$cloneDir/" ]]; then
        displayIssue "cannot clone to \"$appRootParentDir\" because the application already exists there." "error"
        returnVar="false"
    fi
}

# adds DELIVERABLE_NAME to global namespace
ask_deliverable_name () {
    display "\nThe deliverable version name must be unique. For example, it can be a"
    display "version number like \"1_0\" or a date like \"12_25_2022\".\n"
    defaultDeliverableName="$(get_cached_or_default_choice_value "defaultDeliverableName")"
    length_range DELIVERABLE_NAME "Enter the deliverable version name:" "$defaultDeliverableName" "1" "50"
}

# adds EXTRACT_BRANCH_NAME to global namespace
ask_branch_name () {
    # respect branch name being passed in as first script argument
    if [[ -z "$EXTRACT_BRANCH_NAME" ]]; then
        defaultBranchName="$(get_cached_or_default_choice_value "defaultBranchName")"
        length_range EXTRACT_BRANCH_NAME "\nEnter the branch name to clone:" "$defaultBranchName" "1" "80"
    fi
}

# Puts Extract Deliverable Wizard choices into an array for later caching use
populate_extract_deliverable_choice_cache_array () {
    [[ ! -z "$freshPull" ]] && choiceDeliverableCacheArray+=("defaultFreshPull=${freshPull}")
    [[ ! -z "$freshPullDir" ]] && choiceDeliverableCacheArray+=("defaultFreshPullDir=${freshPullDir}")
    [[ ! -z "$DELIVERABLE_NAME" ]] && choiceDeliverableCacheArray+=("defaultDeliverableName=${DELIVERABLE_NAME}")
    [[ ! -z "$EXTRACT_BRANCH_NAME" ]] && choiceDeliverableCacheArray+=("defaultBranchName=${EXTRACT_BRANCH_NAME}")
    [[ ! -z "$deliverableParentDir" ]] && choiceDeliverableCacheArray+=("defaultDeliverableParentDir=${deliverableParentDir}")
    [[ ! -z "$includeEnv" ]] && choiceDeliverableCacheArray+=("defaultIncludeEnv=${includeEnv}")
    [[ ! -z "$includeCicd" ]] && choiceDeliverableCacheArray+=("defaultIncludeCicd=${includeCicd}")
    [[ ! -z "$generateResolveScript" ]] && choiceDeliverableCacheArray+=("defaultGenerateResolveScript=${generateResolveScript}")
    [[ ! -z "$includeMakefile" ]] && choiceDeliverableCacheArray+=("defaultIncludeMakefile=${includeMakefile}")
    [[ ! -z "$includeBuildScript" ]] && choiceDeliverableCacheArray+=("defaultIncludeBuildScript=${includeBuildScript}")
}

# Write user choices to JSON cache file used by subsequent wizard run default values
write_choices_to_cache_file () {

    # Reinstate original stdout and stderr that may have been redirected
    exec 1>&21
    exec 2>&22

    # Enable echo. This may have been disabled when reading secret values
    stty echo

    populate_extract_deliverable_choice_cache_array
    printf -v joined '%s,' "${choiceDeliverableCacheArray[@]}"

    if [[ "$joined" == "," ]]; then
        log "\nSkipping writing choice cache since there were cacheable values entered.\n"
    else
        echo -n "${joined%,}" | jq -R -s 'split(",") | map(split("=")) | map({(.[0]): .[1]}) | add' > "$choiceCacheFilePath"
    fi

    log "\nExiting from write_choices_to_cache_file trap.\n"
}

# Add an event handler for when the script exits
trap write_choices_to_cache_file EXIT

# Initialization for when this wizard is running in interactive mode
init_interactive_mode () {

    if [[ -f $choiceCacheFilePath ]]; then
        yes_or_no useChoiceCache "\nWould you like to load default selections from previous run" "y"
        if [[ $useChoiceCache =~ ^[Yy]$ ]]; then
            choiceCacheJson=$(<"$choiceCacheFilePath")
        fi
    else

        initialChoiceVals="defaultFreshPull=$defaultFreshPullVal"
        initialChoiceVals="${initialChoiceVals},defaultFreshPullDir=$defaultFreshPullDirVal"
        initialChoiceVals="${initialChoiceVals},defaultDeliverableName=$defaultDeliverableNameVal"
        initialChoiceVals="${initialChoiceVals},defaultBranchName=$defaultBranchNameVal"
        initialChoiceVals="${initialChoiceVals},defaultDeliverableParentDir=$defaultDeliverableParentDirVal"
        initialChoiceVals="${initialChoiceVals},defaultIncludeEnv=$defaultIncludeEnvVal"
        initialChoiceVals="${initialChoiceVals},defaultIncludeCicd=$defaultIncludeCicdVal"
        initialChoiceVals="${initialChoiceVals},defaultGenerateResolveScript=$defaultGenerateResolveScriptVal"
        initialChoiceVals="${initialChoiceVals},defaultIncludeMakefile=$defaultIncludeMakefileVal"
        initialChoiceVals="${initialChoiceVals},defaultIncludeBuildScript=$defaultIncludeBuildScriptVal"

        # Create a local choice cache file based on initial project creation values
        echo -n "${initialChoiceVals%,}" | jq -R -s 'split(",") | map(split("=")) | map({(.[0]): .[1]}) | add' > "$choiceCacheFilePath"

        useChoiceCache="y"
        choiceCacheJson=$(<"$choiceCacheFilePath")
        
        log "\n$choiceCacheFilePath not found. Created it based on initialChoiceVals."
    fi

    log "\nChoice Cache JSON:"
    log "$choiceCacheJson"
}

get_cached_or_default_choice_value () {
    local choiceName="$1"
    local jqExpr=".$choiceName | select(type == \"string\")"
    local choiceVal="$(echo "$choiceCacheJson" | jq -r "$jqExpr")"

    # Protect against default values not getting set if user previously quit the
    # wizard before all choices were entered
    if [[ -z "$choiceVal" ]]; then
        if [[ "$choiceName" == "defaultFreshPull" ]]; then
            choiceVal="$defaultFreshPullVal"
        elif [[ "$choiceName" == "defaultFreshPullDir" ]]; then
            choiceVal="$defaultFreshPullDirVal"
        elif [[ "$choiceName" == "defaultDeliverableName" ]]; then
            choiceVal="$defaultDeliverableNameVal"
        elif [[ "$choiceName" == "defaultDeliverableParentDir" ]]; then
            choiceVal="$defaultDeliverableParentDirVal"
        elif [[ "$choiceName" == "defaultIncludeEnv" ]]; then
            choiceVal="$defaultIncludeEnvVal"
        elif [[ "$choiceName" == "defaultIncludeCicd" ]]; then
            choiceVal="$defaultIncludeCicdVal"
        elif [[ "$choiceName" == "defaultGenerateResolveScript" ]]; then
            choiceVal="$defaultGenerateResolveScriptVal"
        elif [[ "$choiceName" == "defaultIncludeMakefile" ]]; then
            choiceVal="$defaultIncludeMakefileVal"
        elif [[ "$choiceName" == "defaultIncludeBuildScript" ]]; then
            choiceVal="$defaultIncludeBuildScriptVal"
        elif [[ "$choiceName" == "defaultBranchName" ]]; then
            choiceVal="$defaultBranchNameVal"
        fi
    fi
    echo "$choiceVal"
}

scriptDir="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "$scriptDir/utility-functions.sh" "source extract_deliverable_wizard" 1> /dev/null

display "\nWelcome to the Create Application Deliverable Wizard!"

validate_bash_version

if ! command -v rsync --version &> /dev/null
then
    displayIssue "rsync could not be found. Please install rsync, then run this script again." "error"
    exit 1
fi

detect_and_set_iac_type

appRootDir="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && cd .. &> /dev/null && pwd )"
appName=${appRootDir##*/}
appRootParentDir="$( cd -- "$( dirname -- "${appRootDir}" )" &> /dev/null && pwd )"
appRootParentDir=${appRootParentDir}/

choiceCacheFilePath=$scriptDir/.extract-deliverable-choice-cache.json
choiceCacheJson=""
choiceDeliverableCacheArray=()
defaultFreshPullVal=y
defaultFreshPullDirVal="${appRootParentDir}pure-git-clones"
defaultDeliverableNameVal="$(date +%m-%d-%Y_%H-%M-%S)"
defaultDeliverableParentDirVal="${appRootParentDir}customer-deliverables/${appName}/"
defaultIncludeEnvVal=n
defaultIncludeCicdVal=n
defaultGenerateResolveScriptVal=y
defaultIncludeMakefileVal=y
defaultIncludeBuildScriptVal=n
defaultBranchNameVal=main

if [[ ! -z "$1" ]] && [[ "$1" == *.json ]]; then
    export HEADLESS="y"

    display "Running in headless mode."

    log "\nHeadless file input:"
    log "$(cat "$1")"

    export_wizard_answers "$1"
    validate_headless_mode_input

else
    init_interactive_mode

    isValidCloneDir="false"
    defaultFreshPull=$(get_cached_or_default_choice_value "defaultFreshPull")
    display "\nThe safest way to ensure that unversioned files do not make it into your"
    display "deliverable is to start with a fresh pull from the remote Git repository.\n"
    yes_or_no freshPull "Do you want to pull a fresh copy of the Git repository to a separate local directory" "$defaultFreshPull"
fi

if [[ "$freshPull" == "y" ]]; then

    if [[ "$HEADLESS" != "y" ]]; then
        ask_branch_name

        while [[ $isValidCloneDir == "false" ]]; do
            display ""
            defaultFreshPullDir="$(get_cached_or_default_choice_value "defaultFreshPullDir")"
            length_range freshPullDir "Enter the path of the directory that will store the freshly pulled files from Git:" \
            "$defaultFreshPullDir" "1" "150"
            is_valid_clone_dir "$appRootParentDir" "$freshPullDir" isValidCloneDir
        done

        display ""
    fi

    if [[ ! -d "$freshPullDir" ]]; then
        mkdir -p "$freshPullDir"
    fi

    if [[ "$freshPullDir" == */ ]]; then
        :
    else
        # make sure freshPullDir ends with /
        freshPullDir=${freshPullDir}/
    fi

    cd "$appRootDir"
    gitRemote=$(git remote get-url --push origin 2> /dev/null)

    if [[ ! -z "$gitRemote" ]]; then
        log "\ngitRemote is $gitRemote\n"
    else
        displayIssue "could not auto-detect git remote" "error"
        displayIssue "Configure the application's Git remote origin and try again"
        exit 1
    fi

    display "App name is ${appRootDir##*/}"

    cd "$freshPullDir"

    if [[ -d "$appName" ]]; then
        display "Deleting previous clone at ${freshPullDir}${appName}\n"
        rm -rf "${freshPullDir}${appName}"
    fi

    git clone "$gitRemote"
    if [[ ! -d "$appName" ]]; then
        displayIssue "\nfailed to clone Git repo at ${gitRemote}" "error"
        exit 1
    fi
    cd "$appName"
    git checkout "$EXTRACT_BRANCH_NAME" || { displayIssue "Invalid branch name: \"$EXTRACT_BRANCH_NAME\"" "error"; exit 1; }
    rm -rf "${freshPullDir}${appName}/.git"
    
    appRootDir="${freshPullDir}${appName}"
    appRootParentDir="$freshPullDir"

fi

if [[ "$HEADLESS" != "y" ]]; then
    ask_deliverable_name

    isValidDeliverableParentDir="false"
    display ""
    while [[ $isValidDeliverableParentDir == "false" ]]; do
        defaultDeliverableParentDir="$(get_cached_or_default_choice_value "defaultDeliverableParentDir")"
        length_range deliverableParentDir "Where should the \"$DELIVERABLE_NAME\" deliverable directory be created?" \
            "$defaultDeliverableParentDir" "1" "150"
        is_valid_deliverable_dir "$deliverableParentDir" "$DELIVERABLE_NAME" isValidDeliverableParentDir
    done
fi

deliverablePath="${deliverableParentDir}${DELIVERABLE_NAME}"
mkdir -p "$deliverablePath"

if [[ "$HEADLESS" != "y" ]]; then
    defaultIncludeEnv="$(get_cached_or_default_choice_value "defaultIncludeEnv")"
    if [[ -d "${appRootDir}${projectEnvPath}" ]]; then 
        display ""
        yes_or_no includeEnv "Do you want to include the \"environment\" scripts" "$defaultIncludeEnv"
    else
        includeEnv="n"
    fi
fi

if [[ "$includeEnv" == "y" ]]; then
    log "\nCopying ${appRootDir}${projectEnvPath} to $deliverablePath ..."
    rsync -av --progress "${appRootDir}${projectEnvPath}" "$deliverablePath" --exclude '.*' --exclude '.log.txt' --exclude 'extract-deliverable.sh' --exclude 'temp-*' --exclude make-env --exclude '.DS_Store' | tee -a "$projectEnvDir/.log.txt"
    log ""

    match="initialChoiceVals=.*$"
    newVal="initialChoiceVals=\"\""
    # Clear initialChoiceVals 
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "s|$match|$newVal|g" "${deliverablePath}${projectEnvPath}/create-app-environment.sh"
    else
        sed -i "s|$match|$newVal|g" "${deliverablePath}${projectEnvPath}/create-app-environment.sh"
    fi

fi

log "\nCopying ${appRootDir}${projectIacPath} to $deliverablePath ..."
rsync -av --progress "${appRootDir}${projectIacPath}" "$deliverablePath" --exclude 'cicd' --exclude '*.bak' --exclude 'temp-*' \
--exclude '*node_modules' --exclude 'cdk.out' --exclude '.terraform*' --exclude '.DS_Store' | tee -a "$projectEnvDir/.log.txt"
log ""

if [[ "$HEADLESS" != "y" ]]; then
    defaultIncludeCicd="$(get_cached_or_default_choice_value "defaultIncludeCicd")"
    if [[ -d "${appRootDir}${projectCicdPath}" ]] || [[ -d "${appRootDir}${projectIacRootModulePath}${projectCicdPath}" ]]; then 
        display ""
        yes_or_no includeCicd "Do you want to include the CICD pipeline" "$defaultIncludeCicd"
    else
        includeCicd="n"
    fi
fi

if [[ "$includeCicd" == "n" ]]; then
    log "\nCopying ${appRootDir}/ to $deliverablePath ..."
    rsync -av --progress "${appRootDir}/" "$deliverablePath" --exclude '*.bak' --exclude 'temp-*' --exclude '*node_modules' \
    --exclude '.git' --exclude 'cicd' --exclude 'environment' --exclude 'iac' \
    --exclude '.gitlab-ci*' | tee -a "$projectEnvDir/.log.txt"
    log ""

    rm -rf "${deliverablePath}${projectIacRootModulePath}${projectCicdPath}"

    if [[ "$includeEnv" == "y" ]]; then
        # Remove references to CICD pipeline
        grep -vE "(Git|GIT|GitLab|GITLAB|gitlab|CICD|cicd|AWS_CREDS_TARGET_ROLE)" "${deliverablePath}${projectEnvPath}/app-env-var-names.txt" > tmpfile && mv tmpfile "${deliverablePath}${projectEnvPath}/app-env-var-names.txt"
        
        grep -vE "(cicd|push-mirror|extract-deliverable)" "${deliverablePath}${projectEnvPath}/Makefile" > tmpfile && mv tmpfile "${deliverablePath}${projectEnvPath}/Makefile"
    fi

else
    log "\nCopying ${appRootDir}/ to $deliverablePath ..."
    rsync -av --progress "${appRootDir}/" "$deliverablePath" --exclude '*.bak' --exclude 'temp-*' --exclude '*node_modules' \
    --exclude '.git' --exclude 'cicd' --exclude 'environment' --exclude 'iac' --exclude '.DS_Store' | tee -a "$projectEnvDir/.log.txt"
    log ""

    if [[ -d "${appRootDir}${projectCicdPath}" ]]; then
        log "\nCopying ${appRootDir}${projectCicdPath} to $deliverablePath ..."
        rsync -av --progress "${appRootDir}${projectCicdPath}" "$deliverablePath" --exclude '*.bak' --exclude 'temp-*' --exclude '.DS_Store' | tee -a "$projectEnvDir/.log.txt"
        log ""
    elif [[ -d "${appRootDir}${projectIacRootModulePath}${projectCicdPath}" ]]; then
        log "\nCopying ${appRootDir}${projectIacRootModulePath}${projectCicdPath} to $deliverablePath ..."
        rsync -av --progress "${appRootDir}${projectIacRootModulePath}${projectCicdPath}" "${deliverablePath}${projectIacRootModulePath}" \
        --exclude '*.bak' --exclude 'temp-*' --exclude '.terraform*' \
        --exclude '.DS_Store' | tee -a "$projectEnvDir/.log.txt"
        log ""
    fi
    
fi

if [[ "$includeEnv" == "n" ]]; then

    if [ -f "${appRootDir}/Makefile-4-customer" ]; then

        if [[ "$HEADLESS" != "y" ]]; then
            display ""
            defaultIncludeMakefile="$(get_cached_or_default_choice_value "defaultIncludeMakefile")"
            yes_or_no includeMakefile "Do you want to set the Makefile-4-customer file to be the project's primary Makefile in the extracted deliverable" "$defaultIncludeMakefile"
        fi

        if [[ "$includeMakefile" == "y" ]]; then
            rm "$deliverablePath/Makefile"
            mv "$deliverablePath/Makefile-4-customer" "$deliverablePath/Makefile"
        else
            rm "$deliverablePath/Makefile"
            rm "$deliverablePath/Makefile-4-customer"
        fi

    elif [ -f "${appRootDir}/Makefile" ]; then
        if [[ "$HEADLESS" != "y" ]]; then
            display ""
            defaultIncludeMakefile="$(get_cached_or_default_choice_value "defaultIncludeMakefile")"
            yes_or_no includeMakefile "Do you want to include the project's Makefile" "$defaultIncludeMakefile"
        fi
        
        if [[ "$includeMakefile" == "n" ]]; then
            rm "$deliverablePath/Makefile"
        fi
        
    fi

fi

if [[ "$includeEnv" == "n" ]]; then

    if [[ "$HEADLESS" != "y" ]]; then
        if [ -f "${appRootDir}/Makefile-4-customer" ] && [[ "$includeMakefile" == "y" ]]; then
            generateResolveScript=y
        else
            display ""
            defaultGenerateResolveScript="$(get_cached_or_default_choice_value "defaultGenerateResolveScript")"
            yes_or_no generateResolveScript "Do you want to generate a script for the customer to use to resolve placeholders" "$defaultGenerateResolveScript"
        fi
    fi
    
    if [[ "$generateResolveScript" == "y" ]]; then

        display "\nGenerating script: \"${deliverablePath}/init.sh\"\n"

        echo -e "#!/usr/bin/env bash\n" >> "${deliverablePath}/init.sh"

        echo -e "# This function reads the file that is supplied as the first function argument." >> "${deliverablePath}/init.sh"
        echo -e "# It then resolves all placeholder values found in that file by" >> "${deliverablePath}/init.sh"
        echo -e "# replacing the ###ENV_VAR_NAME### placeholder with the value of the ENV_VAR_NAME." >> "${deliverablePath}/init.sh"
        echo -e "# param1: the name of the file that has placeholders to resolve" >> "${deliverablePath}/init.sh"
        echo -e "resolve_placeholders () {\n" >> "${deliverablePath}/init.sh"
        echo -e "    local filePath=\"\$1\"\n" >> "${deliverablePath}/init.sh"
        echo -e "    local SED_PATTERNS" >> "${deliverablePath}/init.sh"
        echo -e "    local resolvedContent=\"\$(cat \"\$filePath\")\"\n" >> "${deliverablePath}/init.sh"
        echo -e "    # Loop that replaces variable placeholders with values" >> "${deliverablePath}/init.sh"
        echo -e "    local varName" >> "${deliverablePath}/init.sh"
        echo -e "    while read varName" >> "${deliverablePath}/init.sh"
        echo -e "    do" >> "${deliverablePath}/init.sh"
        echo -e "        local envVarValue=\"\${!varName}\"\n" >> "${deliverablePath}/init.sh"
        echo -e "        if [[ \"\$envVarValue\" == \"blank\" ]]; then" >> "${deliverablePath}/init.sh"
        echo -e "            envVarValue=\"\"" >> "${deliverablePath}/init.sh"
        echo -e "        fi\n" >> "${deliverablePath}/init.sh"
        echo -e "        SED_PATTERNS=\"s|###\${varName}###|\${envVarValue}|g;\"\n" >> "${deliverablePath}/init.sh"
        echo -e "        resolvedContent=\"\$(echo \"\$resolvedContent\" | sed ''\"\$SED_PATTERNS\"'')\"\n" >> "${deliverablePath}/init.sh"
        echo -e "    done <<< \"\$(IFS=\$'\\\\n'; echo -e \"\${ENV_KEYS[*]}\" )\"\n" >> "${deliverablePath}/init.sh"
        echo -e "    echo \"\$resolvedContent\" > \"\$filePath\"" >> "${deliverablePath}/init.sh"
        echo -e "}" >> "${deliverablePath}/init.sh"

        echo -e "\necho -e \"\\\\nGreetings prototype user! Before you can get started deploying this prototype,\"" >> "${deliverablePath}/init.sh"
        echo -e "echo -e \"we need to collect some settings values from you...\\\\n\"\n" >> "${deliverablePath}/init.sh"

        envKeysString=""

        for varIndex in ${!ENV_KEYS[@]}; do
            varName=${ENV_KEYS[$varIndex]}

            if [[ "$varName" =~ ^(AWS_CREDS_TARGET_ROLE|REMOTE_ENV_VAR_LOC|CREATED_BY|gitProjectName|gitProjectGroup|gitRepoDomain)$ ]]; then
                :
                # echo -e "\n  Ignoring Key: ${varName}\n"
            else

                if [[ "$varIndex" == "0" ]]; then
                    envKeysString="$varName"
                else
                    envKeysString="$envKeysString $varName"
                fi

                if [[ "$varName" == "TF_S3_BACKEND_NAME" ]]; then

                    # Don't ask what S3 bucket name should be used because we need to apply a formula for it
                    # Note that the CF templates will automatically append the AWS account number and region to the bucket name
                    echo -e "TF_S3_BACKEND_NAME=\"\${APP_NAME}-\${ENV_NAME}-tf-back-end\"\n" >> "${deliverablePath}/init.sh"

                elif [[ "$varName" == "AWS_DEFAULT_REGION" ]] && [[ " ${ENV_KEYS[*]} " =~ " AWS_PRIMARY_REGION " ]]; then
                    continue
                    # Don't ask user to enter AWS_PRIMARY_REGION and AWS_DEFAULT_REGION since they should always be the same value.
                    # Just ask for the primary region if the application supports multiple regions
                else

                    # echo -e "\nFound Key: ${varName}"
                    description="$(get_env_var_description "${varName}")"
                    echo -e "echo -e \"\\\\n$description\"" >> "${deliverablePath}/init.sh"
                    echo "read -p \"Enter value: \" answer" >> "${deliverablePath}/init.sh"
                    echo "$varName=\"\$answer\"" >> "${deliverablePath}/init.sh"
                    
                    if [[ "$varName" == "AWS_PRIMARY_REGION" ]]; then
                        echo "AWS_DEFAULT_REGION=\"\$answer\"" >> "${deliverablePath}/init.sh"
                    fi

                    echo -e "" >> "${deliverablePath}/init.sh"

                fi
            fi

        done

        echo "envKeysString=\"$envKeysString\"" >> "${deliverablePath}/init.sh"
        echo "ENV_KEYS=(\$(echo \"\$envKeysString\"))" >> "${deliverablePath}/init.sh"

        coinTemplateFiles="./set-env-vars.sh $(echo -e "$(get_template_files)" | grep -vE "(.gitignore|.md)")"
        echo "templateFilePathsStr=\"$coinTemplateFiles\"" >> "${deliverablePath}/init.sh"
        echo "templateFilePaths=(\$(echo \"\$templateFilePathsStr\"))" >> "${deliverablePath}/init.sh"

        echo -e "\nfor templatePath in \"\${templateFilePaths[@]}\"; do" >> "${deliverablePath}/init.sh"

        echo -e "\n    if [[ \$templatePath == *4-customer ]]; then" >> "${deliverablePath}/init.sh"
        echo -e "        templatePath=\"./Makefile\"" >> "${deliverablePath}/init.sh"
        echo -e "    fi" >> "${deliverablePath}/init.sh" 
        
        echo -e "\n    if [[ -f \"\$templatePath\" ]]; then" >> "${deliverablePath}/init.sh"
        echo -e "        echo -e \"\\\\nResolving placeholders in \${templatePath}\"" >> "${deliverablePath}/init.sh"
        echo -e "        resolve_placeholders \"\$templatePath\"" >> "${deliverablePath}/init.sh"
        echo -e "    fi" >> "${deliverablePath}/init.sh"
        echo "done" >> "${deliverablePath}/init.sh"

        echo -e "\necho -e \"\\\\nSUCCESS!\\\\n\"" >> "${deliverablePath}/init.sh"

        chmod +x "${deliverablePath}/init.sh"

    fi

fi

if [[ "$includeEnv" == "y" ]]; then
    echo "default" > "${deliverablePath}${projectEnvPath}/.current-environment"
    log "Set ${deliverablePath}${projectEnvPath}/.current-environment contents to \"blank\".\n"
    log "Writing blank values to \"${deliverablePath}${projectEnvPath}/.environment-default.json\" ...\n"
    "${deliverablePath}${projectEnvPath}/utility-functions.sh" print_blank_app_env_vars_json > "${deliverablePath}${projectEnvPath}/.environment-default.json"
    
    log "${deliverablePath}${projectEnvPath}/.environment-default.json Contents:"
    log "$(cat "${deliverablePath}${projectEnvPath}/.environment-default.json")"
    log "\nprint_blank_app_env_vars_json logs:"
    log "$(cat "${deliverablePath}${projectEnvPath}/.log.txt")"
    log ""
    rm "${deliverablePath}${projectEnvPath}/.log.txt"
    log "Deleted ${deliverablePath}${projectEnvPath}/.log.txt\n"

    log "Setting ${deliverablePath}${projectEnvPath}/environment-constants.json to an empty object..."
    echo "{}" > "${deliverablePath}${projectEnvPath}/environment-constants.json"

    log "${deliverablePath}${projectEnvPath}/environment-constants.json Contents:"
    log "$(cat "${deliverablePath}${projectEnvPath}/environment-constants.json")"

elif [[ "$iac" == "terraform" ]]; then

    display "\nResolving ###CUR_DIR_NAME### placeholders in all backend.tf files under ${deliverablePath}${projectIacRootModulePath}.\n"

    # Replace ###CUR_DIR_NAME### variable with actual value

    cd "${deliverablePath}$projectIacRootModulePath" > /dev/null

    # find all paths (relative to the root TF module path) to backend.tf files and strip leading "./"
    find . -name "backend.tf" | sed -e 's,^\./,,' | while read fname; do
        backendTfDirName="${fname%"/backend.tf"}"
        SED_PATTERNS="s|###CUR_DIR_NAME###|$backendTfDirName|g;"

        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' "$SED_PATTERNS" "./${fname}"
        else
            sed -i "$SED_PATTERNS" "./${fname}"
        fi

    done

    cd "$appRootDir" > /dev/null

elif [[ "$iac" == "cdk2" ]]; then
    :
fi

if [[ "$includeEnv" == "n" ]]; then
    # Generate shell script that sets all of the environment variables  
    # Customers will need to update the values in this file before deploying the IaC
    for i in ${!ENV_KEYS[@]}; do
        inputVarName=${ENV_KEYS[$i]}

        # Remove environment variables that are only used during COIN prototype development
        if [[ "$inputVarName" =~ ^(gitProjectName|gitProjectGroup|gitRepoDomain|REMOTE_ENV_VAR_LOC|CREATED_BY)$ ]]; then
            continue
        fi

        if [[ "$includeCicd" == "n" ]] && [[ "$inputVarName" =~ ^(AWS_CREDS_TARGET_ROLE)$ ]]; then
            continue
        fi

        if [[ "$includeMakefile" == "y" ]]; then
            # Makefile will have init target that will perform placeholder replacement
            echo "export $inputVarName=\"###$inputVarName###\"" >> "${deliverablePath}/set-env-vars.sh"
        else
            echo "export $inputVarName=\"blank\"" >> "${deliverablePath}/set-env-vars.sh"
        fi
        
        chmod +x "${deliverablePath}/set-env-vars.sh"
    done

fi

if [ -d "${appRootDir}/build-script" ]; then

    if [[ "$HEADLESS" != "y" ]]; then
        if [ -f "${appRootDir}/Makefile-4-customer" ] && [[ "$iac" == "terraform" ]]; then
            includeBuildScript=y
            # terraform with Makefile-4-customer requires build-script/empty-s3.sh
        else
            display ""
            defaultIncludeBuildScript="$(get_cached_or_default_choice_value "defaultIncludeBuildScript")"
            yes_or_no includeBuildScript "Do you want to include the project's \"build-script\" directory" "$defaultIncludeBuildScript"
        fi
    fi
    
    if [[ "$includeBuildScript" == "n" ]]; then
        rm -rf "$deliverablePath/build-script"
    fi
fi

if [[ -f "$deliverablePath/.gitleaksignore" ]]; then
    rm "$deliverablePath/.gitleaksignore"
fi

display "\n${GREEN}Congratulations! The deliverable files are available under \"$deliverablePath\"!${NC}\n"
