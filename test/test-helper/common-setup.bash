#!/usr/bin/env bash

# Common BATS setup for all test files
_common_setup() {
    TEST_HELPER_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
    TEST_DIR=$( cd -- "$( echo "${TEST_HELPER_DIR}/.." )" &> /dev/null && pwd )
    COIN_ROOT_DIR=$( cd -- "$( echo "${TEST_DIR}/.." )" &> /dev/null && pwd )
    PATH="$COIN_ROOT_DIR:$COIN_ROOT_DIR/environment:$PATH"

    load "$TEST_DIR/node_modules/bats-support/load"
    load "$TEST_DIR/node_modules/bats-assert/load"
    load "$TEST_DIR/node_modules/bats-file/load"
}
