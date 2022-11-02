#!/bin/bash

SERVER="MY_SERVER"
DAYS_TO_BACKUP=30
WORKING_DIR="/mega_tmp_dir"

BACKUP_MYSQL="true"
MYSQL_USER=""
MYSQL_PASSWORD=""

DOMAINS_FOLDER="/home"

MEGA_BACKUP_DIR="BACKUP"

##################################
# Create local working directory and collect all data
##################################
rm -rf ${WORKING_DIR}
mkdir ${WORKING_DIR}

cd - > /dev/null

##################################
# Backup MySQL
##################################
if [ "${BACKUP_MYSQL}" = "true" ]
then
        mkdir ${WORKING_DIR}/mysql
        for db in $(mysql -u${MYSQL_USER} -p${MYSQL_PASSWORD} -e 'show databases;' | grep -Ev "^(Database|mysql|information_schema|performance_schema|phpmyadmin|sys)$")
        do
                echo "processing ${db}"
                mysqldump --single-transaction -u${MYSQL_USER} -p${MYSQL_PASSWORD} "${db}" | gzip > ${WORKING_DIR}/mysql/${db}_$(date +%F).sql.gz
        done
        #echo "Backup all db now"
        #mysqldump --single-transaction -u${MYSQL_USER} -p${MYSQL_PASSWORD} --events --ignore-table=mysql.event --all-databases | gzip > ${WORKING_DIR}/mysql/ALL_DATABASES_$(date +%F).sql.gz
fi

##################################
# Backup domains
##################################
mkdir ${WORKING_DIR}/domains
for folder in $(find ${DOMAINS_FOLDER} -mindepth 1 -maxdepth 1 -type d)
do
        cd $(dirname ${folder})
        tar cJf ${WORKING_DIR}/domains/$(basename ${folder})_$(date +%F).tar.xz $(basename ${folder})
        cd - > /dev/null
done

##################################
# Workaround to prevent dbus error messages
##################################
export $(dbus-launch)

# Create base backup folder
[ -z "$(mega-ls -r /${MEGA_BACKUP_DIR}/${SERVER})" ] && mega-mkdir /${MEGA_BACKUP_DIR}/${SERVER}

# Remove old logs
while [ $(mega-ls -r /${MEGA_BACKUP_DIR}/${SERVER} | grep -E "/${MEGA_BACKUP_DIR}/${SERVER}/[0-9]{4}-[0-9]{2}-[0-9]{2}$" | wc -l) -gt ${DAYS_TO_BACKUP} ]
do
        TO_REMOVE=$(mega-ls -r /${MEGA_BACKUP_DIR}/${SERVER} | grep -E "/${MEGA_BACKUP_DIR}/${SERVER}/[0-9]{4}-[0-9]{2}-[0-9]{2}$" | sort | head -n 1)
        mega-rm ${TO_REMOVE}
done

# Create remote folder
curday=$(date +%F)
mega-mkdir -p /${MEGA_BACKUP_DIR}/${SERVER}/${curday} 2> /dev/null

# Backup now!!!
mega-put ${WORKING_DIR}/* /${MEGA_BACKUP_DIR}/${SERVER}/${curday} > /dev/null

# Kill DBUS session daemon (workaround)
kill ${DBUS_SESSION_BUS_PID}
rm -f ${DBUS_SESSION_BUS_ADDRESS}

# Clean local environment
rm -rf ${WORKING_DIR}
exit 0
