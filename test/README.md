# COIN Automated Testing

To avoid modifying the user's machine to test various scenarios, we can use a Docker container.

For testing Bash scripts, we make use of [BATS](https://bats-core.readthedocs.io/en/stable/), which is configured as Git submodules under the `test` directory.

## Prerequisites

You must have `npm` installed.

Before running any BATS tests, you must download BATS like so:
```sh
cd test
npm install
```

## Running a BATS tests

### Running All Functional Tests

```sh
cd test
node_modules/bats/bin/bats -r ./functional/
```

### Running Tagged Tests

Note, use "!" for tag negation.

```sh
cd test
node_modules/bats/bin/bats --filter-tags 'tag1:val1,!tag2:val2' -r ./functional/
```

### Running A Specific Test File

```sh
cd test
node_modules/bats/bin/bats functional/my-file.bats 
```

### Running A Specific Test Within A Specific File

The below example uses a regex to filter out any tests that are not an exact match for the "my test name" test.

```sh
cd test
node_modules/bats/bin/bats -f "^my test name$" functional/my-file.bats 
```

## How Do I Debug What's Going On In A Test?

A good way is to open a separate shell and tail the COIN logs like so:
```
tail -n 50 -F "$COIN_HOME/.log.txt"
```

You can print messages to the console from the test like so:
```
echo '# Hello there' >&3
```

You can print the contents of a file like so:
```
cat "<myFileName>" >&3

# OR

run cat <myFileName>"
echo "$output" >&3
```

## Running from Docker

You should have Docker installed and running before attempting these steps.

1. Clone the COIN repository to your local machine
2. Switch to the COIN test directory and build the Docker image
  * `cd $COIN_HOME/test`
  * `docker build --platform linux/amd64 --build-arg="COIN_HOME=$COIN_HOME" -t coin-test .`
4. Get short-term AWS credentials for the account you want to deploy to and set them into your shell as environment variables
5. Start up a COIN container (assuming you are in the "test" directory, see explanations below)
    ```
    export COIN_HOME="$(pwd)/.." && docker run --platform linux/amd64 --rm -it \
    -v ~/.ssh:/root/.ssh:ro \
    -v ~/.gitconfig:/root/.gitconfig:ro \
    -v /etc/localtime:/etc/localtime:ro \
    --mount type=bind,source="$COIN_HOME",target="$COIN_HOME" \
    -e AWS_ACCESS_KEY_ID="$AWS_ACCESS_KEY_ID" \
    -e AWS_SECRET_ACCESS_KEY="$AWS_SECRET_ACCESS_KEY" \
    -e AWS_SESSION_TOKEN="$AWS_SESSION_TOKEN" \
    -e COIN_HOME="$(pwd)/.." \
    --name coin-test docker.io/library/coin-test bash
    ```

    What does `-v ~/.ssh:/root/.ssh:ro` do?
      * It makes your host OS's .ssh configs available to the container in a read-only fashion. This is needed so that you can connect to GitLab using SSH.
    
    What does `-v ~/.gitconfig:/root/.gitconfig:ro` do?
      * It makes your host global Git configs available to the container in a read-only fashion. This is needed so that you can connect to GitLab and it will know your name and email address.

    What does `-v /etc/localtime:/etc/localtime:ro` do?
      * It makes your host OS's time zone configs available to the container in a read-only fashion. This is needed so that COIN logs use time stamps from your local time zone.

    What does `--mount type=bind,source="$COIN_HOME",target="$COIN_HOME"` do?
      * It binds the COIN project directory to the container. The container will be able to WRITE, not just read, from the directory on your host OS. This is needed so that COIN can create log files.

    What do the `-e` arguments do?
      * They set the AWS CLI environment variables so that COIN will be able to make calls to your account using the AWS CLI

## Test Set Up

## Developer Tips for Using BATS

`setup` and `teardown` are called for each test in a file. There is also a `setup_file` and `teardown_file` hook that is called once per file, not once per test.

In your test, you can optionally call your functionality using the `run` function. Here are the implications of that from the [BATS documentation](https://bats-core.readthedocs.io/en/stable/tutorial.html#dealing-with-output):
```
run, which is a function provided by bats that executes the command it gets passed as parameters. Then, run sucks up the stdout and stderr of the command it ran and stores it in $output, stores the exit code in $status and returns 0. This means run never fails the test and won’t generate any context/output in the log of a failed test on its own.
```
Since using `run` means that your test won't ever fail, you need to add assertions to make it fail when it should.

To print to the console from a BATS test, see below example and [BATS docs](https://bats-core.readthedocs.io/en/v1.3.0/writing-tests.html#printing-to-the-terminal):
```
echo '# Hello there' >&3
```

A list of BATS assertions can be found from these sources:
  * https://github.com/bats-core/bats-file
  * https://github.com/bats-core/bats-assert

The output from a test run is stored in the `$output` variable

To check for hidden characters in strings, you can use the following example to see the hidden characters:
```
hiddenOutput=$(printf "%q\n" "$output")
```

If you want to remove ANSI color codes from a string, you can use this sed expression to remove them:
```
sed -e 's/\x1b\[[0-9;]*m//g'
```