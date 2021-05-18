#!/bin/bash

if [ "$JAVA_HOME" = "" ]
then
	echo "JAVA_HOME is not set" >&2
	exit 1
fi
export PATH=$JAVA_HOME/bin:$PATH

[ "$TOMCAT_ROOT" = "" ] && TOMCAT_ROOT=`dirname $0`
TOMCAT_ROOT=`realpath $TOMCAT_ROOT`
echo "Tomcat root: $TOMCAT_ROOT"

export JAVA_OPTS="$JAVA_OPTS -Dfile.encoding=UTF-8"

DB_DIR=$DB_DIR/webapps/${TOMCAT_WEBAPP:-ROOT}/WEB-INF/db
if [ ! -d $DB_DIR ]
then
	echo "No database dir: $DB_DIR" >&2
	exit 2
fi

[ "$DB_VENDOR" = "" ] && DB_VENDOR=hsqldb
[ "$DB_VENDOR" = "mariadb" ] && DB_VENDOR=mysql
[ "$DB_VENDOR" = "pgsql" -o "$DB_VENDOR" = "postgres" ] && DB_VENDOR=postgresql
[ "$DB_VENDOR" = "sqlserver" ] && DB_VENDOR=mssql
echo "Database vendor: $DB_VENDOR"

if [ $DB_VENDOR = "mysql" ]
then
	echo "HSQLDB database: Embedded"
	# Nothing to do
	exit 0
elif [ $DB_VENDOR = "mysql" ]
then
	[ "$DB_PORT" = "" ] && DB_PORT=3306
	echo "MySQL database: $DB_HOST / $DB_PORT / $DB_NAME / $DB_USER"
	mysqldump --host=$DB_HOST --port=$DB_PORT --user=$DB_USER --password=$DB_PASSWORD $DB_NAME > $DB_DIR/simplicite-mysql.dmp
	exit $?
elif [ $DB_VENDOR = "postgresql" ]
then
	[ "$DB_PORT" = "" ] && DB_PORT=5432
	echo "PostgreSQL database: $DB_HOST / $DB_PORT / $DB_NAME / $DB_USER"
	PGPASSWORD=$DB_PASSWORD pg_dump -h $DB_HOST -p $DB_PORT -U $DB_USER $DB_NAME --no-owner --clean > $DB_DIR/simplicite-postgresql.dmp
	exit $?
elif [ $DB_VENDOR = "oracle" ]
then
	[ "$DB_PORT" = "" ] && DB_PORT=1521
	echo "Oracle database: $DB_HOST / $DB_PORT / $DB_NAME / $DB_USER"
	exp $DB_USER/$DB_PASSWORD@//$DB_HOST:$DB_PORT/$DB_NAME file=$DB_DIR/simplicite-oracle.dmp log=$DB_DIR/simplicite-oracle.log owner=$DB_USER
	exit $?
elif [ $DB_VENDOR = "mssql" ]
then
	[ "$DB_PORT" = "" ] && DB_PORT=1433
	echo "SQLServer database: $DB_HOST / $DB_PORT / $DB_NAME / $DB_USER"
	sqlcmd -S $DB_HOST,$DB_PORT -U $DB_USER -P $DB_PASSWORD -b -Q "backup database $DB_NAME to disk='$DB_DIR/simplicite-mssql.dmp' with no_log"
	exit $?
else
	echo "Unknown database vendor: $DB_VENDOR" >&2
	exit 3
fi
