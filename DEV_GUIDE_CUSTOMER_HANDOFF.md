# Customer Handoff Users Guide

This document contains a quick reference for how to deliver code from prototypes that used COIN (during the development phase) to customers. 

COIN supports 2 options for this:
  1. Exclude COIN scripts and give the customer a simple set of instructions to set their configurations (e.g. AWS account number, region) 
  2. Include COIN scripts so that customers can also make use of COIN scripts.

Generally, the first option is considered preferred since it is simpler for customers.

## What If I Exclude COIN Scripts?

If you exclude COIN scripts from the customer deliverable, the `Makefile` you give to the customer cannot use any COIN scripts. This is why COIN creates a second Makefile called `Makefile-4-customer`. This file is not used by prototypers during development. It is intended to be used by customers to deploy the prototype. The `Makefile-4-customer` will contain targets that do not use COIN scripts. It contains an `init` target that should be run first by a customer and it will ask them for all of the configuration values that they need to set (e.g. AWS account number). Once the customer has filled in all of the values in the "init" process, those values will be set everywhere they are referenced in the project. The init process can only be run once, since it alters files to replace placeholders with values set by the customer.

Note: when you run the Extract Deliverable Wizard (described below), it will automatically rename this file to `Makefile`.

## Optional Step - Generate Deployment Instructions for the Customer

Rather than having to write instructions from scratch that explain to the customer how to deploy the prototype, you can have COIN generate instructions for you. It is best to wait until you are done coding the prototype before you generate the instructions so that they are as complete as possible. Once you've generated the instructions, you should proofread them and customize them as appropriate before you commit them into the Git repository.

To generate deployment instructions using COIN, run the `make gdi` command and answer the questions it asks that allow you to customize the instructions that are generated.

# Next Step - Run the Extract Deliverable Wizard

COIN comes with a wizard for getting files ready to share with the customer. It will ask you questions that allow you to include or exclude files from the final customer deliverable. Optionally, the script for the wizard can be customized to do things that are specific to a particular prototype, such as renaming or deleting files before sharing them with the customer. You'll find the Extract Deliverable wizard script at `environment/extract-deliverable.sh`.

When you run the Extract Deliverable wizard, it will not change files in your prototype's local directory. Instead, it will clone the prototype's Git repo into a separate location before making modifications. By default, the "main" branch is cloned. If you want to change the branch name, you can edit the script and set the `branchName` variable to whatever you want, or you can supply the desired branch name as the first argument when you run the command to start the wizard.

The Extract Deliverable wizard can be started using this command: `make exd`. 

Note: to exlude COIN files, answer "n" to question, "Do you want to include the environment scripts?".

If you choose to exclude COIN files, the Extract Deliverable wizard will create an `init.sh` script that will be included in the customer deliverable. The `init.sh` script is executed by the `init` target (described above) in the `Makefile`.

The ultimate goal of the Extract Deliverable wizard is to make sure that we avoid giving the customer any uncommitted or locally changed files and that we have a repeatable process for excluding and renaming files before we hand them to the customer.