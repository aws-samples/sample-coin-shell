# ###APP_NAME###

## Project Description

TODO fill in a project description

## Getting Started

###APP_NAME### includes scripts that can customize it with environment-specific
settings and deploy it to 1 or more AWS accounts/regions. The scripts require some
set up before they can be run successfully. See `environment/README.md` for details
on script prerequisites and functionality.

Once all of the script prerequisites have been met, you can set up a new application
environment configuration by running the Create New Application Environment Wizard
like so:
```
make ce
```

After an application environment is configured, you can deploy the application with
those configurations by executing the targets from `Makefile` in the 
order listed by the `deploy-all` target.
