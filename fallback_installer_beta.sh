#!/usr/bin/bash 
#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
# script to create automated fallback channel switching function

#  wget the zipped lambda first, then create the function
rm -rf *.zip
#
wget https://dxl5rnnj43ic4.cloudfront.net/scripts/fallback_function.zip || (echo "---> Error retrieving file. Exiting." && exit )
sleep 1
## Gather user prefs for first channel
echo ""
echo "___________________________________________________________________________________"
echo "  This installer script creates a Lambda function and associated IAM role"
echo "  to implement automated switching of a MediaLive Channel to a fallback source"
echo "  in the event of a loss of video on the current input."
echo "___________________________________________________________________________________"
echo ""
echo ""


# Create an IAM role for Lambda Function to enable MediaLive fallback switching.
#echo "--- create the IAM Role for the new function ---"
echo "" && echo "--> Creating IAM role 'MediaLive_lambda' for Lambda function" && echo ""
aws iam create-role --role-name MediaLive_lambda --assume-role-policy-document '{"Version": "2012-10-17", "Statement": [{"Effect": "Allow", "Principal": {"Service": "lambda.amazonaws.com"},"Action": "sts:AssumeRole"}]}' || (echo "---> Error creating Role." )
sleep 1
aws iam attach-role-policy --role-name MediaLive_lambda --policy-arn  "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
aws iam attach-role-policy --role-name MediaLive_lambda --policy-arn "arn:aws:iam::aws:policy/AWSElementalMediaLiveFullAccess"
aws iam attach-role-policy --role-name MediaLive_lambda --policy-arn "arn:aws:iam::aws:policy/AWSLambda_FullAccess"
sleep 1
wget https://dxl5rnnj43ic4.cloudfront.net/scripts/trust_policy.json || (echo "---> Error retrieving file. Exiting." && exit )
aws iam update-assume-role-policy --role-name MediaLive_lambda --policy-document file://./trust_policy.json
sleep 1
###
RA=`aws iam get-role --role-name MediaLive_lambda|grep Arn |awk -F '"' '{print $4}'` ## ROLE arn
ACCTNO=`echo ${RA} |awk -F ':' '{print $5}'`
RGN=`aws configure get region`
echo "" && echo "---->Role $RA created and permissions added to control MediaLive..." && echo ""
##---------------------------------------------------------------------------------
## Create the Function itself
##
echo "" && echo "--- sleeping 5s for the Role to be ready ---" && sleep 5
echo "" && echo "--- create the function itself ---"
C1="aws lambda create-function --function-name MediaLive_Fallback_switcher --runtime python3.8 --role "
C2=" --handler lambda_function.lambda_handler --description \"MediaLive Fallback Switcher v2 02-2023 \" --timeout 60 --zip-file"
C3=" fileb://./fallback_function.zip"
C4='--tags "Key"="Channel_ID","Value"="fallback-input-name"'
C5=$C1$RA$C2$C3
echo ""
echo "-->Uploading new Lambda Function 'MediaLive_Fallback_switcher' ... " && echo ""
eval $C5 && echo "--> Success!" || (echo "---> Error uploading Lambda code...this may fail." )
##
##--------------------------------------------------------------------------------------
## Make the EventBridge Rule 
##
aws events put-rule --name MediaLive-automated-fallback --event-pattern "{\"source\":[\"aws.medialive\"],\"detail-type\":[\"MediaLive Channel Alert\"]}" --state ENABLED
sleep 1
##------------------------------------------------------------------------------------
echo "----"
#CMD12="aws lambda add-permission --function-name MediaLive_Fallback_switcher --cli-input-json file://./.pl.JSON"
CMD12="aws lambda add-permission --function-name MediaLive_Fallback_switcher --statement-id MediaLive_Fallback_policy --action lambda:InvokeFunction --principal events.amazonaws.com"
eval $CMD12 || (echo "--Failed on attempt to add permissions to Lambda Fn. .this may fail.")
echo "..."

## Extract new Function arn and put the CW Rule 
LA=`aws lambda list-functions |grep MediaLive |grep Arn |awk -F'"' '{print $4}'`
C8='aws events put-targets --rule MediaLive-automated-fallback --targets "Id"="MediaLiveLambda","Arn"='
eval $C8$LA  || (echo "---> Error putting Event forwarding rule. This may fail." )
#
sleep 1
# 
# create MediaLive log group in case in doesn't already exist... This will error harmlessly if group exists already.

aws logs create-log-group --log-group-name /aws/events/MediaLive > /dev/null 2>&1
##
## Optionally put Tags
##
##------------------------------------------------------------------------------------
echo ""
echo "-----------------------------------------------------------------------------------"

echo ""
echo "  All components installed."
echo "" && echo ""
echo "  This Lambda function references its own Tags to determine which Channels should be switched."
echo "  You can add additional Tags at any time from the AWS console."
echo "  The format of each Tag is: Tag Key = Channel ID# and Tag Value = fallback input name."
echo "" && echo "" && echo ""
##--------------------------------------
#put the column labels in the Tags on the Fn for future reference

C71='aws lambda tag-resource --resource '
C72=' --tags={\"Channel-ID\":\"fallback-input-name\"}'
CMD77=$C71$LA$C72
eval $CMD77 

echo ""
echo ""
eval $CMD94 || (echo "--Failed on attempt to add tags to Lambda Fn. You should add them manually.")
read -p "---> OPTIONAL: Do you want to configure the first channel now ? (enter y to continue or q or n to quit) :" DoTagsR
DoTags=` echo -n $DoTagsR `
if [[ "$DoTags" != 'y' ]]; then
	ChannelNum="Channel-ID"
	InputName="fallback-input-name-here"
	echo "--> Exiting. All done!" && exit
else:
	echo "-->continuing...." 

fi

echo ""
read -p ' Enter a MediaLive Channel ID# (not arn) which should automatically fall back, (or enter: 12345) and press <enter> :' ChannelNum
echo ""
read -p ' Enter a valid input name defined on that Channel (or enter FALLBACK.MP4), and press <enter> :' InputName

##------------------------------------------------------------------------------------


C91='aws lambda tag-resource --resource '
C92=' --tags={\"12345\":\"iname\"}'
CMD94=$C91$LA$C92
CMD94=${CMD94//12345/$ChannelNum} 
CMD94=${CMD94//iname/$InputName} 
echo "" && echo "---> adding first tag pair to new Lambda Function (you can check this from the AWS Console)..."
eval $CMD94 || (echo "--Failed on attempt to add tags to Lambda Fn. You should add them manually.")
##
echo"" && echo "---> cleaning up..."
rm -rf trust_pol* fallback_function.zip 
echo "" && echo "Done."
