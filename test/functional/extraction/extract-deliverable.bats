#!/usr/bin/env bats

setup_file () {
    load '../../test-helper/common-setup'
    _common_setup

    appParentDir="/tmp/"
    gitProjectName="bats-tf-local-deploy-nothing"
    generatedAppDir="${appParentDir}${gitProjectName}"
    inputFileName="/tmp/create-tf-app-headless-input.json"
    firstIacModuleName="example"
    
    # Note that closing "EOF" cannot be indented
    cat <<EOF > "$inputFileName"
    {
        "appParentDir": "$appParentDir",
        "createRemoteGitRepo": "n",
        "deployCdk2Backend": "n",
        "deployCicdResources": "n",
        "deployRemoteEnvVars": "n",
        "deployTfBackend": "n",
        "useCicd": "n",
        "hasSecondaryRegion": "n",
        "AWS_SECONDARY_REGION": "blank",
        "AWS_ACCOUNT_ID": "000000000000",
        "iac": "terraform",
        "REMOTE_ENV_VAR_LOC": "na",
        "APP_NAME": "tbat",
        "AWS_DEFAULT_REGION": "us-east-1",
        "CREATED_BY": "Anthony Watson",
        "ENV_NAME": "dev",
        "firstIacModuleName": "$firstIacModuleName",
        "gitProjectName": "$gitProjectName",
        "TF_S3_BACKEND_NAME": "$appName-$envName-tf-back-end"
    }
EOF

    # use for debugging:
    # cat $inputFileName >&3

    run create_tf_app "$inputFileName"
    
    assert_output --partial "Congratulations! Your application has been created at ${generatedAppDir}"
    assert_output --partial "A Terraform module has been created for you under your project's /iac/roots/${firstIacModuleName} directory"
    assert_exists "$generatedAppDir"
}

teardown_file () {
    rm -f "$inputFileName"
    rm -rf "$generatedAppDir"
}

setup () {
    load '../../test-helper/common-setup'
    _common_setup

    appParentDir="/tmp/"
    gitProjectName="bats-tf-local-deploy-nothing"
    generatedAppDir="${appParentDir}${gitProjectName}"
    generatedAppEnvDir="${generatedAppDir}/environment"
    generatedAppEnvLogFile="${generatedAppEnvDir}/.log.txt"
    iacDir="${generatedAppDir}/iac"
    iacRootsDir="${iacDir}/roots"
    appLogFile="$generatedAppDir/environment/.log.txt"
    exdInputFileName="/tmp/exd-tf-headless-input.json" # exd = "extract deliverable"
    exdScriptPath="${generatedAppEnvDir}/extract-deliverable.sh"
    appName="tbat"
    freshPullDir="${appParentDir}pure-git-clones"
    deliverableName="bats-tf-deliverable"
    deliverableParentDir="${appParentDir}customer-deliverables/$appName/"
    extractedProjectDir="${deliverableParentDir}$deliverableName"
    extractedProjectEnvDir="$extractedProjectDir/environment"
    extractDeliverableChoiceCacheFile="$generatedAppEnvDir/.extract-deliverable-choice-cache.json"
    firstIacModuleName="example"
    defaultEnvironmentJsonFile="$extractedProjectEnvDir/.environment-default.json"
}

teardown () {
    rm -f "$exdInputFileName"
    rm -f "$extractDeliverableChoiceCacheFile"
    rm -rf "$extractedProjectDir"
}

create_tf_app () {
    create-app.sh "$1" 2>&1
}

extract_deliverable () {
    "$exdScriptPath" "$1" 2>&1
}

# bats file_tags=type:functional, suite:extract-deliverable, iac:terraform, category:input-validation

@test "extract and exclude COIN scripts and use Make" {
    freshPull="n"
    includeEnv="n"
    deleteDeliverableDir="y"
    EXTRACT_BRANCH_NAME="main"
    includeMakefile="y"
    generateResolveScript="y"
    includeBuildScript="y"
    includeCicd="n"
    
    cd "$generatedAppDir"

    # Note that closing "EOF" cannot be indented
    cat <<EOF > "$exdInputFileName"
    {
        "freshPull": "$freshPull",
        "includeEnv": "$includeEnv",
        "includeCicd": "$includeCicd",
        "deleteDeliverableDir": "$deleteDeliverableDir",
        "EXTRACT_BRANCH_NAME": "$EXTRACT_BRANCH_NAME",
        "freshPullDir": "$freshPullDir",
        "DELIVERABLE_NAME": "$deliverableName",
        "deliverableParentDir": "$deliverableParentDir",
        "includeMakefile": "$includeMakefile",
        "generateResolveScript": "$generateResolveScript",
        "includeBuildScript": "$includeBuildScript"
    }
EOF

    run extract_deliverable "$exdInputFileName"

    # cat "$generatedAppEnvLogFile" >&3

    # Should extract project to the desired location
    assert_exists "$extractedProjectDir"

    # The extracted project should not include the environment directory since COIN scripts were excluded intentionally
    assert_not_exists "$extractedProjectEnvDir"

    # Should have a Makefile
    assert_exists "$extractedProjectDir/Makefile"

    # Should have IaC modules
    assert_exists "$extractedProjectDir/iac/roots/$firstIacModuleName"

    # Should create script to resolve all placeholders
    assert_exists "$extractedProjectDir/init.sh"

    # Verify that the user's Extract Deliverable Wizard choices were cached
    assert_exists "$extractDeliverableChoiceCacheFile"
    defaultFreshPull="$(jq -r '.defaultFreshPull' "$extractDeliverableChoiceCacheFile")"
    assert [ "$defaultFreshPull" == "$freshPull" ]
    defaultDeliverableName="$(jq -r '.defaultDeliverableName' "$extractDeliverableChoiceCacheFile")"
    assert [ "$defaultDeliverableName" == "$deliverableName" ]
    defaultDeliverableParentDir="$(jq -r '.defaultDeliverableParentDir' "$extractDeliverableChoiceCacheFile")"
    assert [ "$defaultDeliverableParentDir" == "$deliverableParentDir" ]
    defaultIncludeEnv="$(jq -r '.defaultIncludeEnv' "$extractDeliverableChoiceCacheFile")"
    assert [ "$defaultIncludeEnv" == "$includeEnv" ]
    defaultIncludeCicd="$(jq -r '.defaultIncludeCicd' "$extractDeliverableChoiceCacheFile")"
    assert [ "$defaultIncludeCicd" == "$includeCicd" ]
    defaultGenerateResolveScript="$(jq -r '.defaultGenerateResolveScript' "$extractDeliverableChoiceCacheFile")"
    assert [ "$defaultGenerateResolveScript" == "$generateResolveScript" ]
    defaultIncludeMakefile="$(jq -r '.defaultIncludeMakefile' "$extractDeliverableChoiceCacheFile")"
    assert [ "$defaultIncludeMakefile" == "$includeMakefile" ]
    defaultIncludeBuildScript="$(jq -r '.defaultIncludeBuildScript' "$extractDeliverableChoiceCacheFile")"
    assert [ "$defaultIncludeBuildScript" == "$includeBuildScript" ]

    # Should resolve CUR_DIR_NAME in backend.tf file
    run cat "$extractedProjectDir/iac/roots/$firstIacModuleName/backend.tf"
    assert_output --partial "/$firstIacModuleName/terraform.tfstate"

    cd -
}

@test "extract and include COIN scripts" {
    freshPull="n"
    includeEnv="y"
    deleteDeliverableDir="y"
    EXTRACT_BRANCH_NAME="main"
    includeMakefile="y"
    generateResolveScript="n"
    includeBuildScript="y"
    includeCicd="n"

    cd "$generatedAppDir"

    # Note that closing "EOF" cannot be indented
    cat <<EOF > "$exdInputFileName"
    {
        "freshPull": "$freshPull",
        "includeEnv": "$includeEnv",
        "includeCicd": "$includeCicd",
        "deleteDeliverableDir": "$deleteDeliverableDir",
        "EXTRACT_BRANCH_NAME": "$EXTRACT_BRANCH_NAME",
        "freshPullDir": "$freshPullDir",
        "DELIVERABLE_NAME": "$deliverableName",
        "deliverableParentDir": "$deliverableParentDir",
        "includeMakefile": "$includeMakefile",
        "generateResolveScript": "$generateResolveScript",
        "includeBuildScript": "$includeBuildScript"
    }
EOF

    run extract_deliverable "$exdInputFileName"

    # useful for debugging:
    # cat "$generatedAppEnvLogFile" >&3
    # echo "ls of $extractedProjectDir" >&3
    # ls -la $extractedProjectDir/environment >&3

    # Should extract project to the desired location
    assert_exists "$extractedProjectDir"

    # The extracted project should include the 'environment' directory since COIN scripts were included
    assert_exists "$extractedProjectEnvDir"

    # Should have a Makefile
    assert_exists "$extractedProjectDir/Makefile"

    # Should have IaC modules
    assert_exists "$extractedProjectDir/iac/roots/$firstIacModuleName"

    # Should exclude script to resolve all placeholders
    assert_not_exists "$extractedProjectDir/init.sh"

    # Should not resolve CUR_DIR_NAME placeholder in backend.tf file
    run cat "$extractedProjectDir/iac/roots/$firstIacModuleName/backend.tf"
    assert_output --partial "CUR_DIR_NAME"

    # should have a default environment json file
    assert_exists "$defaultEnvironmentJsonFile"
    defaultEnvAppName="$(jq -r '.APP_NAME' "$defaultEnvironmentJsonFile")"
    assert [ "$defaultEnvAppName" == "blank" ]
    defaultEnvAccount="$(jq -r '.AWS_ACCOUNT_ID' "$defaultEnvironmentJsonFile")"
    assert [ "$defaultEnvAccount" == "blank" ]
    defaultEnvRegion="$(jq -r '.AWS_DEFAULT_REGION' "$defaultEnvironmentJsonFile")"
    assert [ "$defaultEnvRegion" == "blank" ]
    defaultEnvName="$(jq -r '.ENV_NAME' "$defaultEnvironmentJsonFile")"
    assert [ "$defaultEnvName" == "blank" ]
    defaultEnvRemoteLoc="$(jq -r '.REMOTE_ENV_VAR_LOC' "$defaultEnvironmentJsonFile")"
    assert [ "$defaultEnvRemoteLoc" == "na" ]
    defaultEnvCreatedBy="$(jq -r '.CREATED_BY' "$defaultEnvironmentJsonFile")"
    assert [ "$defaultEnvCreatedBy" == "blank" ]
    defaultEnvTfBackend="$(jq -r '.TF_S3_BACKEND_NAME' "$defaultEnvironmentJsonFile")"
    assert [ "$defaultEnvTfBackend" == "blank" ]

    run cat "$extractedProjectEnvDir/.current-environment"
    assert_output --partial "default"

    cd -
}