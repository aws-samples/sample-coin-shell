#!/usr/bin/env bats

setup_file () {
    :
    # echo '# Hello there from setup_file' >&3
}

setup () {
    load '../../../test-helper/common-setup'
    _common_setup

    source "$COIN_ROOT_DIR/environment/aws-regions.sh"

    inputFileName="/tmp/coin-input-validation.json"
}

teardown () {
    rm -f "$inputFileName"
}

# Returns the input validation error message only
# Example:
#   ERROR: "APP_NAME" value is invalid: "aReallyLongInvalidValue".
get_input_validation_error_message() {
    # The sed pattern below gets rid of ANSI color codes in the output. These hidden characters will cause
    # assertions on the output to fail
    create-app.sh "$1" 2>&1 | grep "ERROR:" | sed -e 's/\x1b\[[0-9;]*m//g'
}

# Returns the input validation error message on one line and the reason the validation failed on the next line
# Example:
#   ERROR: "APP_NAME" value is invalid: "aReallyLongInvalidValue".
#   Must not include whitespace and length (23) must be between 1 and 10.
get_input_validation_full_error_message() {
    # The sed pattern below gets rid of ANSI color codes in the output. These hidden characters will cause
    # assertions on the output to fail
    create-app.sh "$1" 2>&1 | grep -A 1 "ERROR:" | sed -e 's/\x1b\[[0-9;]*m//g'
}

# bats file_tags=type:functional, suite:create-app, generate:app, category:input-validation

@test "detect structurally invalid json" {
    echo '{ should contain double-quoted key-value pairs }' > "$inputFileName"

    run get_input_validation_error_message "$inputFileName"
    assert_output 'ERROR: Headless input contains structurally invalid JSON'
}

@test "detects appParentDir is missing" {
    echo '{}' > "$inputFileName"

    run get_input_validation_error_message "$inputFileName"
    assert_output 'ERROR: invalid value "" for "appParentDir"'
}

@test "detects createRemoteGitRepo is missing" {
    echo '{"appParentDir": "/tmp/"}' > "$inputFileName"

    run get_input_validation_error_message "$inputFileName"
    assert_output 'ERROR: "createRemoteGitRepo" must be "y" or "n" but was ""'
}

@test "detects createRemoteGitRepo is invalid" {
    echo '{"appParentDir": "/tmp/", "createRemoteGitRepo": "invalidValue"}' > "$inputFileName"

    run get_input_validation_error_message "$inputFileName"
    assert_output 'ERROR: "createRemoteGitRepo" must be "y" or "n" but was "invalidValue"'
}

@test "detects deployCdk2Backend is missing" {
    echo '{"appParentDir": "/tmp/", "createRemoteGitRepo": "n"}' > "$inputFileName"

    run get_input_validation_error_message "$inputFileName"
    assert_output 'ERROR: "deployCdk2Backend" must be "y" or "n" but was ""'
}

@test "detects deployCicdResources is missing" {
    # Note that closing "EOF" cannot be indented
    cat <<EOF > "$inputFileName"
    {
        "appParentDir": "/tmp/",
        "createRemoteGitRepo": "n",
        "deployCdk2Backend": "n"
    }
EOF

    run get_input_validation_error_message "$inputFileName"
    assert_output 'ERROR: "deployCicdResources" must be "y" or "n" but was ""'
}

@test "detects deployRemoteEnvVars is missing" {
    # Note that closing "EOF" cannot be indented
    cat <<EOF > "$inputFileName"
    {
        "appParentDir": "/tmp/",
        "createRemoteGitRepo": "n",
        "deployCdk2Backend": "n",
        "deployCicdResources": "n"
    }
EOF

    run get_input_validation_error_message "$inputFileName"
    assert_output 'ERROR: "deployRemoteEnvVars" must be "y" or "n" but was ""'
}

@test "detects deployTfBackend is missing" {
    # Note that closing "EOF" cannot be indented
    cat <<EOF > "$inputFileName"
    {
        "appParentDir": "/tmp/",
        "createRemoteGitRepo": "n",
        "deployCdk2Backend": "n",
        "deployCicdResources": "n",
        "deployRemoteEnvVars": "n"
    }
EOF

    run get_input_validation_error_message "$inputFileName"
    assert_output 'ERROR: "deployTfBackend" must be "y" or "n" but was ""'
}

@test "detects useCicd is missing" {
    # Note that closing "EOF" cannot be indented
    cat <<EOF > "$inputFileName"
    {
        "appParentDir": "/tmp/",
        "createRemoteGitRepo": "n",
        "deployCdk2Backend": "n",
        "deployCicdResources": "n",
        "deployRemoteEnvVars": "n",
        "deployTfBackend": "n"
    }
EOF

    run get_input_validation_error_message "$inputFileName"
    assert_output 'ERROR: "useCicd" must be "y" or "n" but was ""'
}

@test "detects hasSecondaryRegion is missing" {
    # Note that closing "EOF" cannot be indented
    cat <<EOF > "$inputFileName"
    {
        "appParentDir": "/tmp/",
        "createRemoteGitRepo": "n",
        "deployCdk2Backend": "n",
        "deployCicdResources": "n",
        "deployRemoteEnvVars": "n",
        "deployTfBackend": "n",
        "useCicd": "n"
    }
EOF

    run get_input_validation_error_message "$inputFileName"
    assert_output 'ERROR: "hasSecondaryRegion" must be "y" or "n" but was ""'
}

@test "detects AWS_SECONDARY_REGION is missing when hasSecondaryRegion is yes" {
    # Note that closing "EOF" cannot be indented
    cat <<EOF > "$inputFileName"
    {
        "appParentDir": "/tmp/",
        "createRemoteGitRepo": "n",
        "deployCdk2Backend": "n",
        "deployCicdResources": "n",
        "deployRemoteEnvVars": "n",
        "deployTfBackend": "n",
        "useCicd": "n",
        "hasSecondaryRegion": "y",
        "AWS_ACCOUNT_ID": "000000000000",
        "iac": "cdk2",
        "REMOTE_ENV_VAR_LOC": "na",
        "APP_NAME": "demo",
        "AWS_DEFAULT_REGION": "us-east-1"
    }
EOF

    # use for debugging:
    # cat $inputFileName >&3

    run get_input_validation_error_message "$inputFileName"
    assert_output 'ERROR: "AWS_SECONDARY_REGION" should be set if "hasSecondaryRegion" is set to "y".'
}

@test "detects AWS_SECONDARY_REGION is blank when hasSecondaryRegion is yes" {
    # Note that closing "EOF" cannot be indented
    cat <<EOF > "$inputFileName"
    {
        "appParentDir": "/tmp/",
        "createRemoteGitRepo": "n",
        "deployCdk2Backend": "n",
        "deployCicdResources": "n",
        "deployRemoteEnvVars": "n",
        "deployTfBackend": "n",
        "useCicd": "n",
        "hasSecondaryRegion": "y",
        "AWS_ACCOUNT_ID": "000000000000",
        "iac": "cdk2",
        "REMOTE_ENV_VAR_LOC": "na",
        "APP_NAME": "demo",
        "AWS_DEFAULT_REGION": "us-east-1",
        "AWS_SECONDARY_REGION": "blank"
    }
EOF

    # use for debugging:
    # cat $inputFileName >&3

    run get_input_validation_error_message "$inputFileName"
    assert_output 'ERROR: "AWS_SECONDARY_REGION" should be set if "hasSecondaryRegion" is set to "y".'
}

@test "detects AWS_SECONDARY_REGION is invalid when hasSecondaryRegion is yes" {
    invalidValue="fake-region"

    # Note that closing "EOF" cannot be indented
    cat <<EOF > "$inputFileName"
    {
        "appParentDir": "/tmp/",
        "createRemoteGitRepo": "n",
        "deployCdk2Backend": "n",
        "deployCicdResources": "n",
        "deployRemoteEnvVars": "n",
        "deployTfBackend": "n",
        "useCicd": "n",
        "hasSecondaryRegion": "y",
        "AWS_ACCOUNT_ID": "000000000000",
        "iac": "cdk2",
        "REMOTE_ENV_VAR_LOC": "na",
        "APP_NAME": "demo",
        "AWS_DEFAULT_REGION": "us-east-1",
        "AWS_SECONDARY_REGION": "$invalidValue"
    }
EOF

    # use for debugging:
    # cat $inputFileName >&3

    run get_input_validation_full_error_message "$inputFileName"

    assert_line --index 0 "ERROR: \"AWS_SECONDARY_REGION\" value is invalid: \"$invalidValue\"."
    assert_line --index 1 "Must be one of the following values: $awsJoinedRegionCodes"
}

@test "detects AWS_SECONDARY_REGION is not blank when hasSecondaryRegion is no" {
    # Note that closing "EOF" cannot be indented
    cat <<EOF > "$inputFileName"
    {
        "appParentDir": "/tmp/",
        "createRemoteGitRepo": "n",
        "deployCdk2Backend": "n",
        "deployCicdResources": "n",
        "deployRemoteEnvVars": "n",
        "deployTfBackend": "n",
        "useCicd": "n",
        "hasSecondaryRegion": "n"
    }
EOF

    run get_input_validation_error_message "$inputFileName"
    assert_output 'ERROR: "AWS_SECONDARY_REGION" should be set to "blank" if "hasSecondaryRegion" is set to "n".'
}

@test "detects AWS_ACCOUNT_ID is missing" {
    # Note that closing "EOF" cannot be indented
    cat <<EOF > "$inputFileName"
    {
        "appParentDir": "/tmp/",
        "createRemoteGitRepo": "n",
        "deployCdk2Backend": "n",
        "deployCicdResources": "n",
        "deployRemoteEnvVars": "n",
        "deployTfBackend": "n",
        "useCicd": "n",
        "hasSecondaryRegion": "n",
        "AWS_SECONDARY_REGION": "blank"
    }
EOF

    run get_input_validation_error_message "$inputFileName"
    assert_output 'ERROR: invalid "AWS_ACCOUNT_ID" value: "". Must be a 12-digit number.'
}

@test "detects AWS_ACCOUNT_ID is invalid" {
    # Note that closing "EOF" cannot be indented
    cat <<EOF > "$inputFileName"
    {
        "appParentDir": "/tmp/",
        "createRemoteGitRepo": "n",
        "deployCdk2Backend": "n",
        "deployCicdResources": "n",
        "deployRemoteEnvVars": "n",
        "deployTfBackend": "n",
        "useCicd": "n",
        "hasSecondaryRegion": "y",
        "AWS_SECONDARY_REGION": "us-west-2",
        "AWS_ACCOUNT_ID": "invalidAccountId"
    }
EOF

    run get_input_validation_error_message "$inputFileName"
    assert_output 'ERROR: invalid "AWS_ACCOUNT_ID" value: "invalidAccountId". Must be a 12-digit number.'
}

@test "detects iac is missing" {
    # Note that closing "EOF" cannot be indented
    cat <<EOF > "$inputFileName"
    {
        "appParentDir": "/tmp/",
        "createRemoteGitRepo": "n",
        "deployCdk2Backend": "n",
        "deployCicdResources": "n",
        "deployRemoteEnvVars": "n",
        "deployTfBackend": "n",
        "useCicd": "n",
        "hasSecondaryRegion": "y",
        "AWS_SECONDARY_REGION": "us-west-2",
        "AWS_ACCOUNT_ID": "000000000000"
    }
EOF

    run get_input_validation_error_message "$inputFileName"
    assert_output 'ERROR: invalid "iac" value: "". Must be "terraform" or "cdk2" or "cf".'
}

@test "detects iac is invalid" {
    # Note that closing "EOF" cannot be indented
    cat <<EOF > "$inputFileName"
    {
        "appParentDir": "/tmp/",
        "createRemoteGitRepo": "n",
        "deployCdk2Backend": "n",
        "deployCicdResources": "n",
        "deployRemoteEnvVars": "n",
        "deployTfBackend": "n",
        "useCicd": "n",
        "hasSecondaryRegion": "y",
        "AWS_SECONDARY_REGION": "us-west-2",
        "AWS_ACCOUNT_ID": "000000000000",
        "iac": "invalidValue"
    }
EOF

    run get_input_validation_error_message "$inputFileName"
    assert_output 'ERROR: invalid "iac" value: "invalidValue". Must be "terraform" or "cdk2" or "cf".'
}

@test "detects REMOTE_ENV_VAR_LOC is missing" {
    # Note that closing "EOF" cannot be indented
    cat <<EOF > "$inputFileName"
    {
        "appParentDir": "/tmp/",
        "createRemoteGitRepo": "n",
        "deployCdk2Backend": "n",
        "deployCicdResources": "n",
        "deployRemoteEnvVars": "n",
        "deployTfBackend": "n",
        "useCicd": "n",
        "hasSecondaryRegion": "y",
        "AWS_SECONDARY_REGION": "us-west-2",
        "AWS_ACCOUNT_ID": "000000000000",
        "iac": "cdk2"
    }
EOF

    run get_input_validation_error_message "$inputFileName"
    assert_output 'ERROR: invalid "REMOTE_ENV_VAR_LOC" value: "". Must be "ssm" or "gitlab" or "na".'
}

@test "detects REMOTE_ENV_VAR_LOC is invalid" {
    # Note that closing "EOF" cannot be indented
    cat <<EOF > "$inputFileName"
    {
        "appParentDir": "/tmp/",
        "createRemoteGitRepo": "n",
        "deployCdk2Backend": "n",
        "deployCicdResources": "n",
        "deployRemoteEnvVars": "n",
        "deployTfBackend": "n",
        "useCicd": "n",
        "hasSecondaryRegion": "y",
        "AWS_SECONDARY_REGION": "us-west-2",
        "AWS_ACCOUNT_ID": "000000000000",
        "iac": "cdk2",
        "REMOTE_ENV_VAR_LOC": "invalidValue"
    }
EOF

    run get_input_validation_error_message "$inputFileName"
    assert_output 'ERROR: invalid "REMOTE_ENV_VAR_LOC" value: "invalidValue". Must be "ssm" or "gitlab" or "na".'
}

@test "detects APP_NAME is missing" {
    # Note that closing "EOF" cannot be indented
    cat <<EOF > "$inputFileName"
    {
        "appParentDir": "/tmp/",
        "createRemoteGitRepo": "n",
        "deployCdk2Backend": "n",
        "deployCicdResources": "n",
        "deployRemoteEnvVars": "n",
        "deployTfBackend": "n",
        "useCicd": "n",
        "hasSecondaryRegion": "y",
        "AWS_SECONDARY_REGION": "us-west-2",
        "AWS_ACCOUNT_ID": "000000000000",
        "iac": "cdk2",
        "REMOTE_ENV_VAR_LOC": "na"
    }
EOF

    run get_input_validation_error_message "$inputFileName"
    assert_output 'ERROR: "APP_NAME" value is invalid: "".'
}

@test "detects APP_NAME is too long" {
    longValue="aReallyLongInvalidValue"

    # Note that closing "EOF" cannot be indented
    cat <<EOF > "$inputFileName"
    {
        "appParentDir": "/tmp/",
        "createRemoteGitRepo": "n",
        "deployCdk2Backend": "n",
        "deployCicdResources": "n",
        "deployRemoteEnvVars": "n",
        "deployTfBackend": "n",
        "useCicd": "n",
        "hasSecondaryRegion": "y",
        "AWS_SECONDARY_REGION": "us-west-2",
        "AWS_ACCOUNT_ID": "000000000000",
        "iac": "cdk2",
        "REMOTE_ENV_VAR_LOC": "na",
        "APP_NAME": "$longValue"
    }
EOF

    # use for debugging:
    # cat $inputFileName >&3

    run get_input_validation_full_error_message "$inputFileName"

    assert_line --index 0 "ERROR: \"APP_NAME\" value is invalid: \"$longValue\"."
    assert_line --index 1 "Must not include whitespace and length (${#longValue}) must be between 1 and 10."
}

@test "detects APP_NAME contains whitespace" {
    valueWithWhitespace="app name"

    # Note that closing "EOF" cannot be indented
    cat <<EOF > "$inputFileName"
    {
        "appParentDir": "/tmp/",
        "createRemoteGitRepo": "n",
        "deployCdk2Backend": "n",
        "deployCicdResources": "n",
        "deployRemoteEnvVars": "n",
        "deployTfBackend": "n",
        "useCicd": "n",
        "hasSecondaryRegion": "y",
        "AWS_SECONDARY_REGION": "us-west-2",
        "AWS_ACCOUNT_ID": "000000000000",
        "iac": "cdk2",
        "REMOTE_ENV_VAR_LOC": "na",
        "APP_NAME": "$valueWithWhitespace"
    }
EOF

    # use for debugging:
    # cat $inputFileName >&3

    run get_input_validation_full_error_message "$inputFileName"

    assert_line --index 0 "ERROR: \"APP_NAME\" value is invalid: \"$valueWithWhitespace\"."
    assert_line --index 1 "Must not include whitespace and length (${#valueWithWhitespace}) must be between 1 and 10."
}

@test "detects AWS_DEFAULT_REGION is missing" {
    # Note that closing "EOF" cannot be indented
    cat <<EOF > "$inputFileName"
    {
        "appParentDir": "/tmp/",
        "createRemoteGitRepo": "n",
        "deployCdk2Backend": "n",
        "deployCicdResources": "n",
        "deployRemoteEnvVars": "n",
        "deployTfBackend": "n",
        "useCicd": "n",
        "hasSecondaryRegion": "y",
        "AWS_SECONDARY_REGION": "us-west-2",
        "AWS_ACCOUNT_ID": "000000000000",
        "iac": "cdk2",
        "REMOTE_ENV_VAR_LOC": "na",
        "APP_NAME": "demo"
    }
EOF

    run get_input_validation_error_message "$inputFileName"
    assert_output 'ERROR: "AWS_DEFAULT_REGION" value is invalid: "".'
}

@test "detects AWS_DEFAULT_REGION is invalid" {
    invalidValue="fake-region"

    # Note that closing "EOF" cannot be indented
    cat <<EOF > "$inputFileName"
    {
        "appParentDir": "/tmp/",
        "createRemoteGitRepo": "n",
        "deployCdk2Backend": "n",
        "deployCicdResources": "n",
        "deployRemoteEnvVars": "n",
        "deployTfBackend": "n",
        "useCicd": "n",
        "hasSecondaryRegion": "y",
        "AWS_SECONDARY_REGION": "us-west-2",
        "AWS_ACCOUNT_ID": "000000000000",
        "iac": "cdk2",
        "REMOTE_ENV_VAR_LOC": "na",
        "APP_NAME": "demo",
        "AWS_DEFAULT_REGION": "$invalidValue"
    }
EOF

    # use for debugging:
    # cat $inputFileName >&3

    run get_input_validation_full_error_message "$inputFileName"

    assert_line --index 0 "ERROR: \"AWS_DEFAULT_REGION\" value is invalid: \"$invalidValue\"."
    assert_line --index 1 "Must be one of the following values: $awsJoinedRegionCodes"
}

@test "detects CREATED_BY is missing" {
    # Note that closing "EOF" cannot be indented
    cat <<EOF > "$inputFileName"
    {
        "appParentDir": "/tmp/",
        "createRemoteGitRepo": "n",
        "deployCdk2Backend": "n",
        "deployCicdResources": "n",
        "deployRemoteEnvVars": "n",
        "deployTfBackend": "n",
        "useCicd": "n",
        "hasSecondaryRegion": "y",
        "AWS_SECONDARY_REGION": "us-west-2",
        "AWS_ACCOUNT_ID": "000000000000",
        "iac": "cdk2",
        "REMOTE_ENV_VAR_LOC": "na",
        "APP_NAME": "demo",
        "AWS_DEFAULT_REGION": "us-east-1"
    }
EOF

    # use for debugging:
    # cat $inputFileName >&3

    run get_input_validation_full_error_message "$inputFileName"

    assert_line --index 0 'ERROR: "CREATED_BY" value is invalid: "".'
    assert_line --index 1 "Length (0) must be between 1 and 90."
}

@test "detects ENV_NAME is missing" {
    # Note that closing "EOF" cannot be indented
    cat <<EOF > "$inputFileName"
    {
        "appParentDir": "/tmp/",
        "createRemoteGitRepo": "n",
        "deployCdk2Backend": "n",
        "deployCicdResources": "n",
        "deployRemoteEnvVars": "n",
        "deployTfBackend": "n",
        "useCicd": "n",
        "hasSecondaryRegion": "y",
        "AWS_SECONDARY_REGION": "us-west-2",
        "AWS_ACCOUNT_ID": "000000000000",
        "iac": "cdk2",
        "REMOTE_ENV_VAR_LOC": "na",
        "APP_NAME": "demo",
        "AWS_DEFAULT_REGION": "us-east-1",
        "CREATED_BY": "Anthony Watson"

    }
EOF

    # use for debugging:
    # cat $inputFileName >&3

    run get_input_validation_full_error_message "$inputFileName"

    assert_line --index 0 'ERROR: "ENV_NAME" value is invalid: "".'
    assert_line --index 1 "Must not include whitespace and length (0) must be between 1 and 6."
}

@test "detects firstIacModuleName is missing" {
    # Note that closing "EOF" cannot be indented
    cat <<EOF > "$inputFileName"
    {
        "appParentDir": "/tmp/",
        "createRemoteGitRepo": "n",
        "deployCdk2Backend": "n",
        "deployCicdResources": "n",
        "deployRemoteEnvVars": "n",
        "deployTfBackend": "n",
        "useCicd": "n",
        "hasSecondaryRegion": "y",
        "AWS_SECONDARY_REGION": "us-west-2",
        "AWS_ACCOUNT_ID": "000000000000",
        "iac": "cdk2",
        "REMOTE_ENV_VAR_LOC": "na",
        "APP_NAME": "demo",
        "AWS_DEFAULT_REGION": "us-east-1",
        "CREATED_BY": "Anthony Watson",
        "ENV_NAME": "dev"
    }
EOF

    # use for debugging:
    # cat $inputFileName >&3

    run get_input_validation_full_error_message "$inputFileName"

    assert_line --index 0 'ERROR: "firstIacModuleName" value is invalid: "".'
    assert_line --index 1 "Must not include whitespace and length (0) must be between 1 and 50."
}

@test "detects gitProjectName is missing" {
    # Note that closing "EOF" cannot be indented
    cat <<EOF > "$inputFileName"
    {
        "appParentDir": "/tmp/",
        "createRemoteGitRepo": "n",
        "deployCdk2Backend": "n",
        "deployCicdResources": "n",
        "deployRemoteEnvVars": "n",
        "deployTfBackend": "n",
        "useCicd": "n",
        "hasSecondaryRegion": "y",
        "AWS_SECONDARY_REGION": "us-west-2",
        "AWS_ACCOUNT_ID": "000000000000",
        "iac": "cdk2",
        "REMOTE_ENV_VAR_LOC": "na",
        "APP_NAME": "demo",
        "AWS_DEFAULT_REGION": "us-east-1",
        "CREATED_BY": "Anthony Watson",
        "ENV_NAME": "dev",
        "firstIacModuleName": "example"
    }
EOF

    # use for debugging:
    # cat $inputFileName >&3

    run get_input_validation_full_error_message "$inputFileName"

    assert_line --index 0 'ERROR: "gitProjectName" value is invalid: "".'
    assert_line --index 1 "Must not include whitespace and length (0) must be between 1 and 75."
}

@test "detects gitRepoProvider is missing" {
    # Note that closing "EOF" cannot be indented
    cat <<EOF > "$inputFileName"
    {
        "appParentDir": "/tmp/",
        "createRemoteGitRepo": "y",
        "deployCdk2Backend": "n",
        "deployCicdResources": "n",
        "deployRemoteEnvVars": "n",
        "deployTfBackend": "n",
        "useCicd": "n",
        "hasSecondaryRegion": "y",
        "AWS_SECONDARY_REGION": "us-west-2",
        "AWS_ACCOUNT_ID": "000000000000",
        "iac": "cdk2",
        "REMOTE_ENV_VAR_LOC": "na",
        "APP_NAME": "demo",
        "AWS_DEFAULT_REGION": "us-east-1",
        "CREATED_BY": "Anthony Watson",
        "ENV_NAME": "dev",
        "firstIacModuleName": "example",
        "gitProjectName": "bats-input-test"
    }
EOF

    # use for debugging:
    # cat $inputFileName >&3

    run get_input_validation_full_error_message "$inputFileName"

    assert_line --index 0 'ERROR: "gitRepoProvider" should be set if "createRemoteGitRepo" is set to "y".'
}

@test "detects gitRepoDomain is missing" {
    # Note that closing "EOF" cannot be indented
    cat <<EOF > "$inputFileName"
    {
        "appParentDir": "/tmp/",
        "createRemoteGitRepo": "y",
        "deployCdk2Backend": "n",
        "deployCicdResources": "n",
        "deployRemoteEnvVars": "n",
        "deployTfBackend": "n",
        "useCicd": "n",
        "hasSecondaryRegion": "y",
        "AWS_SECONDARY_REGION": "us-west-2",
        "AWS_ACCOUNT_ID": "000000000000",
        "iac": "cdk2",
        "REMOTE_ENV_VAR_LOC": "na",
        "APP_NAME": "demo",
        "AWS_DEFAULT_REGION": "us-east-1",
        "CREATED_BY": "Anthony Watson",
        "ENV_NAME": "dev",
        "firstIacModuleName": "example",
        "gitProjectName": "bats-input-test",
        "gitRepoProvider": "gitlab"
    }
EOF

    # use for debugging:
    # cat $inputFileName >&3

    run get_input_validation_full_error_message "$inputFileName"

    assert_line --index 0 'ERROR: "gitRepoDomain" should be set if "createRemoteGitRepo" is set to "y".'
}

@test "detects gitProjectGroup is missing" {
    # Note that closing "EOF" cannot be indented
    cat <<EOF > "$inputFileName"
    {
        "appParentDir": "/tmp/",
        "createRemoteGitRepo": "y",
        "deployCdk2Backend": "n",
        "deployCicdResources": "n",
        "deployRemoteEnvVars": "n",
        "deployTfBackend": "n",
        "useCicd": "n",
        "hasSecondaryRegion": "y",
        "AWS_SECONDARY_REGION": "us-west-2",
        "AWS_ACCOUNT_ID": "000000000000",
        "iac": "cdk2",
        "REMOTE_ENV_VAR_LOC": "na",
        "APP_NAME": "demo",
        "AWS_DEFAULT_REGION": "us-east-1",
        "CREATED_BY": "Anthony Watson",
        "ENV_NAME": "dev",
        "firstIacModuleName": "example",
        "gitProjectName": "bats-input-test",
        "gitRepoProvider": "gitlab",
        "gitRepoDomain": "git.fake.example.com"
    }
EOF

    # use for debugging:
    # cat $inputFileName >&3

    run get_input_validation_full_error_message "$inputFileName"

    assert_line --index 0 'ERROR: "gitProjectGroup" should be set if "createRemoteGitRepo" is set to "y" and "gitRepoProvider" is set to "gitlab".'
}

@test "detects TF_S3_BACKEND_NAME is missing" {
    # Note that closing "EOF" cannot be indented
    cat <<EOF > "$inputFileName"
    {
        "appParentDir": "/tmp/",
        "createRemoteGitRepo": "n",
        "deployCdk2Backend": "n",
        "deployCicdResources": "n",
        "deployRemoteEnvVars": "n",
        "deployTfBackend": "n",
        "useCicd": "n",
        "hasSecondaryRegion": "y",
        "AWS_SECONDARY_REGION": "us-west-2",
        "AWS_ACCOUNT_ID": "000000000000",
        "iac": "cdk2",
        "REMOTE_ENV_VAR_LOC": "na",
        "APP_NAME": "demo",
        "AWS_DEFAULT_REGION": "us-east-1",
        "CREATED_BY": "Anthony Watson",
        "ENV_NAME": "dev",
        "firstIacModuleName": "example",
        "gitProjectName": "bats-input-test"
    }
EOF

    # use for debugging:
    # cat $inputFileName >&3

    run get_input_validation_full_error_message "$inputFileName"

    assert_line --index 0 'ERROR: "TF_S3_BACKEND_NAME" value is invalid: "".'
    assert_line --index 1 "Must not include whitespace and length (0) must be between 1 and 75."
}

@test "valid input" {
    appParentDir="/tmp/"
    gitProjectName="bats-input-test"

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
        "hasSecondaryRegion": "y",
        "AWS_SECONDARY_REGION": "us-west-2",
        "AWS_ACCOUNT_ID": "000000000000",
        "iac": "cdk2",
        "REMOTE_ENV_VAR_LOC": "na",
        "APP_NAME": "demo",
        "AWS_DEFAULT_REGION": "us-east-1",
        "CREATED_BY": "Anthony Watson",
        "ENV_NAME": "dev",
        "firstIacModuleName": "example",
        "gitProjectName": "$gitProjectName,
        "TF_S3_BACKEND_NAME": "blank"
    }
EOF

    # use for debugging:
    # cat $inputFileName >&3

    export COIN_CREATE_APP_DRY_RUN="y"
    run get_input_validation_full_error_message "$inputFileName"

    assert_success
    assert_not_exists "${appParentDir}${gitProjectName}"
}

@test "detects gltoken is not set when attempting to communicate with GitLab" {
    # Note that closing "EOF" cannot be indented
    cat <<EOF > "$inputFileName"
    {
        "APP_NAME": "tffull",
        "AWS_ACCOUNT_ID": "123456789123",
        "AWS_DEFAULT_REGION": "us-east-1",
        "AWS_SECONDARY_REGION": "blank",
        "cicd": "gitlab",
        "useCicd": "y",
        "CREATED_BY": "Anthony Watson",
        "createRemoteGitRepo": "y",
        "deployCdk2Backend": "n",

        "deployRemoteEnvVars": "y",
        "deployCicdResources": "y",
        "deployTfBackend": "y",
        "ENV_NAME": "dev",
        "firstIacModuleName": "example",
        "gitRepoDomain": "gitlab.aws.dev",
        "gitRepoProvider": "gitlab",
        "gitProjectGroup": "mygroup",
        "gitProjectName": "bats-tf-full-deploy",
        "hasSecondaryRegion": "n",
        "iac": "terraform",
        "appParentDir": "/tmp/",
        "REMOTE_ENV_VAR_LOC": "gitlab",
        "TF_S3_BACKEND_NAME": "tffull-dev-tf-back-end",
        "destructiveUpgrade": "n"
    }
EOF

    # use for debugging:
    # cat $inputFileName >&3

    gltoken=""

    run get_input_validation_full_error_message "$inputFileName"

    assert_line --index 0 'ERROR: No value found for GitLab personal access token.'
    assert_line --index 1 "You must set \"gltoken\" as an environment variable with the token value"

}