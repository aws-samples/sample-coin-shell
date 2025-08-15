<img src="./docs/images/coin-shell-logo-transparent.png"
     alt="COIN Shell"
     style="max-height: 30%; max-width: 30%;" />

# COIN Shell

COIN (Collaborate on Infrastructure Now) Shell is a set of shell scripts that makes it easy to generate new
Infrastructure as Code (IaC) projects that can be deployed to one or more AWS accounts without changing any code. 
It uses an interactive wizard to gather user choices, (e.g. whether to use CDK or Terraform or CloudFormation) before generating 
a project that contains a plethora of useful utilities.

Users can create one or more sets of configurations and switch between them seamlessly. For example, you might
create a "dev" configuration set for deploying your IaC to a dev environment and a "personal" configuration set
for deploying to your own AWS account. Your teammates can clone the Git repository for the generated app and launch
a wizard to help them create their own unique configuration sets. By default, configuration sets are not committed 
to Git to prevent accidentally committing sensitive information. 

With COIN Shell, your configuration set is defined in a single place and its settings can be referred to from 
anywhere in your project. This prevents you from having to update a setting in multiple places.

COIN Shell helps prevent mistakes. For example, it will validate that you are logged in to the right AWS account
before it tries to execute IaC. It will also check that your configuration set contains values for each configurable 
item and warn you if it doesn't. Let's say your teammate commits changes to your project that adds a new configuration
item that is intended to hold an API URL, if you pull the latest changes from Git and try to deploy the IaC, COIN Shell
will inform you that you must set the API URL before continuing.

The code that COIN Shell generates will also contain a `Makefile` that has easy to remember commands. No more trying
to remember complex sets of instructions. As an example, if you tell COIN Shell you want to create a Terraform module called
"vpc", you would be able to run Terraform plan, apply, or destroy via Make with simple commands like `make deploy-vpc`.

COIN Shell even includes the ability to set configuration item values to be pulled from sources like AWS Secrets Manager
or AWS Systems Manager Parameter Store instead of being hardcoded.

## Guides

If you are a Terraform user, see the [COIN Terraform Users Guide](./docs/DEV_GUIDE_TERRAFORM.md)

If you are a CDK user, see the [COIN CDK Users Guide](./docs/DEV_GUIDE_CDK.md)

Detailed documentation can be found [here](./docs/DOCUMENTATION.md).

## Features

* Generates projects based on wizard that asks questions
    * The wizard can be run interactively or headlessly via a supplied JSON configuration file
        * It can also be run from a Docker container desired
    * Creates a new GitLab repository for you (optionally)
    * Results in projects with standard directory structure
    * Creates an example IaC module for reference or expansion
        * New IaC modules can be created via a Make target that runs a small wizard
    * Works with Terraform, CDK, CloudFormation (based on user's desired stack)
    * Generates GitLab CICD pipeline (optionally) to run static analysis or perform builds/deployments when commits are merged
    * Generates project Makefile with a list of common tasks, such as to deploy an IaC module
        * Just type "make" in a command prompt to see a list of available Make targets
        * Writes to log file (`environment/.log.txt`) whenever a Make target is executed so that users can debug what COIN Shell is doing.
* Facilitates each team member having their own configurations, such as account/region. 
    * The single set of configurations can be applied to any file
      * If the file supports reading environment variables, this is the preferred approach
      * If the file does not support reading environment variables, COIN Shell will perform placeholder substitution
    * These settings do not get checked into Git since this is a common source of mistake
    * Configurations are validated to clearly inform teammates if a new configuration has been added for which they have not yet set a value
    * Configurations are automatically loaded as environment variables whenever a Make target is executed
        * variables can be overridden from the command line if needed
    * Team members can have as many environments configured as they want, here an "environment" is just a set of configuration values
      * It is simple to switch to another environment and to create a new environment using Make targets
* CICD
    * Can run project build via GitLab CICD pipeline
      * There are Make targets to populate environment configurations as GitLab CICD variables so that pipelines can be run against any environment
* Dynamic variable resolution
    * Environment configuration values can be pulled from SSM Parameter Store or Secrets manager
        * This feature enables the following use case: You have an IaC module that creates a new resource. After deploying that module, you want to deploy a second IaC module that needs to know an ARN or some other piece of data that was created by the first IaC module. To support this, the first IaC module should set values that subsequent modules need as either SSM Parameters or Secrets
        * Values are cached locally so that users do not need to wait for them to be pulled remotely every time an action is performed
* Extract deliverable wizard
    * A customizable script that produces the files that we want to share with others. Can be made to include/exclude certain files based on whether we want to share them or not
* Supports hooks that can generate configuration files used by other tools

## Why Was COIN Shell Created?

Before COIN Shell:

* Depending on who sets up a new prototype repository, there is inconsistency in how they go about this
    * The inconsistency creates a one-off learning curve for team members
* Starting from scratch every time is a waste of time
    * People write build jobs and scripts as one-offs. These scripts are often of low quality since they are written in a hurry in order to focus on prototype functionality.
* People accidentally commit their personal settings into the Git repository. Often, it’s not clear which files a team member needs to configure for their personal setup.
* If you don’t have a common approach to scaffolding and scripting, you don’t have a single place to add features or bug fixes so that everyone can benefit
    * Copying and pasting scripts from previous projects does not allow everyone access to the best version of scripts.

## Getting Started

**Prerequisites**

* Optional (but recommended) - COIN Shell's app generation wizard will offer to deploy some initial items for you to 
an AWS account of your choice. To make sure this works, log in with the AWS CLI to the account you plan to target 
before running the wizard.
* Optional - If you want the Create App Wizard to create a new Git repository for you and you are 
using GitLab, you must have Maintainer privileges in GitLab for the group you are adding 
the repository to. Otherwise, the wizard will fail to create the "main" branch on GitLab. 
If you are creating the repository using your GitLab username as the repository group, 
you can ignore this.
* Optional - If your project will use a GitLab CICD pipeline and you want to automatically set
pipeline environment variables, you will need to create a GitLab personal access token that you
can supply to the Create App / Create App Environment wizards.
* Optional - If you want to use the Makefiles that the wizard generates, you must 
install [make](https://www.gnu.org/software/make/)
* Optional - if you want to create an app that uses CDK v2, you must have NodeJS installed
as well as the programming language that you will use to implement your CDK app. It is best if your CDK modules have an explicit dependency set on the CDK version they use. This would be set in `package.json`. If you do not set this, COIN Shell will try to find a globally installed [CDK v2](https://docs.aws.amazon.com/cdk/v2/guide/getting_started.html).
* Optional - if you want to create an app that uses Terraform, you must have 
[Terraform](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli) (version 1.8.0 or greater) installed

**Machine Prerequisites**

The following are prerequisites for running COIN Shell on your computer. If you want to run COIN Shell from a Docker container instead, skip to the "Running from Docker" section below.

* [AWS CLI v2](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
* [Git CLI](https://git-scm.com/downloads)
* [jq](https://stedolan.github.io/jq/)
* Bash shell with version 5.0 or greater. 
  * Mac users 
      * Mac comes with an old version of Bash
      * Use `homebrew` to install new version
      * `which bash` should point to `/opt/homebrew/bin/bash`
      * If you use VSCode and you want to use bash as your default Terminal shell, you must 
      update its terminal shell to use the one from homebrew.
        * Go into VSCode settings and search for "terminal"
        * Find the setting named "Terminal>Integrated>Env:Osx" and set its value to bash
  * Cloud Desktop Users (Amazon Linux 2)
      * Execute the below statements to upgrade to Bash 5
      * After executing these statements, you can switch to the Bash shell
      by typing: `exec bash`. Note that `zsh` is the default shell for AL2.
        ```
        cd ~
        wget http://ftp.gnu.org/gnu/bash/bash-5.2.tar.gz
        tar xf bash-5.2.tar.gz
        cd bash-5.2
        ./configure
        make
        sudo make install
        sh
        bash -version
        ```

**Running from Docker**

Optional - most people just run COIN Shell scripts from their laptop's host operating system. If this doesn't work for you, here are some instructions for creating a Docker container that is set up with the tools needed to run COIN Shell scripts.

You should have Docker installed and running before attempting these steps.

1. Clone the COIN Shell repository to your local machine
2. Set an environment variable to where you downloaded the COIN Shell project to, for example:
  * `export COIN_HOME=~/code/create_coin_app`
3. Switch to the COIN Shell directory and build the Docker image
  * `cd $COIN_HOME`
  * `docker build --platform linux/amd64 --build-arg="COIN_HOME=$COIN_HOME" -t coin .`
5. Get short-term AWS credentials for the account you want to deploy to and set them into your shell as environment variables
6. Start up a COIN Shell container (see explanations below)
    ```
    docker run --platform linux/amd64 --rm -it \
    -v ~/.ssh:/root/.ssh:ro \
    -v ~/.gitconfig:/root/.gitconfig:ro \
    -v /etc/localtime:/etc/localtime:ro \
    --mount type=bind,source="$COIN_HOME/..",target="$COIN_HOME/.." \
    -e AWS_ACCESS_KEY_ID="$AWS_ACCESS_KEY_ID" \
    -e AWS_SECRET_ACCESS_KEY="$AWS_SECRET_ACCESS_KEY" \
    -e AWS_SESSION_TOKEN="$AWS_SESSION_TOKEN" \
    --name coin docker.io/library/coin bash
    ```

    What does `-v ~/.ssh:/root/.ssh:ro` do?
      * It makes your host OS's .ssh configs available to the container in a read-only fashion. This is needed so that you can connect to GitLab using SSH.
    
    What does `-v ~/.gitconfig:/root/.gitconfig:ro` do?
      * It makes your host global Git configs available to the container in a read-only fashion. This is needed so that you can connect to GitLab and it will know your name and email address.

    What does `-v /etc/localtime:/etc/localtime:ro` do?
      * It makes your host OS's time zone configs available to the container in a read-only fashion. This is needed so that COIN Shell logs use time stamps from your local time zone.

    What does `--mount type=bind,source="$COIN_HOME/..",target="$COIN_HOME/.."` do?
      * It binds the parent directory of the COIN Shell project to the container. The container will be able to WRITE, not just read, from the directory on your host OS. This is needed so that COIN Shell can create files for you on your host OS. You can bind whatever directory you want COIN Shell to generate applications into.

    What do the `-e` arguments do?
      * They set the AWS CLI environment variables so that COIN Shell will be able to make calls to your account using the AWS CLI
    
**Generating a Prototype Project Skeleton**

First, clone the COIN Shell Git repsitory to your machine, open a terminal, and change to the directory where COIN Shell was downloaded to.

Make sure you've satisfied the prerequsites listed above before continuing.

Start the "Create COIN App Wizard" like so:

```
./create-app.sh
```

If you want to run the wizard in headless mode, create a JSON file that
has the answers to the wizard's questions. Pass in the location of
the JSON file as the first argument to the `create-app.sh` script.
See `create-app-answers-template.json5` for details.

```
./create-app.sh "/Users/someuser/create-my-app-configs.json"
```

## Troubleshooting

* The best way to troubleshoot COIN Shell is to check its logs. To do this, open `environment/.log.txt` and browse through its contents. You can also search the file for "ERROR" or "WARN" to see if COIN Shell has detected what is wrong.
* I get a "declare: -A: invalid option" error when running COIN Shell scripts.
  * The problem is your bash shell has an old version that does not support associative
  arrays. See the prerequites for this project for bash upgrade instructions.

## FAQ

1. Where is the documentation?
    * See [DOCUMENTATION.md](DOCUMENTATION.md).
2. How do I know what version of Create COIN App was used to generate my project?
    * The create app wizard will save the Git hash of the Create COIN App project
  to the generated application's `environment/coin-app-version` file.
3. Can I change the standard directory structure of my generated application?
    * It is recommended for consistency to use the out-of-the-box directory structure of COIN Shell.
  However, if you need to change it, you can edit the `constants.sh` file in your application.
  All COIN Shell scripts utilize the directory paths that are defined in that file.
4. When new features/fixes are added to Create COIN App (COIN), how do I upgrade applications
that were generated by an older version of the wizard so that my application has
all of the latest features and bug fixes?
    * If your project was created after 4/1/25, you can simply run the `make uc` command in your project to upgrade COIN Shell.
    * For older projects: The create app wizard can be run as many times as necessary against the same
  application directory. To upgrade an existing application that was created by
  COIN Shell
      1. First, pull the latest COIN Shell changes from Git. 
      2. Next, make sure that you do not have any uncommitted changes to your application repository.
      3. Run the create app wizard, making sure that the project name and directory that
    you input into the wizard match where your existing application is on your file system.
      4. After the wizard completes, examine the Git "diff" manually before committing
    any changes. Your application team may have modified some files that are generated
    by the create app wizard. Make sure to keep those changes, while also keeping any
    changes made for the latest version of COIN Shell. Files that the application
    team is most likely to change are `environment/Makefile` and `app-env-var-names.txt`.

      Note: In order to avoid overwriting the contents of an existing environment JSON config file
    in your project, the Create App Wizard will automatically make a copy of that file instead
    of overwriting it. The existing `environment/.environment-<myEnvName>.json` file will be 
    backed up to `environment/.environment-<myEnvName>-copy.json`.
5. How do I configure COIN Shell to ignore/exclude certain files that should not be included in the template placeholder resolution process?
    * Update the grep patterns set in the `COIN_EXCLUDE_TEMPLATE_SEARCH` variable in the `environment/constants.sh` file
6. Does COIN Shell have any extension points?
    * Yes - see `extensions.sh`. For configurations, see `create-app-defaults.sh` and `constants.sh`