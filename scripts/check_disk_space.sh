#!/bin/bash

################################################################################
# XPR Network node disk free check by Bloxprod.io
################################################################################
# Script Name: check_disk_space.sh
# Version: v0.9.0
# Author: bloxprod.io
# Date: 2025-04-16
#
# Description:
# The script monitors disk usage, comparing current values to previous ones stored in a history file.
# It generates warnings if usage exceeds 60% or increases by 5% and saves them in a temporary file.
# If email alerts are enabled, it sends a notification with the warnings to a specified recipient.
# --------------------------------------
# change log
# v0.9.0 - 2025-04-16 - initial version
#
# --------------------------------------
# Usage:
# ./check_disk_space.sh
#
# Dependencies:
# 1. install and configure ssmtp
# 	1.1 apt install ssmtp
# 	1.2 add your SMTP server details to /etc/ssmtp/ssmtp.config
# 	1.3 define sender addresses for user in /etc/ssmtp/revaliases
#
#
# 5. change path of nodeos home dir (if this is not /opt/XPRMainNet/xprNode | /opt/XPRTestNet/xprNode)
# 	5.1 CHECK_HOME_DIR
#
# 6. define e-mail parameters
#	6.1 SEND_EMAIL ( true | false )
# 	6.2 EMAIL_RECEIVER
#	6.3 EMAIL_SENDER
# 	6.4 EMAIL_SUBJECT
#
# Script Parameters:
#   no parameters
#
# Example:
# ./check_disk_space.sh
#
# before starting script, check values and settings of section "variable definition"
################################################################################



####################### start variable definition #######################

### path und filenames
# nodeos base dir
CHECK_HOME_DIR="/opt/XPRTestNet/xprNode"
# file to log actual df status
DF_COMPARISON_FILE="$CHECK_HOME_DIR/df_comparison.txt"
# file to df history
DF_HISTORY_FILE="$CHECK_HOME_DIR/df_history.txt"
# temp file to generate outgoinfg mail body
DF_TEMP_FILE="$CHECK_HOME_DIR/df_temp_file.txt"
# temp file to generate outgoinfg mail body
MAIL_TEMP_FILE="$CHECK_HOME_DIR/df_alert.txt"


### e-mail parameters
## parameters to send e-mails in case of errors
# send e-mail in case of error( true | false )
SEND_EMAIL=true
# receiver e-mail
EMAIL_RECEIVER="rcv_mail@example.com"
# sender e-mail
EMAIL_SENDER="rcv_mail@example.com"
# e-mail subject
EMAIL_SUBJECT="disk free issue on BloxProd API Server"

####################### end variable definition #######################

# Check if the comparison file exists; if not, create it
if [ -e $DF_COMPARISON_FILE ]; then
	touch $DF_COMPARISON_FILE
fi

# Check if the history file exists; if not, create it
if [ -e $DF_HISTORY_FILE ]; then
	touch $DF_HISTORY_FILE
fi

# Check if the temporary mail file exists; if yes, remove it
if [ -e $MAIL_TEMP_FILE ]; then
	rm $MAIL_TEMP_FILE
fi

# Check if the temporary disk file exists; if yes, remove it
if [ -e $DF_TEMP_FILE ]; then
	rm $DF_TEMP_FILE
fi

# Retrieve disk usage information
df_output=$(df -h)

# Save the current date and disk usage data into the history file
current_date=$(date +"%Y-%m-%d %H:%M:%S")
echo "$current_date" >> $DF_HISTORY_FILE
echo "$df_output" | awk 'NR>1 {print $1":"$6, $5}' >> $DF_HISTORY_FILE
echo "#######################" >> $DF_HISTORY_FILE

# Loop through disk usage data to compare current values with previous entries
while read -r line; do
  device=$(echo $line | awk '{print $1}')  # Extract the device name
  current_use=$(echo $line | awk '{print $2}' | tr -d '%')  # Extract current usage percentage
  previous_use=$(grep $device df_history.txt | tail -n 2 | head -n 1 | awk '{print $2}' | tr -d '%')  # Extract previous usage percentage

  if [ -n "$previous_use" ]; then
    use_change=$(($current_use - $previous_use))  # Calculate the change in usage
	echo "$current_date" >> $DF_COMPARISON_FILE
    echo "$device: current use = $current_use%, previous use = $previous_use%, change = $use_change%" >> $DF_COMPARISON_FILE
	echo "#######################" >> $DF_COMPARISON_FILE
    
    # Warning if current usage is greater than or equal to 60%
    if [ "$current_use" -ge 60 ]; then
	echo "WARNING: $device has usage of $current_use%"
      echo "WARNING: $device has usage of $current_use%" >> $DF_TEMP_FILE
    fi

    # Warning if usage has increased by 5% or more
    if [ "$use_change" -ge 5 ]; then
      echo "WARNING: $device has increased usage by $use_change% (from $previous_use% to $current_use%)!" >> $DF_TEMP_FILE
    fi
  fi
done <<< "$(echo "$df_output" | awk 'NR>1 {print $1":"$6, $5}')"

# Send an email if email sending is enabled and temporary disk file is not empty
if [ "$SEND_EMAIL" = true ] && [ -s $DF_TEMP_FILE ]; then
	echo -e "To: $EMAIL_SENDER\nSubject: $EMAIL_SUBJECT \n\n Please check disk status and space." > $MAIL_TEMP_FILE
	cat $DF_TEMP_FILE >> $MAIL_TEMP_FILE
	ssmtp -v $EMAIL_RECEIVER < $MAIL_TEMP_FILE
fi
