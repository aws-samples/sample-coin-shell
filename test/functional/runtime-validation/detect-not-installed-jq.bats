#!/usr/bin/env bats

setup() {
    load '../../test-helper/common-setup'
    _common_setup

    if [[ $(echo `[ -f /.dockerenv ]` $?) == 1 ]]; then
        skip "SETUP test should only run from within a Docker container"
    else
        apt remove -y jq
    fi

    # get the containing directory of this file
    # use $BATS_TEST_FILENAME instead of ${BASH_SOURCE[0]} or $0,
    # as those will point to the bats executable's location or the preprocessed file respectively
}

teardown() {
    if [[ $(echo `[ ! -f /.dockerenv ]` $?) == 1 ]]; then
        apt install -y jq
    fi
}

# bats file_tags=type:functional, suite:create-app, not-installed:jq

@test "detects jq not installed" {

    if command -v jq --version &> /dev/null
    then
        skip "jq is already installed"
    fi

    run create-app.sh

    assert_failure
    assert_equal "${#lines[@]}" 8 # account for leading and trailing new lines as well as install instructions
    assert_line --partial --index 1 'ERROR: jq could not be found. Please install jq, then run this script again.'
}
