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

[ "$TOMCAT_WEBAPP" = "" ] && TOMCAT_WEBAPP=ROOT
echo "Tomcat webapp: $TOMCAT_WEBAPP"

[ ! -d $TOMCAT_ROOT/work ] && mkdir $TOMCAT_ROOT/work
[ ! -d $TOMCAT_ROOT/temp ] && mkdir $TOMCAT_ROOT/temp
[ ! -d $TOMCAT_ROOT/logs ] && mkdir $TOMCAT_ROOT/logs
[ ! -d $TOMCAT_ROOT/webapps ] && mkdir $TOMCAT_ROOT/webapps

export JAVA_OPTS="$JAVA_OPTS -server -Dfile.encoding=UTF-8"

if [ -d $TOMCAT_ROOT/webapps/$TOMCAT_WEBAPP ]
then
	[ "$DB_VENDOR" = "" ] && DB_VENDOR=hsqldb
	[ "$DB_VENDOR" = "mariadb" ] && DB_VENDOR=mysql
	[ "$DB_VENDOR" = "pgsql" ] && DB_VENDOR=postgresql
	echo "Database vendor: $DB_VENDOR"
	if [ $DB_VENDOR = "mysql" ]
	then
		[ "$DB_PORT" = "" ] && DB_PORT=3306
		echo "MySQL database: $DB_HOST / $DB_PORT / $DB_NAME / $DB_USER"
		echo "exit" | mysql --silent --host=$DB_HOST --port=$DB_PORT --user=$DB_USER --password=$DB_PASSWORD --database=$DB_NAME
		RET=$?
		if [ $RET -ne 0 ]
		then
			echo "Unable to connect to database" >&2
			exit 2
		fi
		mysqldump --host=$DB_HOST --port=$DB_PORT --user=$DB_USER --password=$DB_PASSWORD $DB_NAME > $TOMCAT_ROOT/webapps/$TOMCAT_WEBAPP/WEB-INF/db/simplicite-mysql.dmp
	elif [ $DB_VENDOR = "postgresql" ]
	then
		[ "$DB_PORT" = "" ] && DB_PORT=5432
		echo "PostgreSQL database: $DB_HOST / $DB_PORT / $DB_NAME / $DB_USER"
		echo "\q" | PGPASSWORD=$DB_PASSWORD psql --quiet -h $DB_HOST -p $DB_PORT -U $DB_USER $DB_NAME
		RET=$?
		if [ $RET -ne 0 ]
		then
			echo "Unable to connect to database" >&2
			exit 2
		fi
		PGPASSWORD=$DB_PASSWORD pg_dump -h $DB_HOST -p $DB_PORT -U $DB_USER $DB_NAME --no-owner --clean > $TOMCAT_ROOT/webapps/$TOMCAT_WEBAPP/WEB-INF/db/simplicite-postgresql.dmp
	elif [ $DB_VENDOR = "oracle" ]
	then
		[ "$DB_PORT" = "" ] && DB_PORT=1521
		echo "Oracle database: $DB_HOST / $DB_PORT / $DB_NAME / $DB_USER"
		echo "Not available" >&2
		exit 2
	elif [ $DB_VENDOR = "sqlserver" ]
	then
		[ "$DB_PORT" = "" ] && DB_PORT=1433
		echo "SQLServer database: $DB_HOST / $DB_PORT / $DB_NAME / $DB_USER"
		echo "Not available" >&2
		exit 2
	fi
fi

exit 0