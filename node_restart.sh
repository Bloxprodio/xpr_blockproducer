#!/bin/bash

################################################################################
# XPR Network node restart by Bloxprod.io
################################################################################
# Script Name: example_script.sh
# Version: v0.9.2
# Author: bloxprod.io
# Date: 2025-04-15
#
# Description:
# This script is restarts XPR block producer (nodeos node) in a main or test network.
# Its primary function is to ensure that the nodeos service of configured block producer is not interupted during block producing
# --------------------------------------
# change log
# v0.9 - 2025-04-01 - initial version
# v0.9.1 - 2025-04-14 - comment changes
# v0.9.2 - 2025-04-15 - checkup for start timestamp implemented
# --------------------------------------
# Usage:
# ./node_restart.sh <parameter1>
#
# Dependencies:
# 1. script requires XPR/Nodeos scripts in NODEOS_DIR
#	1.1 stop.sh
#	1.2 start.sh
#
# 2. install and configure ssmtp
# 	2.1 apt install ssmtp
# 	2.2 add your SMTP server details to /etc/ssmtp/ssmtp.config
# 	2.3 define sender addresses for user in /etc/ssmtp/revaliases
#
# 3. define current runtime in variable
# 	3.1 XPR_NET = MainNet | TestNet
#
# 4. enter your favorite server for calling the v1/chain/get_producer_schedule api
# 	4.1 SERVER_URL_TESTNET
#	4.2 SERVER_URL_MAINNET
#
# 5. change path of nodeos home dir (if this is not /opt/XPRMainNet/xprNode | /opt/XPRTestNet/xprNode)
# 	5.1 NODEOS_DIR
#
# 6. define e-mail parameters
# 	6.1 EMAIL_RECEIVER
#	6.2 EMAIL_SENDER
# 	6.3 EMAIL_SUBJECT
#
# Script Parameters:
#   <parameter1> - test (if script is started in test mode, the restart of node will be skipped)
#
# Example:
# ./node_restart.sh test
#
# before starting script, check values and settings of section "variable definition"
################################################################################



####################### start variable definition #######################

### set the network for which the Nodeos node works (TestNet | MainNet)
XPR_NET=MainNet

### server endpoint for v1/chain/get_producer_schedule
SERVER_URL_TESTNET="https://xpr-testnet-api.bloxprod.io"
SERVER_URL_MAINNET="https://xpr-mainnet-api.bloxprod.io"

### path und filenames
# nodeos base dir
NODEOS_DIR="/opt/XPR$XPR_NET/xprNode"
# node config file
NODEOS_CONFIG_FILE="$NODEOS_DIR/config.ini"
# node log file
NODEOS_LOG_FILE="$NODEOS_DIR/stderr.txt"
# log file to log script activities
RESTART_LOG_FILE="$NODEOS_DIR/restart_logfile.log"
# temp file to generate outgoinfg mail body
MAIL_TEMP_FILE="$NODEOS_DIR/restart_mail_tempfile.txt"


### e-mail parameters
## parameters to send e-mails in case of errors
# receiver e-mail
EMAIL_RECEIVER="rcv_mail@example.com"
EMAIL_SENDER="rcv_mail@example.com"
EMAIL_SUBJECT="error on $XPR_NET with BP $LOCAL_PRODUCER"

####################### end variable definition #######################




echo "##############################################"
# local block producer name
LOCAL_PRODUCER=$(grep -E "producer-name\s*=" "$NODEOS_CONFIG_FILE" | cut -d '=' -f2 | tr -d ' ')

# check if a script parameter was used
if [ $# -eq 0 ]; then
    RESTART_FLAG=true
	echo "info: RESTART_FLAG set to TRUE"
	echo "info###RESTART_FLAG set to TRUE $(date)###" >> $RESTART_LOG_FILE
elif [ "$1" = "test" ]; then
	RESTART_FLAG=false
	echo "info: RESTART_FLAG set to FALSE"
	echo "info###RESTART_FLAG set to FALSE $(date)###" >> $RESTART_LOG_FILE
else
	echo "error: undefinded parameter "$1" found"
	echo "info###undefinded parameter "$1" found $(date)###" >> $RESTART_LOG_FILE
	exit 1
fi

if [ "$XPR_NET" = "MainNet" ]; then
	echo "info: XPR_NET variable set to MainNet"
	echo "info###XPR_NET variable set to MainNet $(date)###" >> $RESTART_LOG_FILE
	SERVER_URL="$SERVER_URL_MAINNET"
elif  [ "$XPR_NET" = "TestNet" ]; then
	echo "info: XPR_NET variable set to TestNet"
	echo "info###XPR_NET variable set to TestNet $(date)###" >> $RESTART_LOG_FILE
	SERVER_URL="$SERVER_URL_TESTNET"
else
	echo "error: XPR_NET variable is neither set to MainNet nor to TestNet"
	echo "info###XPR_NET variable set to TestNet $(date)###" >> $RESTART_LOG_FILE
	exit 0
fi

# set endpoint URL
API_URL="${SERVER_URL}/v1/chain/get_producer_schedule"

# send API-Request
response=$(curl -s -X POST "$API_URL")

# check whether the get_producer_schedule response contains a valid JSON (active element exists and key elements was found 21 times)
if echo "$response" | jq '.active? // empty' > /dev/null; then
	key_count=$(echo "$response" | jq -r '.. | objects | .key? | select(. != null)' | wc -l)
	if [ "$key_count" -eq 21 ]; then
		echo "info: json response of get_producer_schedule is valid"
	else
		echo "error### the key element was not found 21 times in JSON response.\n\n Please check get_producer_schedule response: \n\n $response" >> $RESTART_LOG_FILE
		echo -e "To: $EMAIL_SENDER\nSubject: $EMAIL_SUBJECT \n\n the key element was not found 21 times in JSON response.\n\n Please check get_producer_schedule response: \n\n $response" > $MAIL_TEMP_FILE
		ssmtp -v $EMAIL_RECEIVER < $MAIL_TEMP_FILE
		exit 1
	fi
else
    	echo "error### the action element was not found in JSON response.\n\n Please check get_producer_schedule response: \n\n $response" >> $RESTART_LOG_FILE
		echo -e "To: $EMAIL_SENDER\nSubject: $EMAIL_SUBJECT \n\n the action element was not found in JSON response.\n\n Please check get_producer_schedule response: \n\n $response" > $MAIL_TEMP_FILE
		ssmtp -v $EMAIL_RECEIVER < $MAIL_TEMP_FILE
		exit 1
fi




# parse API-Response: search blockproducer list and get successor
blockproducers=$(echo "$response" | jq '.active.producers[] | .producer_name')

# get position of local producer
current_index=$(echo "$blockproducers" | grep -n "$LOCAL_PRODUCER" | cut -d: -f1)

# If the current producer was not found, we assume that our block producer is out of schedule
if [ -z "$current_index" ]; then
		echo "info: BP $LOCAL_PRODUCER not found in $XPR_NET schedule"
		echo "info: seems to be safe to restart BP $LOCAL_PRODUCER without checking producing dependencies"
		echo "info###restart initiated:$(date)### $response" >> $RESTART_LOG_FILE
   		if [ "$RESTART_FLAG" = "true" ]; then
			echo "info: restart initiated"
			$NODEOS_DIR/stop.sh
			$NODEOS_DIR/start.sh
			echo "info###restart finshed:$(date)### $response" >> $RESTART_LOG_FILE
			echo "info: BP $LOCAL_PRODUCER restarted"   			
			exit 0
		else
			echo "info: RESTART_FLAG=false - no restart initiated"
			echo "info###RESTART_FLAG=false - no restart initiated:(date)### $response" >> $RESTART_LOG_FILE
			echo "info: RESTART_FLAG=false - BP $LOCAL_PRODUCER not restarted"   	
			exit 0
		fi
		

fi

# get successor
next_index=$((current_index + 1))

# write block producer to variable
current_blockproducer=$(echo "$blockproducers" | sed -n "${current_index}p")
current_blockproducer="${current_blockproducer%\"}"
current_blockproducer="${current_blockproducer#\"}"

# write successor producer to variable
next_blockproducer=$(echo "$blockproducers" | sed -n "${next_index}p")
next_blockproducer="${next_blockproducer%\"}"
next_blockproducer="${next_blockproducer#\"}"

echo "info: local BP in schedule found: $current_blockproducer"

# if successor producer is empty was not found for any reason, send an error e-mail and exit script
if [ -z "$next_blockproducer" ]; then
	echo "error### the variable next_blockproducer was emtpty.\n\n Please check$response" >> $RESTART_LOG_FILE
 	echo -e "To: $EMAIL_SENDER\nSubject: $EMAIL_SUBJECT \n\n $response" > $MAIL_TEMP_FILE
	ssmtp -v $EMAIL_RECEIVER < $MAIL_TEMP_FILE
	exit 1
fi

echo "info: BP successor in schedule found: $next_blockproducer"

# create search string
SEARCH_ENTRY="signed by $next_blockproducer"

echo "##############################################"

# check the nodeos log file every second to see if the search entry is present
while true
	do

		# set timestamp
		CURRENT_TIME=$(date +%s)
		
		# find first entry of listening

		FIRST_LISTEN_ENTRY=$(grep "start listening on" "$NODEOS_LOG_FILE" | head -n 1)

		# extract timestamp from listening line
		FIRST_LISTEN_TIME=$(echo "$FIRST_LISTEN_ENTRY" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}\.[0-9]{3}')

		# ensure that timestamp was exttracted only once
		FIRST_LISTEN_TIME=$(echo "$FIRST_LISTEN_TIME" | head -n 1)
		
		# set FIRST_LISTEN_TIME to current datetime if empty
		if [ -z "$FIRST_LISTEN_TIME" ];then
			FIRST_LISTEN_TIME=$(date +"%Y-%m-%dT%H:%M:%S.%3N")
		fi
		
		# convert timestamp
		FIRST_LISTEN_SECONDS=$(date -d "$FIRST_LISTEN_TIME" +%s)

		# find last entry with search string
		LAST_ENTRY=$(grep "$SEARCH_ENTRY" "$NODEOS_LOG_FILE" | tail -n 1)

		# extract timestamp from last entry
		LAST_ENTRY_TIME=$(echo "$LAST_ENTRY" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}\.[0-9]{3}')
		
		# ensure that timestamp was exttracted only once
		LAST_ENTRY_TIME=$(echo "$LAST_ENTRY_TIME" | head -n 1)
		
		# set LAST_ENTRY_TIME to current datetime if empty
		if [ -z "$LAST_ENTRY_TIME" ];then
			LAST_ENTRY_TIME=$(date +"%Y-%m-%dT%H:%M:%S.%3N")
		fi

		# convert timestamp
		LAST_ENTRY_SECONDS=$(date -d "$LAST_ENTRY_TIME" +%s)

		


		# calc timestamp diff
		TIME_DIFF_START=$((CURRENT_TIME - FIRST_LISTEN_SECONDS))
		
		# calc timestamp diff
		TIME_DIFF_SUCCESSOR=$((CURRENT_TIME - LAST_ENTRY_SECONDS))
		
		LAST_SIGNED_BY=$(grep "signed by" "$NODEOS_LOG_FILE" | tail -n 1 | sed -E 's/.*signed by ([^ ]+).*/\1/')

		# check if timestamp diff is less than 20 secs and greater than 5 secs. If so, local BP can be restarted
		if [ "$TIME_DIFF_SUCCESSOR" -le 20 ] && [ "$TIME_DIFF_SUCCESSOR" -gt 5 ]; then

			echo "info: last production date of BP successor $next_blockproducer was $TIME_DIFF_START secs ago."
			echo "info: seems to be safe to restart BP $current_blockproducer"
			if [ "$RESTART_FLAG" = true ]; then
				echo "info###restart initiated:$(date)### $response" >> $RESTART_LOG_FILE
				echo "info: restart initiated"
				$NODEOS_DIR/stop.sh
				$NODEOS_DIR/start.sh
				echo "info###restart finshed:$(date)### $response" >> $RESTART_LOG_FILE
				echo "info: BP $LOCAL_PRODUCER restarted"   			
				exit 0
			else
				echo "info: RESTART_FLAG=false - no restart initiated"
				echo "info###RESTART_FLAG=false - no restart initiated:(date)### $response" >> $RESTART_LOG_FILE
				echo "info: RESTART_FLAG=false - BP $LOCAL_PRODUCER not restarted"   	
				exit 0
			fi

		# exit script because sucessor has not appeared for 200 secs and node is running longer than 300 secs
		elif [ "$TIME_DIFF_SUCCESSOR" -gt 200 ] && [ "$TIME_DIFF_START" -gt 300 ]; then
			echo "TIME_DIFF_START $TIME_DIFF_START"
			echo "TIME_DIFF_SUCCESSOR $TIME_DIFF_SUCCESSOR"
			echo "error: exiting script because sucessor $next_blockproducer has not appeared for 300 secs in node logs"
			echo "error: please check if BPs where rescheduled or removed from scheduling (v1/chain/get_producer_schedule)"
			echo "error###restart initiated:$(date)### exiting script because sucessor $next_blockproducer has not appeared for 300 secs in node logs" >> $RESTART_LOG_FILE
			echo -e "To: $EMAIL_SENDER\nSubject: $EMAIL_SUBJECT \n\n exiting script because sucessor $next_blockproducer has not appeared for 300 secs in node logs.\n\n Please check v1/chain/get_producer_schedule" > $MAIL_TEMP_FILE
			ssmtp -v $EMAIL_RECEIVER < $MAIL_TEMP_FILE
			exit 1
		
		# wait for BP restart
		else
			echo "current BP is $LAST_SIGNED_BY"
			echo "node was restarted $TIME_DIFF_START secs ago"
			echo "last production date of BP successor $next_blockproducer was $TIME_DIFF_SUCCESSOR secs ago"
			echo "restart of BP $current_blockproducer is pending..." #$LAST_ENTRY
			echo ""
			sleep 1
		fi
	done
