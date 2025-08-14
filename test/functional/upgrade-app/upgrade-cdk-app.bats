#!/usr/bin/env bats

setup_file () {
    :
    # echo '# Hello there from setup_file' >&3
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
    inputFileName="/tmp/create-cdk-app-headless-input.json"
    firstIacModuleName="example"
    envName="dev"
    appName="cbat"
    accountId="000000000000"
    defaultRegion="us-east-1"
    remoteLoc="na"
    createdBy="Anthony Watson"
}

teardown () {
    rm -f "$inputFileName"
    rm -rf "$generatedAppDir"
}

create_cdk_app () {
    create-app.sh "$1" 2>&1
}

get_last_line_of_file () {
    tail -1 $1 2>&1
}

upgrade_coin () {
    make uc 2>&1
}

# bats file_tags=type:functional, suite:create-app, iac:cdk2

@test "CDK app upgrade should not modify files that may have changed during app development" {
    
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
        "AWS_ACCOUNT_ID": "$accountId",
        "iac": "cdk2",
        "REMOTE_ENV_VAR_LOC": "$remoteLoc",
        "APP_NAME": "$appName",
        "AWS_DEFAULT_REGION": "$defaultRegion",
        "CREATED_BY": "$createdBy",
        "ENV_NAME": "$envName",
        "firstIacModuleName": "$firstIacModuleName",
        "gitProjectName": "$gitProjectName",
        "TF_S3_BACKEND_NAME": "blank"
    }
EOF

    # use for debugging:
    # cat $inputFileName >&3

    assert_not_exists "$generatedAppDir"

    run create_cdk_app "$inputFileName"
    
    assert_success
    assert_output --partial "Congratulations! Your application has been created at ${generatedAppDir}"
    assert_exists "$generatedAppDir"
    assert_exists "$generatedAppEnvDir"

    cd "$generatedAppDir" 

    # First we add a new line to each file in the application that we want to verify is not changed by the upgrade.
    # Next, we run the upgrade and we check that our new line is still there, meaning that the upgrade did not overwrite
    # the file.

    assert_exists README.md
    echo "bats-upgrade-marker" >> README.md

    assert_exists environment/.current-environment
    cp environment/.current-environment environment/original-current-environment
    echo "bats-upgrade-marker" > environment/.current-environment
    cp "environment/.environment-$envName.json" "environment/.environment-bats-upgrade-marker.json"

    assert_exists environment/dynamic-lookups.sh
    echo "#bats-upgrade-marker" >> environment/dynamic-lookups.sh

    assert_exists environment/app-env-var-names.txt
    echo "#bats-upgrade-marker" >> environment/app-env-var-names.txt

    assert_exists "environment/.environment-$envName.json"
    jq '. + {"bats-upgrade-marker": "true"}' "environment/.environment-$envName.json" > temp.json && mv temp.json "environment/.environment-$envName.json"

    assert_exists Makefile
    echo "#bats-upgrade-marker" >> Makefile

    assert_exists Makefile-4-customer
    echo "#bats-upgrade-marker" >> Makefile-4-customer

    assert_exists "iac/roots/$firstIacModuleName/package.json"
    jq '. + {"bats-upgrade-marker": "true"}' "iac/roots/$firstIacModuleName/package.json" > temp.json && mv temp.json "iac/roots/$firstIacModuleName/package.json"

    # Update the environment/coin-app-version file so we can check that it did get updated by the upgrade
    echo "bats-upgrade-marker" > "environment/coin-app-version"

    # run make puc 2>&1
    # echo "$output" >&3

    # run the upgrade
    export COIN_HOME="$COIN_ROOT_DIR"
    export HEADLESS="y"
    run upgrade_coin
    assert_success
    
    # cat "$generatedAppEnvLogFile"  >&3

    # Verify that our changes have not been overwritten

    envJsonUpgradeMarker="$(jq -r '."bats-upgrade-marker"' "environment/.environment-$envName.json")"
    assert [ "$envJsonUpgradeMarker" == "true" ]
    packageJsonUpgradeMarker="$(jq -r '."bats-upgrade-marker"' "iac/roots/$firstIacModuleName/package.json")"
    assert [ "$packageJsonUpgradeMarker" == "true" ]

    run get_last_line_of_file "README.md"
    assert [ "$output" == "bats-upgrade-marker" ]
    run get_last_line_of_file "environment/.current-environment"
    assert [ "$output" == "bats-upgrade-marker" ]
    run get_last_line_of_file "environment/dynamic-lookups.sh"
    assert [ "$output" == "#bats-upgrade-marker" ]
    run get_last_line_of_file "environment/app-env-var-names.txt"
    assert [ "$output" == "#bats-upgrade-marker" ]
    run get_last_line_of_file "Makefile"
    assert [ "$output" == "#bats-upgrade-marker" ]
    run get_last_line_of_file "Makefile-4-customer"
    assert [ "$output" == "#bats-upgrade-marker" ]
    
    run get_last_line_of_file "environment/coin-app-version"
    assert [ "$output" != "bats-upgrade-marker" ]

    # cat "environment/coin-app-version" >&3

    cd -
}
