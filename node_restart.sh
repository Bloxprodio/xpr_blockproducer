#!/bin/bash

################################################################################
# XPR Network node restart by Bloxprod.io
################################################################################
# This script is a restart for a block producer in a main or test network.
# Its primary function is to ensure that the nodeos service of block producer is not interupted during block producing
# --------------------------------------
# change log
# v0.9 - 2025-04-01 - initial version
#
# --------------------------------------
# Usage:
# ./node_restart.sh <parameter1>
#
# Parameters:
#   test - if script is started in test mode, the restart of node is skipped
#
# Example:
# ./node_restart.sh test
################################################################################



####################### start variable definition #######################

# set the network for which the Nodeos node works (TestNet | MainNet)
XPR_NET=TestNet

# server endpoint for v1/chain/get_producer_schedule
SERVER_URL_TESTNET="https://xpr-testnet-api.bloxprod.io"
SERVER_URL_MAINNET="https://xpr-mainnet-api.bloxprod.io"

# path und filenames
NODEOS_DIR="/opt/XPR$XPR_NET/xprNode"
NODEOS_CONFIG_FILE="$NODEOS_DIR/config.ini"
NODEOS_LOG_FILE="$NODEOS_DIR/stderr.txt"
RESTART_LOG_FILE="$NODEOS_DIR/restart_logfile.log"
MAIL_TEMP_FILE="$NODEOS_DIR/restart_mail_tempfile.txt"

# E-Mail parameters
# in case of unexpected error - send mail
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
	echo "info###RESTART_FLAG set to TRUE (date +%s)###" >> $RESTART_LOG_FILE
elif [ "$1" = "test" ]; then
	RESTART_FLAG=false
	echo "info: RESTART_FLAG set to FALSE"
	echo "info###RESTART_FLAG set to FALSE (date +%s)###" >> $RESTART_LOG_FILE
else
	echo "error: undefinded parameter "$1" found"
	echo "info###undefinded parameter "$1" found (date +%s)###" >> $RESTART_LOG_FILE
	exit 1
fi

if [ "$XPR_NET" = "MainNet" ]; then
	echo "info: XPR_NET variable set to MainNet"
	echo "info###XPR_NET variable set to MainNet (date +%s)###" >> $RESTART_LOG_FILE
	SERVER_URL="$SERVER_URL_MAINNET"
elif  [ "$XPR_NET" = "TestNet" ]; then
	echo "info: XPR_NET variable set to TestNet"
	echo "info###XPR_NET variable set to TestNet (date +%s)###" >> $RESTART_LOG_FILE
	SERVER_URL="$SERVER_URL_TESTNET"
else
	echo "error: XPR_NET variable is neither set to MainNet nor to TestNet"
	echo "info###XPR_NET variable set to TestNet (date +%s)###" >> $RESTART_LOG_FILE
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
		echo "info###restart initiated:$(date +%s)### $response" >> $RESTART_LOG_FILE
   		if [ "$RESTART_FLAG" = "true" ]; then
			echo "info: restart initiated"
			$NODEOS_DIR/stop.sh
			$NODEOS_DIR/start.sh
			echo "info###restart finshed:(date +%s)### $response" >> $RESTART_LOG_FILE
			echo "info: BP $LOCAL_PRODUCER restarted"   			
			exit 0
		else
			echo "info: RESTART_FLAG=false - no restart initiated"
			echo "info###RESTART_FLAG=false - no restart initiated:(date +%s)### $response" >> $RESTART_LOG_FILE
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

		# find last entry
		LAST_ENTRY=$(grep "$SEARCH_ENTRY" "$NODEOS_LOG_FILE" | tail -n 1)

		# extract timestamp from last entry
		LAST_ENTRY_TIME=$(echo "$LAST_ENTRY" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}\.[0-9]{3}')
		
		# ensure that timestamp was exttracted only once
		LAST_ENTRY_TIME=$(echo "$LAST_ENTRY_TIME" | head -n 1)

		# convert timestamp
		LAST_ENTRY_SECONDS=$(date -d "$LAST_ENTRY_TIME" +%s)
	
		# calc timestamp diff
		TIME_DIFF=$((CURRENT_TIME - LAST_ENTRY_SECONDS))
		
		LAST_SIGNED_BY=$(grep "signed by" "$NODEOS_LOG_FILE" | tail -n 1 | sed -E 's/.*signed by ([^ ]+).*/\1/')

		# check if timestamp diff is less than 20 secs and greater than 5 secs. If so, local BP can be restarted
		if [ "$TIME_DIFF" -le 20 ] && [ "$TIME_DIFF" -gt 5 ]; then

			echo "info: last production date of BP successor $next_blockproducer was $TIME_DIFF secs ago."
			echo "info: seems to be safe to restart BP $current_blockproducer"
			echo "info: restart initiated"
			echo "info###restart initiated:$(date +%s)### $response" >> $RESTART_LOG_FILE
			if [ "$RESTART_FLAG" = true ]; then
				echo "info: restart initiated"
				$NODEOS_DIR/stop.sh
				$NODEOS_DIR/start.sh
				echo "info###restart finshed:(date +%s)### $response" >> $RESTART_LOG_FILE
				echo "info: BP $LOCAL_PRODUCER restarted"   			
				exit 0
			else
				echo "info: RESTART_FLAG=false - no restart initiated"
				echo "info###RESTART_FLAG=false - no restart initiated:(date +%s)### $response" >> $RESTART_LOG_FILE
				echo "info: RESTART_FLAG=false - BP $LOCAL_PRODUCER not restarted"   	
				exit 0
			fi

		# exit script because sucessor has not appeared for 300 secs
		elif [ "$TIME_DIFF" -gt 300 ]; then
			echo "error: exiting script because sucessor $next_blockproducer has not appeared for 300 secs in node logs"
			echo "error: please check if BPs where rescheduled or removed from scheduling (v1/chain/get_producer_schedule)"
			echo "error###restart initiated:$(date +%s)### exiting script because sucessor $next_blockproducer has not appeared for 300 secs in node logs" >> $RESTART_LOG_FILE
			echo -e "To: $EMAIL_SENDER\nSubject: $EMAIL_SUBJECT \n\n exiting script because sucessor $next_blockproducer has not appeared for 300 secs in node logs.\n\n Please check v1/chain/get_producer_schedule" > $MAIL_TEMP_FILE
			ssmtp -v $EMAIL_RECEIVER < $MAIL_TEMP_FILE
			exit 1
		
		# wait for BP restart
		else
			echo "current BP is $LAST_SIGNED_BY"
			echo "last production date of BP successor $next_blockproducer was $TIME_DIFF secs ago"
			echo "restart of BP $current_blockproducer is pending..." #$LAST_ENTRY
			echo ""
			sleep 1
		fi
	done

