#!/bin/bash

if [ "$1" = "--help" ]
then
	echo "Usage $(basename $0) [<save dir absolute path>]" >&2
	exit 1
fi


if [ "$JAVA_HOME" = "" ]
then
	echo "ERROR: JAVA_HOME is not set" >&2
	exit 1
fi
export PATH=$JAVA_HOME/bin:$PATH

[ "$TOMCAT_ROOT" = "" ] && TOMCAT_ROOT=$(dirname $0)
TOMCAT_ROOT=$(realpath $TOMCAT_ROOT)
echo "Tomcat root: $TOMCAT_ROOT"

export JAVA_OPTS="$JAVA_OPTS -Dfile.encoding=UTF-8"

SAVE_DIR=${1:-TOMCAT_ROOT/webapps/${TOMCAT_WEBAPP:-ROOT}/WEB-INF/save}
[ ! -d $SAVE_DIR ] && mkdir $SAVE_DIR
if [ ! -w $SAVE_DIR ]
then
	echo "ERROR: Save directory is not writable ($SAVE_DIR)" >&2
	exit 2
fi

WEBINF_DIR=$TOMCAT_ROOT/webapps/${TOMCAT_WEBAPP:-ROOT}/WEB-INF
DB_DIR=$WEBINF_DIR/db
DBDOC_DIR=$WEBINF_DIR/dbdoc

[ "$DB_VENDOR" = "" ] && DB_VENDOR=hsqldb
[ "$DB_VENDOR" = "mariadb" ] && DB_VENDOR=mysql
[ "$DB_VENDOR" = "pgsql" -o "$DB_VENDOR" = "postgres" ] && DB_VENDOR=postgresql
[ "$DB_VENDOR" = "sqlserver" ] && DB_VENDOR=mssql
echo "Database vendor: $DB_VENDOR"

TOMCAT_PID=$(ps -u $(whoami) | grep -v grep | grep java | awk '{print $1}')
if [ "$TOMCAT_PID" != "" ]
then
	echo "Suspending Tomcat process $TOMCAT_PID"
	kill -STOP $TOMCAT_PID
	echo "Done"
fi

DATE=$(date +%Y%m%d%H%M%S)
DMP=""

if [ $DB_VENDOR = "hsqldb" ]
then
	echo "HSQLDB database: Embedded"
	rm -f $SAVE_DIR/simplicite-hsqldb.$DATE.tar.gz
	pushd $WEBINF_DIR > /dev/null
	tar --exclude='db/simplicite-mysql*' --exclude='db/simplicite-postgresql*' --exclude='db/simplicite-mssql*' --exclude='db/simplicite-oracle*' -c -f $SAVE_DIR/simplicite-hsqldb.$DATE.tar.gz $(basename $DB_DIR) $(basename $DBDOC_DIR)
	popd > /dev/null
	RET=0
elif [ $DB_VENDOR = "mysql" ]
then
	[ "$DB_HOST" = "" ] && DB_HOST=127.0.0.1
	[ "$DB_PORT" = "" ] && DB_PORT=3306
	echo "MySQL database: $DB_HOST / $DB_PORT / $DB_NAME / $DB_USER"
	DMP=$SAVE_DIR/simplicite-mysql.$DATE.dmp
	mysqldump --host=$DB_HOST --port=$DB_PORT --user=$DB_USER --password=$DB_PASSWORD $DB_NAME > $DMP
	RET=$?
elif [ $DB_VENDOR = "postgresql" ]
then
	[ "$DB_HOST" = "" ] && DB_HOST=127.0.0.1
	[ "$DB_PORT" = "" ] && DB_PORT=5432
	echo "PostgreSQL database: $DB_HOST / $DB_PORT / $DB_NAME / $DB_USER"
	DMP=$SAVE_DIR/simplicite-postgresql.$DATE.dmp
	PGPASSWORD=$DB_PASSWORD pg_dump -h $DB_HOST -p $DB_PORT -U $DB_USER $DB_NAME --no-owner --clean > $DMP
	RET=$?
elif [ $DB_VENDOR = "oracle" ]
then
	[ "$DB_HOST" = "" ] && DB_HOST=127.0.0.1
	[ "$DB_PORT" = "" ] && DB_PORT=1521
	echo "Oracle database: $DB_HOST / $DB_PORT / $DB_NAME / $DB_USER"
	DMP=$SAVE_DIR/simplicite-oracle.dmp
	exp $DB_USER/$DB_PASSWORD@//$DB_HOST:$DB_PORT/$DB_NAME file=$DMP log=$SAVE_DIR/simplicite-oracle.log owner=$DB_USER
	RET=$?
elif [ $DB_VENDOR = "mssql" ]
then
	[ "$DB_HOST" = "" ] && DB_HOST=127.0.0.1
	[ "$DB_PORT" = "" ] && DB_PORT=1433
	echo "SQLServer database: $DB_HOST / $DB_PORT / $DB_NAME / $DB_USER"
	DMP=$SAVE_DIR/simplicite-mssql.dmp
	sqlcmd -S $DB_HOST,$DB_PORT -U $DB_USER -P $DB_PASSWORD -b -Q "backup database $DB_NAME to disk='$DMP' with no_log"
	RET=$?
else
	echo "ERROR: Unknown database vendor ($DB_VENDOR)" >&2
	RET=4
fi

if [ "$TOMCAT_PID" != "" ]
then
	echo "Resuming Tomcat process $TOMCAT_PID"
	kill -CONT $TOMCAT_PID
	echo "Done"
fi

if [ "$DMP" != "" ]
then
	echo "GZipping dump file"
	gzip $DMP
	echo "Done"
fi

exit $RET
