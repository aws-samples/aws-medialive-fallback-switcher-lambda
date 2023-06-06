# fallback MediaLive channel switcher
# based on code from github
# https://github.com/aws-samples/aws-media-services-simple-live-workflow/blob/master/3-MediaLive/InputSwitching/InputSwitching.md
#
# PRE-REQUISITES
#  1. This lambda needs to be run by an IAM role with full access to MediaLive and to AWS Lambda
#  2. User will need to create a CW event-bus rule to forward events of type 'alert' to this function
#
import sys
import datetime
import time
import json
import os
import random
import string
import re
import boto3
from botocore.exceptions import ClientError
import code

target_channel = "0"
input_attachment_name ="none"

## parse the inbound CW event message

def lambda_handler(event, context):
    
    #print("received event was:  ", event)
    try: 
        Themsg = event['Records'][0]['sns']['Message']
        Fullmsg = json.loads(Themsg)

    except: 
       #Themsg = event['version'][0]['aws.sns']['Message']
       Fullmsg = event
       #print("** using alternate assignment **")
       
    else:
        print("Expected keys not found in SNS payload, exiting")
        print({
        "response status_code": "5xx",
        "message sent": "Expected keys not found in SNS payload - exiting."
        })
        return()
        
    ##--Define the Keys we want to match on in the log event ----------------
    
    TS = str(datetime.datetime.now())
    #
    ## define our list of desired keys to pull values for
    KeysWeWant = ["detail-type","eventName","alarm_state","alert_type","channel_arn","message"]
    ## define a results dictionary to be populated before sending
    Results = {'Time_Now': TS }
    #
    ##-- EXTRACT DETAILS --------------------------------------
    
    def walk(entity):
        itemkeys = entity.keys()
        for thiskey in itemkeys:
                #print("now checking ", thiskey)
                if thiskey in KeysWeWant:
                    #It is a single key so check the value against targetlist
                    #print("matched key:", thiskey)
                    Results.update( {thiskey : entity[thiskey]} )
                else:
                    try:
                        walk(entity[thiskey])
                        #print("...walking key", thiskey)
                    except (AttributeError, TypeError, KeyError):
                        pass


    ##--PARSE THE MSG -----------------------------
    
    walk(Fullmsg)
    
    ###-- We now have a Results dict populated with some k/v pairs to be ordered
    ###
    FoundResults = {'Timestamp': TS}
    for k in KeysWeWant:
        if k in Results.keys():
            FoundResults.update({k : Results[k]})
    
    ##
    ## decide if we need to switch by getting tags for Ch ID and Input     
    ##-------------------------------------------------------------------
    
    Lclient = boto3.client('lambda')
    #
    E=event
    C=context
    #####
    #print("..event = ", str(E))
    #print("***")
    #print("..context is ", str(C))
    #print("***","\n\n")
    #####
    target_channel_arn = str(E['detail']['channel_arn'])
    target_channel = target_channel_arn.split(":")[-1]
    #####
    resource_arn=context.invoked_function_arn
    resource_arn=str(resource_arn)
    #print("-->  this Fn ARN is: ", resource_arn, "and target_channel is", target_channel)
    ##
    ##
    response = "nope"
    try: 
        response = Lclient.list_tags(
            Resource=(str(resource_arn))
        )
        #print("-->Raw response: ",response)	

    except:
    	print("...caught exception #3...")
    	return()
    try: 
    	TAGS = response['Tags']
    	#print("TAGS found:",TAGS)
    	
    except:
    	print("...caught exception #4...")
    	return()
    
    if target_channel in TAGS.keys():
    	input_attachment_name = TAGS[target_channel]
    	print("--> Matched Channel ID", target_channel, "--attempting to switch to input",input_attachment_name)
        #We continue
    	
    else:
    	print("No matching Ch ID; exiting.", "\n")
    	print("...")
    	return()
    
    ##----------------------------------------------
    ID=False
    ALARMSET=False
    VIDALERT=False
    try:
        ARNfromALERT = str(FoundResults['channel_arn'])
        CHfromALERT = ARNfromALERT.split(":")[-1]
        CHfromALERT = int(CHfromALERT)
        TC=int(target_channel)
        #print("--> L139: TC = ",TC, type(TC),repr(TC) )
        #print("--> L140: CHfromALERT = ", CHfromALERT, type(CHfromALERT), repr(CHfromALERT))
        #print("........")
        try:
            if CHfromALERT == TC :
                #print("--> Matched Ch ID ", target_channel)
                ID = True
                
        except:   
            print("!!  Chl IDs do not match, taking no action, see line 149", "\n")
    except:
        print("no Channel ID matched.")
        return()
    
    try:
        if (FoundResults['alarm_state'] == "SET") :
            ## good to contine
            #print("--> Found alarm SET ")
            ALARMSET = True
            
    except:
        #print("Alarm not set high.")
        return()

    try:
        if  FoundResults['alert_type'] == "Video Not Detected":
            ## good to contine
            print("--> Found Alert: Video Not Detected! ")
            VIDALERT = True
            
    except:
        #print("Alarm not set high.")
        return()
     
     
     
    try:
        if (ID and ALARMSET and VIDALERT):
            print("--> Sending Switch cmd. ")
            DoSwitch(target_channel,input_attachment_name)
        
    except Exception as e: # work on python 3.x
        print("Got error", str(e))
        print("Did not meet conditions to switch.")
  



    
    
    
def DoSwitch(target_channel,input_attachment_name):    

    # start type 
    start_type = "immediate"  
      
    # if doing a dynamic input switch, set to true
    # if true, must provide a dynamic_input_url
    dynamic = False # True | False
    dynamic_input_url = "rodeolabz-us-west-2/livestreamingworkshop/big_buck_bunny.mp4" 

    ##
    ##  Compose the JSON
    medialive = boto3.client('medialive')

    action = {}            
    action = {
        'ScheduleActionSettings': {
            'InputSwitchSettings': {
                'InputAttachmentNameReference': input_attachment_name
                
            }
        }
    }
    if dynamic == "True":
        action = {
        'ScheduleActionSettings': {
            'InputSwitchSettings': {
                'UrlPath': [dynamic_input_url],
                'InputAttachmentNameReference': input_attachment_name                
            }
        }
    }
    

    action['ActionName'] = 'immediate_input_switch.{}'.format(rand_string())
    action['ScheduleActionStartSettings'] = {'ImmediateModeScheduleActionStartSettings': {}}
        
 
    print(action)
    response = medialive.batch_update_schedule(ChannelId=target_channel, Creates={'ScheduleActions':[action]})
    print("medialive schedule response: ")
    print(json.dumps(response))

def rand_string():
    s = string.digits
    return ''.join(random.sample(s,6))
