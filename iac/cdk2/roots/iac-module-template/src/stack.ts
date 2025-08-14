import * as cdk from 'aws-cdk-lib';
import { Construct } from 'constructs';
import * as ssm from 'aws-cdk-lib/aws-ssm';
import { AppConfig } from "./utils/config";

interface ###COIN_IAC_MOD_CAMELCASE###StackProps extends cdk.StackProps {
  /**
   * Application config
   */
  readonly config: AppConfig;
}

export class ###COIN_IAC_MOD_CAMELCASE###Stack extends cdk.Stack {
  constructor(scope: Construct, id: string, props: ###COIN_IAC_MOD_CAMELCASE###StackProps) {
    super(scope, id, props);

    // example resource - you should delete this and replace with your IaC resources
    const ssmParam = new ssm.StringParameter(this, 'Parameter', {
      allowedPattern: '.*',
      description: 'The value Foo',
      parameterName: `/${props.config.appName}/${props.config.envName}/cdk-###COIN_IAC_MOD_SPINALCASE###-param`,
      stringValue: 'bar',
      tier: ssm.ParameterTier.STANDARD,
    });

  }
}
