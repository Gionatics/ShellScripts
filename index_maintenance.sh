###### This script is for index maintenance of MySQL ######
### Created in Ubuntu server ###
### This automation is intended for MySQL purposes ###

#!/bin/bash

# MySQL Credentials based from your setup
DB_USER=""
DB_PASS=""
DB_HOST="localhost"

# Log File
LOG_FILE="" ##Set your log path location

# Clear log file contents
> "$LOG_FILE"

# Get all user databases (excluding system databases)
DATABASES=$(mysql -u$DB_USER -p$DB_PASS -h$DB_HOST -e "
    SELECT schema_name
    FROM information_schema.schemata
    WHERE schema_name NOT IN ('mysql', 'performance_schema', 'information_schema', 'sys');
" | tail -n +2)

# Timestamp
echo "==== MySQL Index Maintenance Started: $(date) ====" | tee -a "$LOG_FILE"

# Loop through each database
for DB_NAME in $DATABASES; do
    echo "Processing database: $DB_NAME" | tee -a "$LOG_FILE"

    # Step 1: Get tables in the database
    TABLES=$(mysql -u$DB_USER -p$DB_PASS -h$DB_HOST -D$DB_NAME -e "
        SELECT table_name
        FROM information_schema.tables
        WHERE table_schema='$DB_NAME';
    " | tail -n +2)

    # Step 2: Run ANALYZE and OPTIMIZE only if necessary
    for TABLE in $TABLES; do
        # Get the table engine
        ENGINE=$(mysql -u$DB_USER -p$DB_PASS -h$DB_HOST -D$DB_NAME -e "
            SELECT ENGINE FROM information_schema.tables
            WHERE table_schema='$DB_NAME' AND table_name='$TABLE';
        " | tail -n +2)

        echo "Analyzing $TABLE in $DB_NAME..." | tee -a "$LOG_FILE"
        mysql -u$DB_USER -p$DB_PASS -h$DB_HOST -D$DB_NAME -e "ANALYZE TABLE $TABLE;" | tee -a "$LOG_FILE"

        if [[ "$ENGINE" == "MyISAM" ]]; then
            echo "Optimizing $TABLE in $DB_NAME (MyISAM)..." | tee -a "$LOG_FILE"
            mysql -u$DB_USER -p$DB_PASS -h$DB_HOST -D$DB_NAME -e "OPTIMIZE TABLE $TABLE;" | tee -a "$LOG_FILE"
        else
            echo "Skipping OPTIMIZE for $TABLE (InnoDB does not need it)." | tee -a "$LOG_FILE"
        fi
    done

    # Step 3: Identify Duplicate Indexes
    echo "Checking for duplicate indexes in $DB_NAME..." | tee -a "$LOG_FILE"
    mysql -u$DB_USER -p$DB_PASS -h$DB_HOST -D$DB_NAME -e "
        SELECT TABLE_NAME, INDEX_NAME, GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX) AS columns
        FROM information_schema.STATISTICS
        WHERE TABLE_SCHEMA = '$DB_NAME'
        GROUP BY TABLE_NAME, INDEX_NAME
        HAVING COUNT(*) > 1;
    " | tee -a "$LOG_FILE"

    echo "Completed maintenance for database: $DB_NAME" | tee -a "$LOG_FILE"
done

# Completion Log
echo "==== MySQL Index Maintenance Completed: $(date) ====" | tee -a "$LOG_FILE"

## Open crontab -e ##
#Schedule this job to run depending on your requirements
0 1 * * 0 /<script location>/index_maintenance.sh
