#!/bin/bash

if [ "$JAVA_HOME" = "" ]
then
	echo "JAVA_HOME is not set" >&2
	exit 1
fi
export PATH=$JAVA_HOME/bin:$PATH

[ "$TOMCAT_ROOT" = "" ] && TOMCAT_ROOT=$(dirname $0)
TOMCAT_ROOT=$(realpath $TOMCAT_ROOT)
echo "Tomcat root: $TOMCAT_ROOT"

export JAVA_OPTS="$JAVA_OPTS -Dfile.encoding=UTF-8"

[ "$DB_VENDOR" = "" ] && DB_VENDOR=hsqldb
[ "$DB_VENDOR" = "mariadb" ] && DB_VENDOR=mysql
[ "$DB_VENDOR" = "pgsql" -o "$DB_VENDOR" = "postgres" ] && DB_VENDOR=postgresql
[ "$DB_VENDOR" = "sqlserver" ] && DB_VENDOR=mssql
echo "Database vendor: $DB_VENDOR"

if [ $DB_VENDOR = "hsqldb" ]
then
	WEBINF_DIR=$TOMCAT_ROOT/webapps/${TOMCAT_WEBAPP:-ROOT}/WEB-INF
	if [ -d $WEBINF_DIR/db ]
	then
		echo "HSQLDB database: Embedded"
		DRIVER=$(find $WEBINF_DIR -name hsqldb-\*.jar -print)
		SQLTOOL=$(find $WEBINF_DIR -name sqltool-\*.jar -print)
		java $JAVA_OPTS -cp $DRIVER:$SQLTOOL org.hsqldb.cmdline.SqlTool --inlineRc="url=jdbc:hsqldb:file:$TOMCAT_ROOT/webapps/${TOMCAT_WEBAPP:-ROOT}/WEB-INF/db/simplicite;shutdown=true;sql.ignore_case=true,user=sa,password="
		exit $?
	else
		echo "No database directory: $WEBINF_DIR/db" >&2
		exit 3
	fi
elif [ $DB_VENDOR = "mysql" ]
then
	[ "$DB_HOST" = "" ] && DB_HOST=127.0.0.1
	[ "$DB_PORT" = "" ] && DB_PORT=3306
	echo "MySQL database: $DB_HOST / $DB_PORT / $DB_NAME / $DB_USER"
	mysql --host=$DB_HOST --port=$DB_PORT --user=$DB_USER --password=$DB_PASSWORD --database=$DB_NAME
	exit $?
elif [ $DB_VENDOR = "postgresql" ]
then
	[ "$DB_HOST" = "" ] && DB_HOST=127.0.0.1
	[ "$DB_PORT" = "" ] && DB_PORT=5432
	echo "PostgreSQL database: $DB_HOST / $DB_PORT / $DB_NAME / $DB_USER"
	PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER $DB_NAME
	exit $?
elif [ $DB_VENDOR = "oracle" ]
then
	[ "$DB_HOST" = "" ] && DB_HOST=127.0.0.1
	[ "$DB_PORT" = "" ] && DB_PORT=1521
	echo "Oracle database: $DB_HOST / $DB_PORT / $DB_NAME / $DB_USER"
	sqlplus $DB_USER/$DB_PASSWORD@//$DB_HOST:$DB_PORT/$DB_NAME
	exit $?
elif [ $DB_VENDOR = "sqlserver" ]
then
	[ "$DB_HOST" = "" ] && DB_HOST=127.0.0.1
	[ "$DB_PORT" = "" ] && DB_PORT=1433
	echo "SQLServer database: $DB_HOST / $DB_PORT / $DB_NAME / $DB_USER"
	sqlcmd -S $DB_HOST,$DB_PORT -U $DB_USER -P $DB_PASSWORD
	exit $?
else
	echo "Unknown vendor: $DB_VENDOR" >&2
	exit 3
fi
