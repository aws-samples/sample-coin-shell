#!/usr/bin/env bats

setup_file () {
    load '../../test-helper/common-setup'
    _common_setup

    appParentDir="/tmp/"
    gitProjectName="bats-cdk-local-deploy-nothing"
    generatedAppDir="${appParentDir}${gitProjectName}"
    inputFileName="/tmp/create-cdk-app-headless-input.json"
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

    run create_cdk_app "$inputFileName"
    
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
    gitProjectName="bats-cdk-local-deploy-nothing"
    generatedAppDir="${appParentDir}${gitProjectName}"
    generatedAppEnvDir="${generatedAppDir}/environment"
    generatedAppEnvLogFile="${generatedAppEnvDir}/.log.txt"
    iacDir="${generatedAppDir}/iac"
    iacRootsDir="${iacDir}/roots"
    createAppIacModuleLogFile="$generatedAppDir/environment/.log.txt"
    createAppIacModuleInputFileName="/tmp/create-cdk-app-iac-module-headless-input.json"
    generateIacModuleScriptPath="${generatedAppDir}/environment/create-iac-module.sh"
}

teardown () {
    :
}

create_cdk_app () {
    create-app.sh "$1" 2>&1
}

create_cdk_app_iac_module () {
    "$generateIacModuleScriptPath" "$1" 2>&1
}

# bats file_tags=type:functional, suite:create-app-environment, generate:iac-module

@test "create cdk app iac module" {
    newIacModuleName="new-module"
    newIacModuleNestedPath="iac/roots/nested1/nested2"
    newIacMakeModuleName="nested1-nested2-${newIacModuleName}"

    # Note that closing "EOF" cannot be indented
    cat <<EOF > "$createAppIacModuleInputFileName"
    {
        "newIacModuleName": "$newIacModuleName",
        "newIacModuleNestedPath": "$newIacModuleNestedPath"
    }
EOF

    # cat "$createAppIacModuleInputFileName" >&3

    run create_cdk_app_iac_module "$createAppIacModuleInputFileName"

    assert_exists "$generatedAppDir/$newIacModuleNestedPath/$newIacModuleName"
    assert_exists "$generatedAppDir/$newIacModuleNestedPath/$newIacModuleName/package.json"

    run cat "$generatedAppDir/Makefile"
    assert_output --partial "diff-$newIacMakeModuleName"
    assert_output --partial "deploy-$newIacMakeModuleName"
    assert_output --partial "destroy-$newIacMakeModuleName"

    run cat "$generatedAppDir/Makefile-4-customer"
    assert_output --partial "deploy-$newIacMakeModuleName"
    assert_output --partial "destroy-$newIacMakeModuleName"

    # use for debugging:
    # echo -e "\n\n\n" >&3
    # cat "$createAppIacModuleLogFile" >&3
}