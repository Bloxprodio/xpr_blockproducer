# xpr_blockproducer
scripts to maintain a XPR block producer node

## node_restart.sh
This script automates the restart of a local XPR block producer node. It extracts the name of the block producer from the configuration file of the node and checks whether it is included in the schedule of the active producer schedule. If the local producer is outside the schedule and not actively producing, the script restarts the block producer immediately. If the block producer is listed in the producer schedule, the script determines which block producer is next in line after the local block producer. Then it waits until this successor produces blocks and considers this moment as an opportunity to restart the local block producer.

## check_disk_space.sh
This script monitors disk usage on a Linux server, logs the current status, and compares it with previous data to identify changes. It writes both the current usage and the comparison details to respective log files. Warnings are generated if any disk's usage exceeds 60% or increases by 5% compared to the last run. All warnings are stored in a temporary file. If email alerts are enabled and warnings are found, it sends an email notification to a specified recipient with the alert details. This ensures proactive monitoring and alerting of potential disk space issues.

## create_snapshot.sh
IMPORTANT: YOU MUST NOT RUN A PUBLICLY ACCESSIBLE PRODUCER API ON A BLOCK PRODUCER NODE.

This script performs a snapshot creation for a Nodeos node. 
It requests a snapshot creation via the curl command and logs the activity in a log file.
The script analyzes the JSON response from the server to verify if the head_block_id field is present, indicating a successful snapshot creation.
If the field is missing, it logs an error message and exits with an error status.
Finally, the snapshot file is stored into the snapshot folder of node.
