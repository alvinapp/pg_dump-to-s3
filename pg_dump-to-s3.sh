#!/bin/bash

#                     _                             _                  _____ 
#  _ __   __ _     __| |_   _ _ __ ___  _ __       | |_ ___        ___|___ / 
# | '_ \ / _` |   / _` | | | | '_ ` _ \| '_ \ _____| __/ _ \ _____/ __| |_ \ 
# | |_) | (_| |  | (_| | |_| | | | | | | |_) |_____| || (_) |_____\__ \___) |
# | .__/ \__, |___\__,_|\__,_|_| |_| |_| .__/       \__\___/      |___/____/ 
# |_|    |___/_____|                   |_|                                   
#
# Project at https://github.com/gabfl/pg_dump-to-s3
#

set -e

# Set current directory
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Import config file
source $DIR/pg_dump-to-s3.conf

# Vars
NOW=$(date +"%Y-%m-%d-at-%H-%M-%S")
DELETETION_TIMESTAMP=`[ "$(uname)" = Linux ] && date +%s --date="-$DELETE_AFTER"` # Maximum date (will delete all files older than this date)

# Split databases
IFS=',' read -ra DBS <<< "$PG_DATABASES"

# Delete old files
echo " * Backup in progress.,.";

DIRECTORY_NAME="DATABASE_BACKUP_$NOW"

mkdir -p /tmp/"$DIRECTORY_NAME"/

# Loop thru databases
for db in "${DBS[@]}"; do

    echo "   -> backing up $db..."

    # Dump database
    pg_dump -h $PG_HOST -U $PG_USER -p $PG_PORT $db > /tmp/"$DIRECTORY_NAME"/$db.sql

    tar -C /tmp/ -czf /tmp/"$DIRECTORY_NAME".tar.gz  /tmp/"$DIRECTORY_NAME"/

    # Copy to S3
    aws s3 cp /tmp/"$DIRECTORY_NAME".tar.gz s3://$S3_PATH/"$DIRECTORY_NAME".tar.gz --storage-class STANDARD_IA

    # Delete local file
    rm -rf /tmp/"$DIRECTORY_NAME".tar.gz

    # Log
    echo "      ...database $db has been backed up"
done

# Delete old files
echo " * Deleting old backups...";

# Loop thru files
aws s3 ls s3://$S3_PATH/ | while read -r line;  do
    # Get file creation date
    createDate=`echo $line|awk {'print $1" "$2'}`
    createDate=`date -d"$createDate" +%s`

    if [[ $createDate -lt $DELETETION_TIMESTAMP ]]
    then
        # Get file name
        FILENAME=`echo $line|awk {'print $4'}`
        if [[ $FILENAME != "" ]]
          then
            echo "   -> Deleting $FILENAME"
            aws s3 rm s3://$S3_PATH/$FILENAME
        fi
    fi
done;

echo ""
echo "...done!";
echo ""
