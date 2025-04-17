# xpr_blockproducer
scripts to maintain a XPR block producer node

## node_restart.sh
This script automates the restart of a local XPR block producer node. It extracts the block producer's name from the node configuration file and checks its presence in the active producer schedule fetched from the API. If the local producer is out of schedule or not producing, it restarts the block producer while logging all actions. The script checks whether the successor block producer is producing and considers this moment as an opportunity to restart the local block producer. It ensures that only valid JSON responses are processed and can send email alerts for errors like invalid schedules or missing successors. It continuously monitors the node logs for specific entries, calculating time differences and determining if a safe restart is possible. If critical conditions arise, the script either sends notifications or exits to avoid disruptions or uncontrolled restarts.

## check_disk_space.sh
This script monitors disk usage on a Linux server, logs the current status, and compares it with previous data to identify changes. It writes both the current usage and the comparison details to respective log files. Warnings are generated if any disk's usage exceeds 60% or increases by 5% compared to the last run. All warnings are stored in a temporary file. If email alerts are enabled and warnings are found, it sends an email notification to a specified recipient with the alert details. This ensures proactive monitoring and alerting of potential disk space issues.
