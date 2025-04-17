#!/bin/bash

################################################################################
# XPR Network create snapshot by Bloxprod.io
################################################################################
# Script Name: create_snapshot.sh
# Version: v0.9.0
# Author: bloxprod.io
# Date: 2025-04-13
#
# Description:
# IMPORTANT: YOU MUST NOT RUN A PUBLICLY ACCESSIBLE PRODUCER API ON A BLOCK PRODUCER NODE.
# This script performs a snapshot creation for a Nodeos node. 
# It requests a snapshot creation via the curl command and logs the activity in a log file.
# The script analyzes the JSON response from the server to verify if the head_block_id field is present, indicating a successful snapshot creation.
# If the field is missing, it logs an error message and exits with an error status.
# Finally, the snapshot file is stored into the snapshot folder of node.
#
# --------------------------------------
# change log
# v0.9 - 2025-04-17 - initial version
# --------------------------------------
# Usage:
# ./create_snapshot.sh
#
# Dependencies:
#
# 1. install curl
#	1.1 apt install curl
#
# 2. install jq utility ( to parse and manipulate JSON data)
# 	2.1 apt install jq
#
# 3. enter your favorite server for calling the v1/producer/create_snapshot api
# 	3.1 SERVER_URL_PRODUCER_API
#
#
# Script Parameters:
#   no parameters
#
# Example:
# ./create_snapshot.sh
#
# before starting script, check values and settings of section "variable definition"
# 
################################################################################


####################### start variable definition #######################

### set the network for which the Nodeos node works (TestNet | MainNet)
XPR_NET=TestNet

### path und filenames
# nodeos base dir
NODEOS_DIR="/opt/XPR$XPR_NET/xprNode"
# log file to log script activities
SNAPSHOT_LOG_FILE="$NODEOS_DIR/snapshot_logfile.log"


### server endpoint for /v1/producer/create_snapshot
SERVER_URL_PRODUCER_API="http://api.bloxprodio:8817"

####################### end variable definition #######################


echo "##############################################"
# check if curl is installed
if command -v curl >/dev/null 2>&1; then
	echo "$(date):info: curl is installed and ready to use."
	echo "$(date):info: curl is installed and ready to use' ###" >> $SNAPSHOT_LOG_FILE
else
  echo "$(date):error: curl is not installed. Please install it using 'sudo apt install curl'"
  echo "$(date):error: curl is not installed. Please install it using 'sudo apt install curl' ###" >> $SNAPSHOT_LOG_FILE
  exit 1
fi

# define the URL
URL="$SERVER_URL_PRODUCER_API/v1/producer/create_snapshot"

# run the curl command and capture the response
response=$(curl "$URL")


# Check if 'head_block_id' field exists in the JSON
if echo "$response" | jq -e '.head_block_id? // empty' > /dev/null; then
    echo "Success: Snapshot creation request was successful."
	echo "$(date):error: Snapshot creation request was successful"
	echo "$(date):error: Snapshot creation request was successful ###" >> $SNAPSHOT_LOG_FILE
else
	echo "$(date):error: Failed to create snapshot."
	echo "$(date):error: Failed to create snapshot. HTTP status code: $response ###" >> $SNAPSHOT_LOG_FILE
	echo $response
    exit 1
fi

exit 0
