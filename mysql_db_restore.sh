###### This script is for automatically restore user databases from souce to destination MySQL Instance ######
### Created in Ubuntu server ###
### This automation is intended for MySQL purposes ###

#!/bin/bash

# MySQL credentials for restoration
MYSQL_HOST=""           # Change to your MySQL server
MYSQL_PORT="3306"       # Change if the MySQL port is different
MYSQL_USER=""           # Change to your MySQL username
MYSQL_PASS=""           # Change to your MySQL password

# Backup directory
BACKUP_DIR="" # Set based on the location of database backup
LOG_FILE="$BACKUP_DIR/mysql_db_restore.log"

# Remove the log file if it already exists
[ -f "$LOG_FILE" ] && rm "$LOG_FILE"

# Start restore process
echo "$(date '+%Y-%m-%d %H:%M:%S') - Starting restore of multiple databases..." >> "$LOG_FILE"

# Disable foreign key checks
mysql -h $MYSQL_HOST -P $MYSQL_PORT -u $MYSQL_USER -p$MYSQL_PASS -e "SET GLOBAL FOREIGN_KEY_CHECKS=0;"

# Loop through each database directory
for DB_DIR in "$BACKUP_DIR"/*/; do
    DB=$(basename "$DB_DIR")

    # Get the latest date folder for this DB
    LATEST_DATE_DIR=$(find "$DB_DIR" -type d -printf "%P\n" | sort -r | head -n 1)
    LATEST_BACKUP_DIR="$DB_DIR/$LATEST_DATE_DIR"

    # Get the latest backup file for this DB
    LATEST_BACKUP_FILE=$(ls -t "$LATEST_BACKUP_DIR/${DB}_"*.sql 2>/dev/null | head -n 1)

    if [ -f "$LATEST_BACKUP_FILE" ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Restoring $DB from $LATEST_BACKUP_FILE" >> "$LOG_FILE"

        # Drop and recreate the database
        mysql -h $MYSQL_HOST -P $MYSQL_PORT -u $MYSQL_USER -p$MYSQL_PASS -e "DROP DATABASE IF EXISTS \`$DB\`; CREATE DATABASE \`$DB\`;"

        # Restore
        mysql --verbose -h $MYSQL_HOST -P $MYSQL_PORT -u $MYSQL_USER -p$MYSQL_PASS "$DB" < "$LATEST_BACKUP_FILE"

        if [ $? -eq 0 ]; then
            echo "$(date '+%Y-%m-%d %H:%M:%S') - Restore successful: $DB" >> "$LOG_FILE"
        else
            echo "$(date '+%Y-%m-%d %H:%M:%S') - Restore failed: $DB" >> "$LOG_FILE"
        fi
    else
        echo "$(date '+%Y-%m-%d %H:%M:%S') - No backup found for $DB in $LATEST_BACKUP_DIR" >> "$LOG_FILE"
    fi
done

echo "$(date '+%Y-%m-%d %H:%M:%S') - All restores completed." >> "$LOG_FILE"

# Re-enable foreign key checks
mysql -h $MYSQL_HOST -P $MYSQL_PORT -u $MYSQL_USER -p$MYSQL_PASS -e "SET GLOBAL FOREIGN_KEY_CHECKS=1;"

## Open crontab -e ##
#Schedule this job to run depending on your requirements
0 7 * * * /<script location>/mysql_db_restore.sh
