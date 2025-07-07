###### This script is for automatically backup user databases from MySQL Instance ######
### Created in Ubuntu server ###
### This automation is intended for MySQL purposes ###

#!/bin/bash

# Remote MySQL credentials
REMOTE_HOST="localhost"    # Change to your remote server
REMOTE_PORT="3306"         # Change if the MySQL port is different
REMOTE_USER=""             # Change to your MySQL username
REMOTE_PASS=""             # Change to your MySQL password

# Backup directory
BACKUP_DIR=""   # Set location of database backup

# Timestamps
DATE_DIR=$(date +"%Y-%m-%d")
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Retention settings
RETENTION_DAYS=7

echo "[$(date)] Starting MySQL full backup process..."

# Retention Policy - Delete backup folders older than x number of days
echo "[$(date)] Applying retention policy: Keeping backups from last $RETENTION_DAYS days..."

for DB_DIR in "$BACKUP_DIR"/*/; do
    [ -d "$DB_DIR" ] || continue
    DB=$(basename "$DB_DIR")
    
    echo "[$(date)] Checking old backups for database: $DB"
    
    OLD_DIRS=$(find "$DB_DIR" -maxdepth 1 -type d -name "20*" -mtime +$RETENTION_DAYS)

    if [ -z "$OLD_DIRS" ]; then
        echo "[$(date)] No old backups to remove for $DB"
    else
        for DIR in $OLD_DIRS; do
            echo "[$(date)] Deleting old backup folder: $DIR"
            rm -rf "$DIR"
        done
    fi
done

######################################################################################################

# Ensure the backup directory exists
mkdir -p "$BACKUP_DIR"

# Fetch all databases from production (excluding system databases)
DATABASES=$(mysql -h $REMOTE_HOST -P $REMOTE_PORT -u $REMOTE_USER -p$REMOTE_PASS -e "SHOW DATABASES;" | grep -Ev "(Database|information_schema|performance_schema|mysql|sys|phpmyadmin)")

# Start backup process
echo "[$(date)] Starting full backups..."

for DB in $DATABASES; do
    DB_DATE_DIR="$BACKUP_DIR/$DB/$DATE_DIR"
    mkdir -p "$DB_DATE_DIR"

    BACKUP_FILE="$DB_DATE_DIR/${DB}_${TIMESTAMP}.sql"

    echo "[$(date)] Backing up: $DB -- $BACKUP_FILE"

    # Perform backup with --verbose for debugging
    mysqldump --verbose -h $REMOTE_HOST -P $REMOTE_PORT -u $REMOTE_USER -p$REMOTE_PASS --single-transaction --quick --routines --triggers --events $DB > "$BACKUP_FILE"

    if [ $? -eq 0 ]; then
        echo "Backup successful: $BACKUP_FILE"
    else
        echo "Backup failed for database: $DB"
        rm -f "$BACKUP_FILE"
    fi
done

echo "[$(date)] All backups completed."

## Open crontab -e ##
#Schedule this job to run depending on your requirements
0 7 * * * /<script location>/mysql_db_backup.sh > /<destination log path>/mysql_db_backup.log 2>&1
