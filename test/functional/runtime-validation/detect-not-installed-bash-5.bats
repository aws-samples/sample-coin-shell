#!/usr/bin/env bats

setup() {
    load '../../test-helper/common-setup'
    _common_setup

    # get the containing directory of this file
    # use $BATS_TEST_FILENAME instead of ${BASH_SOURCE[0]} or $0,
    # as those will point to the bats executable's location or the preprocessed file respectively
}

# bats file_tags=type:functional, suite:create-app

@test "detects bash 5 not installed" {

    if [[ ! -d "$HOME/old-bash/bash-3.2.57" ]]; then
        skip "bash-3.2.57 is not installed in $HOME/old-bash/bash-3.2.57"
    fi

    run $HOME/old-bash/bash-3.2.57/bash create-app.sh

    assert_failure
    assert_equal "${#lines[@]}" 14 # account for leading and trailing new lines as well as install instructions
    assert_line --partial --index 1 'ERROR: You are currently running Bash shell version 3. Please upgrade to 5 or later'
}