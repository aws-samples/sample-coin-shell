import * as cdk from 'aws-cdk-lib';
import { Construct } from 'constructs';

import { CicdConfig } from "./utils/config";
import { GitLabIamRoleConstruct } from './constructs/gitlab-cicd-iam-role-construct';

interface CicdStackProps extends cdk.StackProps {
  /**
   * Application config
   */
  readonly config: CicdConfig;
}

export class CicdStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props: CicdStackProps) {
    super(scope, id, props);
        
    // BEGIN_GITLAB_ROLE_CICD_CONSTRUCT
    new GitLabIamRoleConstruct(this, "gitlab-iam-role", {
      config: props.config,

      // AWS Private GitLab role
      assumeRoleArn: "arn:aws:iam::979517299116:role/gitlab-runners-prod",
    });
    // END_GITLAB_ROLE_CICD_CONSTRUCT
  }

}
