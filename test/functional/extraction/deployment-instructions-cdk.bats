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
        "iac": "cdk2",
        "REMOTE_ENV_VAR_LOC": "na",
        "APP_NAME": "cbat",
        "AWS_DEFAULT_REGION": "us-east-1",
        "CREATED_BY": "Anthony Watson",
        "ENV_NAME": "dev",
        "firstIacModuleName": "$firstIacModuleName",
        "gitProjectName": "$gitProjectName",
        "TF_S3_BACKEND_NAME": "blank"
    }
EOF

    # use for debugging:
    # cat $inputFileName >&3

    run create_tf_app "$inputFileName"
    
    assert_output --partial "Congratulations! Your application has been created at ${generatedAppDir}"
    assert_output --partial "A CDK v2 module has been created for you under your project's /iac/roots/${firstIacModuleName} directory"
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
    gdiInputFileName="/tmp/gdi-tf-headless-input.json" # gdi = "generate deployment instructions"
    gdiScriptPath="${generatedAppDir}/environment/generate-deployment-instructions.sh"
}

teardown () {
    :
}

create_tf_app () {
    create-app.sh "$1" 2>&1
}

generate_deployment_instructions () {
    "$gdiScriptPath" "$1" 2>&1
}

# bats file_tags=type:functional, suite:generate-deployment-instructions, iac:cdk2

@test "generate COIN deployment instructions" {
    instructionsFileName="DEPLOYMENT_WITH_COIN.md"

    # Note that closing "EOF" cannot be indented
    cat <<EOF > "$gdiInputFileName"
    {
        "isUseCoinForDeployment": "y",
        "includeMakefile": "n",
        "instructionsFileName": "$instructionsFileName"
    }
EOF

    run generate_deployment_instructions "$gdiInputFileName"
    assert_output --partial "Congratulations! The deployment instructions have been written"
    assert_exists "$generatedAppDir/$instructionsFileName"

    run cat "$generatedAppDir/$instructionsFileName" >&3

    assert_output --partial "Prerequisites"
    assert_output --partial "# Configuring CDK input variables"
    assert_output --partial "# Approach"
    assert_output --partial "# Input variable names used in the prototype and their meanings"
    assert_output --partial "12 digit AWS account ID to deploy resources to"
    assert_output --partial "# Running the CDK"    
}

@test "generate deployment instructions for app without COIN scripts but with a Makefile" {
    instructionsFileName="DEPLOYMENT_WITH_NO_COIN_WITH_MAKE.md"

    # Note that closing "EOF" cannot be indented
    cat <<EOF > "$gdiInputFileName"
    {
        "isUseCoinForDeployment": "n",
        "includeMakefile": "y",
        "instructionsFileName": "$instructionsFileName"
    }
EOF

    run generate_deployment_instructions "$gdiInputFileName"
    assert_output --partial "Congratulations! The deployment instructions have been written"
    assert_exists "$generatedAppDir/$instructionsFileName"

    run cat "$generatedAppDir/$instructionsFileName" >&3

    assert_output --partial "Prerequisites"
    assert_output --partial "# Configuring CDK input variables"
    assert_output --partial "# Input variable names used in the prototype and their meanings"
    assert_output --partial "12 digit AWS account ID to deploy resources to"
    assert_output --partial "# Configuring and deploying the solution for the first time"
    assert_output --partial "make init"
    
}

@test "generate deployment instructions for app without COIN and without a Makefile" {
    instructionsFileName="DEPLOYMENT_WITH_NO_COIN_WITH_NO_MAKE.md"

    # Note that closing "EOF" cannot be indented
    cat <<EOF > "$gdiInputFileName"
    {
        "isUseCoinForDeployment": "n",
        "includeMakefile": "n",
        "instructionsFileName": "$instructionsFileName"
    }
EOF

    run generate_deployment_instructions "$gdiInputFileName"
    assert_output --partial "Congratulations! The deployment instructions have been written"
    assert_exists "$generatedAppDir/$instructionsFileName"

    run cat "$generatedAppDir/$instructionsFileName" >&3

    assert_output --partial "Prerequisites"
    assert_output --partial "# Configuring CDK input variables"
    assert_output --partial "# Input variable names used in the prototype and their meanings"
    assert_output --partial "12 digit AWS account ID to deploy resources to"
    assert_output --partial "# Setting the variable values"
    assert_output --partial "# Running the CDK"

}