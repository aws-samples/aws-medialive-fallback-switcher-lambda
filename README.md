Introduction


This README summarizes the process of installing and configuring a Fallback Input Switcher script to automatically switch AWS MediaLive Channels to a preferred fallback input in the event that primary or current input is lost.  An automated installer deploys all needed components.


Solution Overview
- - - - - - - - -  

This fallback workflow uses an AWS EventBridge (CloudWatch) Rule to trigger an AWS  Lambda function which switches the alerting MediaLive Channel to a specified fallback input. We recommend that the fallback input be a VOD file (MP4 or TS) with content which does not expire: an animated logo slate, evergreen video material,  or a “Please Stand By” message.


This functionality differs from the Input Loss Behavior built into a MediaLive Channel in the following ways:

[a] Advantage: this fallback script can switch the MediaLive Channel to any configured input, including a live video source, whereas the native Channel Input Loss Behavior feature presently supports only static image slates or a simple colored screen on output.

[b] Advantage: The fallback script is easily configurable to support many MediaLive Channels without requiring alteration to any of the Channel configurations, whereas the Channel input loss behavior must be individually configured for each Channel.

[c]  Advantage:  Because the fallback script uses python and AWS lambda functions, it can be easily customized to take additional actions (Send Notifications, start or stop other resources (i.e. backup Channel) , etc.).

[d] Disadvantage: the built-in Channel Input Loss Behavior response is automatic and nearly instantaneous once configured, whereas this fallback script takes 5 to 6 seconds to react to the relevant input errors and switch the Channel to the specified fallback input. Basically this approach is slower due the slight latency of CloudWatch alerts and Lambda function start/run latency,  but users get a designated video source instead of a static slate image.


Solution Details:
- - - - - - - - - - - 

The fallback script installation is fully automated, and consists of three parts:


[1] It creates the AWS EventBridge Rule which forwards all MediaLive alerts for a given AWS Region to the designated Lambda function


[2] It creates the Lambda function itself


[3] It create and assigns the Necessary Roles and permissions, including:

  [a] One IAM Role named 'MediaLive lambda' which the Lambda Function will assume while executing. This Role has the ability to control MediaLive and to read its own metadata tags.

  [b] One CloudWatch Log group (aws/events/MediaLive).  This log group will typically already exist for previous users of the MediaLive service. If not, it will be created.




Installation:

Any AWS user can install the automated fallback script and the associated dependencies by running this one command from the AWS Cloudshell prompt or AWS CLI:

/bin/bash -c "$(curl -fsSL https://dxl5rnnj43ic4.cloudfront.net/scripts/fallback_installer_b6.sh)"




Optional: If you wish, you can create a test fallback input for MediaLive using a generic 'trouble slate' MP4 file with this command:

aws medialive create-input --type MP4_FILE --name fallback --sources "Url"="https://dxl5rnnj43ic4.cloudfront.net/MP4/TECHNICALDIFF.mp4"

If you do use this sample fallback input, you will need to attach it as an input to the MediaLive Channels for which you want to use it.
See https://docs.aws.amazon.com/medialive/latest/ug/attach-inputs-procedure.html for complete information.




Configuring additional Channels after setup:


This workflow was designed for ease of use.  To summarize:

•  A newly created EventBus (CloudWatch) Rule watches for new MediaLive alerts of type "Video Not Detected".

• When a new alert of this type appears, the Rule forwards a copy of it to the Lambda Function.

• When the Lambda function receives a forwarded alert, the Lambda checks it own metadata tags for a list of MediaLive Channel IDs and corresponding fallback input names.


• If the Channel mentioned in the alert is listed in the tags on the Lambda function, the corresponding fallback input is used for an immediate input switch command sent to the named MediaLive Channel.  Note: The fallback input must already be attached to this MediaLive Channel.

• This implementation allows any AWS user to quickly add or update the list of Channels having an automated fallback action by simply editing the Tags on the Lambda function at any time.

• If the specified fallback input is not available, the Channel will follow its configured Input Loss behavior. Options for Input Loss behavior include a repeat of the last known good frame; a solid color, or a trouble slate image.  The Input Loss behavior and Fallback Switcher work in concert to help ensure your MediaLive Channel always outputs the intended content, even in the event of unexpected input loss.

Consult the MediaLive documentation for complete details on input loss behavior options; see:
https://docs.aws.amazon.com/medialive/latest/ug/creating-a-channel-step3.html


Adding a new Channel to the Fallback switcher configuration is simple:
1. Edit the existing metadata tags on the Lambda function from the AWS console. Tags can be added, edited or removed at any time.
2. Add your Channel ID number as the Key, and the name of the fallback input to be used as the corresponding Value.
3. Updates are stored immediately, and take effect at the next occurrence of the lambda execution.

The next time a "Video Not Detected" alert comes in, the Channel ID will be checked and the appropriate fallback switch will be made approximately 5 to 6 seconds later. The exact timing depends upon CloudWatch Event latency and Lambda execution time. The switch will not be instantaneous. Users may see a brief appearance of whatever Input Loss Behavior is configured for the primary input on the current channel until the requested fallback input appears, so consider customizing the Input Loss Behavior for your MediaLive Channels to best suit your needs.


Advanced users are invited to explore modifications and enhancements to the Lambda function code, for example: to expand the trigger conditions (alerts); or to broaden the actions taken by the Lambda function. Possible enhancements may include sending out notifications via the SNS service, or starting a backup MediaLive Channel in some other AWS Region.


Conclusion:

This Fallback input switching script works in concert with AWS MediaLive's existing Input Loss behavior feature to help ensure your MediaLive Channel always outputs your intended content, even in the event of unexpected input loss.  We recommend combining redundant (Standard) Inputs, Dual (Standard) Pipelines,  robust Input Loss behaviors, and this fallback script to help ensure your high profile Channels provide content reliably even when inputs experience disruptions.

 

## Security

See [CONTRIBUTING](CONTRIBUTING.md#security-issue-notifications) for more information.

## License

This library is licensed under the MIT-0 License. See the LICENSE file.

