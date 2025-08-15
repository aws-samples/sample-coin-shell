# COIN Shell CDK Users Guide

This document contains a quick reference for how to use COIN Shell with CDK projects.

# Does COIN Shell have any prerequisites that I need to install?

Yes. See the Prerequisites section in `environment/README.md`

# How can I configure personal (i.e. environment-specific) settings that I want CDK to use?

Run the `make ce` command (ce stands for "create environment"), which will start up a wizard that will ask you to provide values for all of the
existing configurable placeholders that your application has. When the wizard completes, it will output your
settings into a JSON file located at `environment/.environment-<my-env-name>.json`

Note that you can add new configurable settings
by adding them to the `environment/app-env-var-names.txt` file.

# Is it possible to configure settings for more than one environment?

Yes. It is common to have a shared/team environment as well as a personal environment. Each environment would have a separate JSON file.

You can set/switch your current environment with the `make sce` command, which stands for "Set Current Environment". 

You can view your current environment with the `make gce` command, which stands for "Get Current Environment".

# How are environment-specific settings fed into CDK?

Your environment-specific configurations should be defined in a JSON file under the `environment` directory. To run any CDK command, you should utilize targets defined in `environment/Makefile`. When you run a `make` target, COIN Shell will set all of your configurations as environment variables so that your CDK code can make use of them.

# How can my CDK code get the environment-specific settings?

CDK has the ability to make use of environment variables that are set automatically by COIN Shell when you run Makefile targets. It is a best practice to define a type-safe interface that CDK code can use to reference environment-specific values. Not only is this good for type-safety reasons, but it also abstracts the source of the configuration values.

COIN Shell defines a standard for how configurations should be referenced by CDK. Within each top-level CDK module, there should be a file called `utils/config.ts` that defines an `AppConfig` interface that makes all environment-specific configurations readable. Note that this file and interface are created automatically for you by COIN Shell, but if you add new environment-specific configurations to your project, you will need to update the `utils/config.ts` file before your CDK code can use them.

Here is an example of the `AppConfig` interface:
```
export interface AppConfig {
    readonly appName: string;
    readonly envName: string;
    readonly awsAccountId: string;
}
```

The `utils/config.ts` file must also contain a `getConfig` function that will return the `AppConfig` object. This function sets values based on environment variables.

Here is an example of the `getConfig` function:

```
export async function getConfig(): Promise<AppConfig> {

    let config: AppConfig = {
        appName: process.env.APP_NAME as string,
        envName: process.env.ENV_NAME as string,
        awsAccountId: process.env.AWS_ACCOUNT_ID as string,
    };
    return config;
}

```

# How can my CDK code use environment-specific configurations?

The below example illustrates how a CDK stack should accept the `AppConfig` object as part of it's input properties:
```
import * as cdk from 'aws-cdk-lib';
import { Construct } from 'constructs';
import { AppConfig } from "./utils/config";

interface ExampleStackProps extends cdk.StackProps {
  /**
   * Application config
   */
  readonly config: AppConfig;
}

export class ExampleStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props: ExampleStackProps) {
    super(scope, id, props);

    // create resources here

  }
}
```

Your CDK app is responsible for creating stacks. The app code is where the `AppConfig` object should be retrieved. Note the use of the `getConfig` function in the example below:
```
import * as cdk from "aws-cdk-lib";
import "source-map-support/register";
import { getConfig } from "./utils/config";
import { ExampleStack } from './stack';

/**
 * Main application function, make it async so it can call asnyc functions properly.
 */
async function main() {
    const app = new cdk.App();

    //Load config, when ready start the app
    console.log("Loading Configurations...");
    const config = await getConfig();
    console.log(JSON.stringify(config));
    console.log("DONE");

    if (!config) throw Error("Config not defined");

    new ExampleStack(app, `${config.appName}-${config.envName}-example`, {
        config
    });

    app.synth();
}

main();

```

# How do I create a new CDK module in my project?

`make cim`

("cim" stands for "Create Infrastructure Module")

Running the above command will ask you the name of the new module you want to create and it will create a new CDK module for you using that name. The new module will be placed under the `iac/roots` directory. It will also update your `environment/Makefile` to include easy commands for you to run CDK deploy, destroy, and diff against your new module.

# How do I run a CDK diff on my module?

In the `environment/Makefile`, you will see a target defined that allows you to run a CDK diff. It will be called `diff-<module-name>`. This will enable you to run `make diff-<my-module-name>` to execute a CDK diff on your module.

# How do I run CDK deploy on my module?

In the `environment/Makefile`, you will see a target defined that allows you to run a CDK deploy. It will be called `deploy-<module-name>`. This will enable you to run `make deploy-<my-module-name>` to execute a CDK deploy on your module.

# How do I run CDK destroy on my module?

In the `environment/Makefile`, you will see a target defined that allows you to run a CDK destroy. It will be called `destroy-<module-name>`. This will enable you to run `make destroy-<my-module-name>` to execute a CDK destroy on your module.

# Can I pass additional arguments to a CDK diff/deploy/destroy command?

Yes. Simply pass your additional arguments using the `args` parameter like the following example:

`make deploy-example args="myStackId --exclusively"`

# Can I use COIN Shell to run a custom CDK command of my choosing?

Yes. COIN Shell can set environment variables and then run any arbitrary CDK command you want to run.

```
make runcdk m=<my-module-name> c="<my-cdk-command>"
```

Example of running "cdk deploy" on the example module:
```
make runcdk m=example c="cdk deploy"
```

# How can I see the code that COIN Shell is running?

The `make` commands that run CDK "diff", "deploy", and "destroy" will call the `exec_cdk_for_env` function 
in the `environment/bash-5-utils.sh` script.

The `make` command that runs a CDK command of your choice will call the `exec_cdk_command_for_env` function 
in the `environment/bash-5-utils.sh` script.

# Where should I install the CDK binary?

Although the CDK binary can be installed globally on your system, it is best to specify the exact version of CDK that your project uses instead. Doing this will reduce the chance that CDK commands will work for some people and not for others. 

The CDK binary version should be set in your top-level CDK module's `package.json` file like so:

```
  "devDependencies": {
    "aws-cdk": "version-number-here",
  }
```

COIN Shell will try to use the CDK binary under `<myProjectPath>/iac/roots/<myModuleName>/node_modules/aws-cdk/bin/cdk`. If it can't find it there, it will try to use the globally-installed CDK. COIN Shell will log out which CDK binary it is using when you run Make commands that execute CDK.

# Setting yarn or npm as the package manager

When executing make targets such as `deploy-myModuleName`, COIN Shell will first install 3rd party dependencies that are defined in your `package.json` file (when appropriate). You may want to use yarn or npm for the package manager. COIN Shell allows you to set the package manager to use in the `environment/constants.sh` file. 

Here is an example of the setting:
```
# Set the package manager to use
coinPackageManager="npm" # can be set to "npm" or "yarn"
```

