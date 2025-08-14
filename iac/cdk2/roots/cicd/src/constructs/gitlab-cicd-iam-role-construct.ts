
import * as cdk from "aws-cdk-lib";
import { Construct } from "constructs";
import * as iam from 'aws-cdk-lib/aws-iam';

import { CicdConfig } from "../utils/config";

/* eslint-disable @typescript-eslint/no-empty-interface */
export interface GitLabIamRoleConstructProps extends cdk.StackProps {
    /**
    * Application config
    */
    readonly config: CicdConfig;

    /**
     * The ARN of the role that can assume the CICD role
     */
    readonly assumeRoleArn: string;
}

const defaultProps: Partial<GitLabIamRoleConstructProps> = {};

/**
 * Deploys the IAM role for GitLab CICD pipeline to assume
 */
export class GitLabIamRoleConstruct extends Construct {

    constructor(parent: Construct, name: string, props: GitLabIamRoleConstructProps) {
        super(parent, name);

        /* eslint-disable @typescript-eslint/no-unused-vars */
        props = { ...defaultProps, ...props };

        const gitLabInlinePolicy = new iam.PolicyDocument({
            statements: [
                new iam.PolicyStatement({
                    actions: [
                        "sts:AssumeRole",
                        "sts:TagSession",
                        "iam:PassRole",
                    ],
                    resources: [
                        `arn:aws:iam::${props.config.awsAccountId}:role/cdk-*`
                    ],
                }),
                new iam.PolicyStatement({
                    actions: [
                        "ssm:*",
                    ],
                    resources: [
                        `arn:aws:ssm:*:${props.config.awsAccountId}:parameter/${props.config.appName}-*`
                    ],
                }),
            ],
        });

        const principal = new iam.SessionTagsPrincipal(
            new iam.ArnPrincipal(props.assumeRoleArn)
        ).withConditions({
            StringEquals: {
                'aws:PrincipalTag/GitLab:Group': props.config.gitLabGroup,
                "aws:PrincipalTag/GitLab:Project": props.config.gitLabProject,
            },
        },);

        const gitLabCicdIamRole = new iam.Role(this, `${props.config.appName}-${props.config.envName}-cicd-role`, {
            roleName: `${props.config.appName}-${props.config.envName}-cicd-role`,
            assumedBy: new iam.PrincipalWithConditions(
                new iam.ArnPrincipal(
                    props.assumeRoleArn,
                ),
                {
                    StringEquals: {
                        'aws:PrincipalTag/GitLab:Group': props.config.gitLabGroup,
                        "aws:PrincipalTag/GitLab:Project": props.config.gitLabProject,
                    },
                },
            ).withSessionTags(),
            description: `CICD role for use by the ${props.config.appName} project`,
            inlinePolicies: {
                [`${props.config.appName}-${props.config.envName}-gitlab-policy`]: gitLabInlinePolicy,
            },
            managedPolicies: [
                iam.ManagedPolicy.fromAwsManagedPolicyName(
                    'PowerUserAccess',
                ),
            ],
        });

    }
}
