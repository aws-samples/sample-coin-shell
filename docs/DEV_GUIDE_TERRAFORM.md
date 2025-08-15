# COIN Shell Terraform Users Guide

This document contains a quick reference for how to use COIN Shell with Terraform projects.

# Does COIN Shell have any prerequisites that I need to install?

Yes. See the Prerequisites section in `environment/README.md`

# Where is Terraform state stored?

COIN Shell automates the creation of an S3 bucket and DynamoDB table (that acts as a lock against simultaneous deployments). It uses a CloudFormation template to create this infrastructure. This template needs to be run at least once for each environment you want to use for your application.
You must deploy the CloudFormation template before executing any Terraform commands. 

To execute the CloudFormation, simply set your current environment with:

`make sce`

Then deploy the CloudFormation stack with:

`make deploy-tf-backend-cf-stack`

The stack can be deleted with:

`make destroy-tf-backend-cf-stack`

# How can I configure personal (i.e. environment-specific) settings that I want Terraform to use?

Run the `make ce` command, which will start up a wizard that will ask you to provide values for all of the
existing configurable placeholders that your application has. When the wizard completes, it will output your
settings into a JSON file located at `environment/.environment-<my-env-name>.json`

Note that you can add new configurable settings
by adding them to the `environment/app-env-var-names.txt` file.

# Is it possible to configure settings for more than one environment?

Yes. It is common to have a shared/team environment as well as a personal environment. Each environment would have a separate JSON file.

You can set/switch your current environment with the `make sce` command, which stands for "Set Current Environment". 

You can view your current environment with the `make gce` command, which stands for "Get Current Environment".

# How are environment-specific settings fed into Terraform?

Your environment-specific configurations should be defined in a JSON file under the `environment` directory. To run any Terraform command, you should utilize targets defined in `environment/Makefile`. When you run a `make` target, COIN Shell will resolve all of the placeholders that are defined in your module's files, then execute your Terraform command, then restore the placeholders back into the module's files so that they remain unchanged after the Terraform command completes.

COIN Shell looks for a placeholder pattern of `###MY_VAR_NAME###` and tries to replace those with values you have configured 
for your environment.

# Where are environment-specific placeholders defined in my Terraform?

There are 2 Terraform files that will have placeholders in them that will be resolved with your environment's configuration values.

The first file with placeholders is the `backend.tf` file for your Terraform module. This file specifies settings for where Terraform stores its state. You do not need to modify this file at all since it should always be the same. It sets up Terraform to store its state in the S3 bucket that COIN Shell creates for you (see above for details).

Example backend.tf file:
```
terraform {

  backend "s3" {

    bucket         = "###TF_S3_BACKEND_NAME###-###AWS_ACCOUNT_ID###-###AWS_DEFAULT_REGION###"
    key            = "###ENV_NAME###/###CUR_DIR_NAME###/terraform.tfstate"
    dynamodb_table = "###TF_S3_BACKEND_NAME###-lock"
    region         = "###AWS_DEFAULT_REGION###"
    encrypt        = true
  }
}
```

The second file with placeholders will be your module's `terraform.tfvars` file. This file holds the values for Terraform variables that
are refered to like so: `var.myCustomValue`.

Example terraform.tfvars file:
```
appName                        = "###APP_NAME###"
envName                        = "###ENV_NAME###"
primaryRegion                  = "###AWS_PRIMARY_REGION###"
secondaryRegion                = "###AWS_SECONDARY_REGION###"
myCustomValue                  = "###MY_CUSTOM_CONFIG_EXAMPLE###"
```

# How is the local Terraform state file impacted by switching environments that point to different AWS accounts?

After COIN Shell runs a Terraform command for you, it will create a backup of your module's `.terraform/terraform.tfstate` file. The backup will be named `coin-<environment-name>-env-tf-state`.

Before running a Terraform command, COIN Shell will automatically compare the current environment name with the configurations found in your Terraform module's `.terraform/terraform.tfstate` file (if it exists). If the Terraform state file refers to a different environment, COIN Shell will automatically resolve the problem for you by renaming backup files.

You can disable this behavior by changing the `projectToggleTerraformStateFiles` setting to "n" in `constants.sh`

# How do I create a new Terraform module in my project?

`make cim`

("cim" stands for "Create Infrastructure Module")

Running the above command will ask you the name of the new module you want to create and it will create a new Terraform module for you using that name. The new module will be placed under the `iac/roots` directory. It will also update your `environment/Makefile` to include easy commands for you to run Terraform plan, apply, and destroy against your new module.

# How do I run terraform plan on my module?

In the `environment/Makefile`, you will see a target defined that allows you to run a Terraform plan. It will be called `plan-<module-name>`. This will enable you to run `make plan-<my-module-name>` to execute a terraform plan on your module.

If you want to save the plan file, use this variant: `make plan-<my-module-name> args="-out tf.plan"`

# How do I run terraform apply on my module?

In the `environment/Makefile`, you will see a target defined that allows you to run a Terraform apply. It will be called `deploy-<module-name>`. This will enable you to run `make deploy-<my-module-name>` to execute a terraform apply on your module.

# How do I run terraform destroy on my module?

In the `environment/Makefile`, you will see a target defined that allows you to run a Terraform destroy. It will be called `destroy-<module-name>`. This will enable you to run `make destroy-<my-module-name>` to execute a terraform destroy on your module.

# Can I pass additional arguments to a Terraform plan/apply/destroy command?

Yes. Simply pass your additional arguments using the `args` parameter like the following example:

`make plan-example args="-target aws_ssm_parameter.example"`

# Can I use COIN Shell to run a custom terraform command of my choosing?

Yes. COIN Shell can resolve your module's placeholders and then run any arbitrary command you want to run.

As of COIN Shell version 9/28/2024 and later, you can use this simple syntax:

```
make tf m=<my-module-name> c="<my-terraform-command>"
```

To see the values that you supply to the "m" argument above, run:
```
make list-tf-modules
```

Example of running "terraform init" on the example module:
```
make tf m=example c="terraform init"
```

For older versions of COIN Shell, use this syntax:

Example structure for running a custom command:
```
cd <my-app-root-dir>
./environment/utility-functions.sh exec_command_for_env "<path-to-my-terraform-module>" "<custom-terraform-command>"
```

Example of running a custom "terraform import" command on the example module:
```
./environment/utility-functions.sh exec_command_for_env "iac/roots/example" "terraform import module.global_resources.aws_route53_zone.main MYZONEID"
```

# Can I tell COIN Shell to ignore certain files that it detects placeholders in?

Yes. COIN Shell looks for a placeholder pattern of `###MY_VAR_NAME###` and tries to replace those with values you have configured 
for your environment. Sometimes, there might be a file, such as in a third-party library, that COIN Shell finds in your Terraform module's
directory that you want it to ignore. 

To do this, simply update the `COIN_EXCLUDE_TEMPLATE_SEARCH` variable in the `environment/constants.sh file` and add a file or folder
using `grep` syntax that you want COIN Shell to ignore.

# How can I see the code that COIN Shell is running?

The `make` commands that run Terraform "plan", "apply", and "destroy" will call the `exec_tf_for_env` function 
in the `environment/bash-5-utils.sh` script.

The `make` command that runs a Terraform command of your choice will call the `exec_tf_command_for_env` function 
in the `environment/bash-5-utils.sh` script.

# Can I run checkov locally against my Terraform?

Yes. You can run it against a single root module like so:
```
make checkov m=<my-module-name>
```

or

You can run it against all of your root Terraform modules like so:
```
make checkov-all
```
