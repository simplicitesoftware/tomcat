#!/bin/bash

[ "$JAVA_HOME" = "" ] && JAVA_HOME="/usr/lib/jvm/java"
if [ ! -d $JAVA_HOME ]
then
	echo "ERROR: JAVA_HOME = $JAVA_HOME is not correctly configured" >&2
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

if [ ${TOMCAT_CLEAN_WORK_DIRS:-true} = "true" ]
then
	echo -n "Cleaning work files/dirs... "
	[ -d $TOMCAT_ROOT/conf/Catalina ] && rm -fr $TOMCAT_ROOT/conf/Catalina/*
	rm -fr $TOMCAT_ROOT/work/*
	rm -fr $TOMCAT_ROOT/temp/*
	if [ -d $TOMCAT_ROOT/webapps/$TOMCAT_WEBAPP ]
	then
		find $TOMCAT_ROOT/webapps/$TOMCAT_WEBAPP/WEB-INF -name \*.ser -exec rm -f {} \;
		for DIR in src bin build jar maven cache recyclebin tmp
		do
			[ -d $TOMCAT_ROOT/webapps/$TOMCAT_WEBAPP/WEB-INF/$DIR ] && rm -fr $TOMCAT_ROOT/webapps/$TOMCAT_WEBAPP/WEB-INF/$DIR/*
		done
		# Older versions' dirs (just in case...)
		for DIR in cache recyclebin tmp
		do
			[ -d $TOMCAT_ROOT/webapps/$TOMCAT_WEBAPP/WEB-INF/dbdoc/$DIR ] && rm -fr $TOMCAT_ROOT/webapps/$TOMCAT_WEBAPP/WEB-INF/dbdoc/$DIR
		done
	fi
	echo "Done"
fi

if [ ${TOMCAT_CLEAN_LOG_DIRS:-false} = "true" ]
then
	echo -n "Cleaning log dirs... "
	rm -fr $TOMCAT_ROOT/logs/*
	[ -d $TOMCAT_ROOT/webapps/$TOMCAT_WEBAPP/WEB-INF/log ] && rm -fr $TOMCAT_ROOT/webapps/$TOMCAT_WEBAPP/WEB-INF/log/*
	echo "Done"
fi

export JAVA_OPTS="$JAVA_OPTS -server -Djava.awt.headless=true -Dfile.encoding=UTF-8 -Duser.timezone=${TOMCAT_TIMEZONE:-`date +%Z`} -Dplatform.autoupgrade=true -Dtomcat.webapp=$TOMCAT_WEBAPP"
export JAVA_OPTS="$JAVA_OPTS -Dtomcat.adminport=${TOMCAT_ADMIN_PORT:-8005} -Dtomcat.httpport=${TOMCAT_HTTP_PORT:-8080} -Dtomcat.httpsport=${TOMCAT_HTTPS_PORT:-8443} -Dtomcat.httpredirectport=${TOMCAT_HTTPREDIRECTPORT:-443} -Dtomcat.ajpredirectport=${TOMCAT_AJPREDIRECTPORT:-443}"
export JAVA_OPTS="$JAVA_OPTS -Dtomcat.maxhttpheadersize=${TOMCAT_MAXHTTPHEADERSIZE:-8192} -Dtomcat.maxthreads=${TOMCAT_MAXTHREADS:-200} -Dtomcat.maxconnections=${TOMCAT_MAXCONNECTIONS:-8192}"
[ "$GZIP" = "true" -o "$TOMCAT_COMPRESSION" = "on" ] && export JAVA_OPTS="$JAVA_OPTS -Dtomcat.compression=on"
if [ "$SSL" = "true" -o ${TOMCAT_SSL_PORT:-0} -gt 0 ]
then
	export JAVA_OPTS="$JAVA_OPTS -Dtomcat.sslport=${TOMCAT_SSL_PORT:-8444} -Dtomcat.sslkeystorefile=${KEYSTORE_FILE:-$TOMCAT_ROOT/conf/server.jks} -Dtomcat.sslkeystorepassword=${KEYSTORE_PASSWORD:-password}"
	grep -q '<!-- SSL Connector' $TOMCAT_ROOT/conf/server.xml
	if [ $? = 0 -a -w $TOMCAT_ROOT/conf/server.xml ]
	then
		sed -i 's/<!-- SSL Connector/<Connector/;s/Connector SSL -->/Connector>/' $TOMCAT_ROOT/conf/server.xml
	else
		echo "WARNING: $TOMCAT_ROOT/conf/server.xml is not writeable, unable to enable SSL connector"
	fi
fi
if [ "$AJP" = "true" -o ${TOMCAT_AJP_PORT:-0} -gt 0 ]
then
	export JAVA_OPTS="$JAVA_OPTS -Dtomcat.ajpport=${TOMCAT_AJP_PORT:-8009} -Dtomcat.ajpaddress=${TOMCAT_AJP_ADDRESS:-0.0.0.0} -Dtomcat.ajpprotocol=${TOMCAT_AJP_PROTOCOL:-AJP/1.3} -Dtomcat.ajpsecretrequired=${TOMCAT_AJP_SECRET_REQUIRED:-false} -Dtomcat.ajpsecret=${TOMCAT_AJP_SECRET:-simplicite}"
	grep -q '<!-- AJP Connector' $TOMCAT_ROOT/conf/server.xml
	if [ $? = 0 -a -w $TOMCAT_ROOT/conf/server.xml ]
	then
		sed -i 's/<!-- AJP Connector/<Connector/;s/Connector AJP -->/Connector>/' $TOMCAT_ROOT/conf/server.xml
	else
		echo "WARNING: $TOMCAT_ROOT/conf/server.xml is not writeable, unable to enable SSL connector"
	fi
fi
export JAVA_OPTS="$JAVA_OPTS -Dgit.basedir=${GIT_BASEDIR:-$TOMCAT_ROOT/webapps/$TOMCAT_WEBAPP/WEB-INF/git}"
[ "$JMX" = "true" -o ${TOMCAT_JMX_PORT:-0} -gt 0 ] && export JAVA_OPTS="$JAVA_OPTS -Dcom.sun.management.jmxremote -Dcom.sun.management.jmxremote.port=${TOMCAT_JMX_PORT:-8555} -Dcom.sun.management.jmxremote.local.only=false -Dcom.sun.management.jmxremote.ssl=false -Dcom.sun.management.jmxremote.authenticate=false"
[ "$DEBUG" = "true" ] && export JAVA_OPTS="$JAVA_OPTS -Dplatform.debug=true"
[ "$JPDA" = "true" -o ${TOMCAT_JPDA_PORT:-0} -gt 0 ] && export JPDA_ADDRESS=${TOMCAT_JPDA_HOST:-0.0.0.0}:${TOMCAT_JPDA_PORT:-8000}
[ "$TOMCAT_LOG_ARGS" = "true" -o "$TOMCAT_LOG_ARGS" = "false" ] && export JAVA_OPTS="$JAVA_OPTS -Dtomcat.logargs=$TOMCAT_LOG_ARGS"
[ "$TOMCAT_LOG_ENV" = "true" -o "$TOMCAT_LOG_ENV" = "false" ] && export JAVA_OPTS="$JAVA_OPTS -Dtomcat.logenv=$TOMCAT_LOG_ENV"
[ "$TOMCAT_LOG_PROPS" = "true" -o "$TOMCAT_LOG_PROPS" = "false" ] && export JAVA_OPTS="$JAVA_OPTS -Dtomcat.logprops=$TOMCAT_LOG_PROPS"

if [ -d $TOMCAT_ROOT/webapps/$TOMCAT_WEBAPP ]
then
	[ "$DB_VENDOR" = "" ] && DB_VENDOR=hsqldb
	[ "$DB_VENDOR" = "mariadb" ] && DB_VENDOR=mysql
	[ "$DB_VENDOR" = "pgsql" -o "$DB_VENDOR" = "postgres" ] && DB_VENDOR=postgresql
	[ "$DB_VENDOR" = "sqlserver" ] && DB_VENDOR=mssql
	echo "Database vendor: $DB_VENDOR"
	# Check if generic database configuration is enabled (e.g. in Doker images)
	grep -q '<!-- database --><Resource' $TOMCAT_ROOT/webapps/$TOMCAT_WEBAPP/META-INF/context.xml
	GENERIC_DB=$?
	if [ $DB_VENDOR = "hsqldb" -a $GENERIC_DB = 0 ]
	then
		JAVA_OPTS="$JAVA_OPTS -Ddb.vendor='$DB_VENDOR' -Ddb.user='sa' -Ddb.password='' -Ddb.driver='org.hsqldb.jdbcDriver' -Ddb.url='hsqldb:file:$TOMCAT_ROOT/webapps/$TOMCAT_WEBAPP/WEB-INF/db/simplicite;shutdown=true;sql.ignore_case=true'"
	elif [ $DB_VENDOR = "mysql" ]
	then
		[ "$DB_HOST" = "" ] && DB_HOST=127.0.0.1
		[ "$DB_PORT" = "" ] && DB_PORT=3306
		[ "$DB_SSL" = "" ] && DB_SSL=false
		if [ "$DB_NAME" = "" -o "$DB_USER" = "" -o "$DB_PASSWORD" = "" ]
		then
			echo "ERROR: Missing database name, user and/or password" >&2
			exit 2	
		fi
		echo "MySQL database: $DB_HOST / $DB_PORT / $DB_NAME / $DB_USER"
		if [ $GENERIC_DB = 0 ]
		then
			JAVA_OPTS="$JAVA_OPTS -Ddb.vendor='$DB_VENDOR' -Ddb.user='$DB_USER' -Ddb.password='$DB_PASSWORD' -Ddb.driver='com.mysql.cj.jdbc.Driver' -Ddb.url='mysql://$DB_HOST:$DB_PORT/$DB_NAME?autoReconnect=true&useSSL=$DB_SSL&allowPublicKeyRetrieval=true&characterEncoding=utf8&characterResultSets=utf8&serverTimezone=${TOMCAT_TIMEZONE:-`date +%Z`}'"
		else
			JAVA_OPTS="$JAVA_OPTS -Dmysql.user=$DB_USER -Dmysql.password=$DB_PASSWORD -Dmysql.host=$DB_HOST -Dmysql.port=$DB_PORT -Dmysql.database=$DB_NAME -Dmysql.ssl=$DB_SSL"
			if [ -w $TOMCAT_ROOT/webapps/$TOMCAT_WEBAPP/META-INF/context.xml ]
			then
				sed -i 's/<!-- hsqldb --><Resource/<!-- hsqldb --><!-- Resource/;s/<\/Resource><!-- hsqldb -->/<\/Resource --><!-- hsqldb -->/;s/<!-- mysql --><!-- Resource/<!-- mysql --><Resource/;s/<\/Resource --><!-- mysql -->/<\/Resource><!-- mysql -->/' $TOMCAT_ROOT/webapps/$TOMCAT_WEBAPP/META-INF/context.xml
			else
				echo "ERROR: $TOMCAT_ROOT/webapps/$TOMCAT_WEBAPP/META-INF/context.xml is not writeable, unable to setup mysql connection"
				exit 3
			fi
		fi
		W=${DB_WAIT:-1}
		N=0
		while [ $N -lt $W ]
		do
			N=`expr $N + 1`
			echo "exit" | mysql --silent --host=$DB_HOST --port=$DB_PORT --user=$DB_USER --password=$DB_PASSWORD --database=$DB_NAME
			RET=$?
			if [ $RET -ne 0 ]
			then
				if [ $W -eq 1 -o $N -eq $W ]
				then
					echo "ERROR: Unable to connect to database" >&2
					exit 4
				else
					echo "Waiting 5s for database ($N)"
					sleep 5
				fi
			fi
		done
		EXISTS=`echo "show tables like 'm_system'" | mysql --silent --host=$DB_HOST --port=$DB_PORT --user=$DB_USER --password=$DB_PASSWORD --database=$DB_NAME`
		if [ "$EXISTS" = "" ]
		then
			if [ "$DB_SETUP" = "true" -o "$DB_SETUP" = "yes" ]
			then
				if [ -f $TOMCAT_ROOT/webapps/$TOMCAT_WEBAPP/WEB-INF/db/simplicite-mysql.dmp ]
				then
					echo "Loading database..."
					mysql --silent --host=$DB_HOST --port=$DB_PORT --user=$DB_USER --password=$DB_PASSWORD $DB_NAME < $TOMCAT_ROOT/webapps/$TOMCAT_WEBAPP/WEB-INF/db/simplicite-mysql.dmp
					RET=$?
					if [ $RET -ne 0 ]
					then
						echo "ERROR: Load database error" >&2
						exit 7
					fi
					echo "Done"
				else
					echo "ERROR: No dump to load database" >&2
					exit 6
				fi
			else
				echo "ERROR: Database is not setup" >&2
				exit 5
			fi
		fi
	elif [ $DB_VENDOR = "postgresql" ]
	then
		[ "$DB_HOST" = "" ] && DB_HOST=127.0.0.1
		[ "$DB_PORT" = "" ] && DB_PORT=5432
		[ "$DB_SSL" = "" ] && DB_SSL=false
		if [ "$DB_NAME" = "" -o "$DB_USER" = "" -o "$DB_PASSWORD" = "" ]
		then
			echo "ERROR: Missing database name, user and/or password" >&2
			exit 2	
		fi
		echo "PostgreSQL database: $DB_HOST / $DB_PORT / $DB_NAME / $DB_USER"
		if [ $GENERIC_DB = 0 ]
		then
			JAVA_OPTS="$JAVA_OPTS -Ddb.vendor='$DB_VENDOR' -Ddb.user='$DB_USER' -Ddb.password='$DB_PASSWORD' -Ddb.driver='org.postgresql.Driver' -Ddb.url='postgresql://$DB_HOST:$DB_PORT/$DB_NAME?ssl=$DB_SSL'"
		else
			JAVA_OPTS="$JAVA_OPTS -Dpostgresql.user=$DB_USER -Dpostgresql.password=$DB_PASSWORD -Dpostgresql.host=$DB_HOST -Dpostgresql.port=$DB_PORT -Dpostgresql.database=$DB_NAME -Dpostgresql.ssl=$DB_SSL"
			if [ -w $TOMCAT_ROOT/webapps/$TOMCAT_WEBAPP/META-INF/context.xml ]
			then
				sed -i 's/<!-- hsqldb --><Resource/<!-- hsqldb --><!-- Resource/;s/<\/Resource><!-- hsqldb -->/<\/Resource --><!-- hsqldb -->/;s/<!-- postgresql --><!-- Resource/<!-- postgresql --><Resource/;s/<\/Resource --><!-- postgresql -->/<\/Resource><!-- postgresql -->/' $TOMCAT_ROOT/webapps/$TOMCAT_WEBAPP/META-INF/context.xml
			else
				echo "ERROR: $TOMCAT_ROOT/webapps/$TOMCAT_WEBAPP/META-INF/context.xml is not writeable, unable to setup postgresql connection"
				exit 3
			fi
		fi
		W=${DB_WAIT:-1}
		N=0
		while [ $N -lt $W ]
		do
			N=`expr $N + 1`
			echo "\q" | PGPASSWORD=$DB_PASSWORD psql --quiet -h $DB_HOST -p $DB_PORT -U $DB_USER $DB_NAME
			RET=$?
			if [ $RET -ne 0 ]
			then
				if [ $W -eq 1 -o $N -eq $W ]
				then
					echo "ERROR: Unable to connect to database" >&2
					exit 4
				else
					echo "Waiting 5s for database ($N)"
					sleep 5
				fi
			fi
		done
		EXISTS=`echo "select tablename from pg_catalog.pg_tables where tablename = 'm_system'" | PGPASSWORD=$DB_PASSWORD psql -t -h $DB_HOST -p $DB_PORT -U $DB_USER $DB_NAME`
		if [ "$EXISTS" = "" ]
		then
			if [ "$DB_SETUP" = "true" -o "$DB_SETUP" = "yes" ]
			then
				if [ -f $TOMCAT_ROOT/webapps/$TOMCAT_WEBAPP/WEB-INF/db/simplicite-postgresql.dmp ]
				then
					echo "Loading database..."
					PGPASSWORD=$DB_PASSWORD psql --quiet -t -h $DB_HOST -p $DB_PORT -U $DB_USER $DB_NAME < $TOMCAT_ROOT/webapps/$TOMCAT_WEBAPP/WEB-INF/db/simplicite-postgresql.dmp
					RET=$?
					if [ $RET -ne 0 ]
					then
						echo "ERROR: Load database error" >&2
						exit 7
					fi
					echo "Done"
				else
					echo "ERROR: No dump to load database" >&2
					exit 6
				fi
			else
				echo "ERROR: Database is not setup" >&2
				exit 5
			fi
		fi
	elif [ $DB_VENDOR = "oracle" ]
	then
		[ "$DB_HOST" = "" ] && DB_PORT=127.0.0.1
		[ "$DB_PORT" = "" ] && DB_PORT=1521
		if [ "$DB_NAME" = "" -o "$DB_USER" = "" -o "$DB_PASSWORD" = "" ]
		then
			echo "ERROR: Missing database name, user and/or password" >&2
			exit 2	
		fi
		echo "Oracle database: $DB_HOST / $DB_PORT / $DB_NAME / $DB_USER"
		if [ $GENERIC_DB = 0 ]
		then
			JAVA_OPTS="$JAVA_OPTS -Ddb.vendor='$DB_VENDOR' -Ddb.user='$DB_USER' -Ddb.password='$DB_PASSWORD' -Ddb.driver='oracle.jdbc.driver.OracleDriver' -Ddb.url='oracle:thin:@$DB_HOST:$DB_PORT:$DB_NAME'"
		else
			JAVA_OPTS="$JAVA_OPTS -Doracle.user=$DB_USER -Doracle.password=$DB_PASSWORD -Doracle.host=$DB_HOST -Doracle.port=$DB_PORT -Doracle.database=$DB_NAME"
			if [ -w $TOMCAT_ROOT/webapps/$TOMCAT_WEBAPP/META-INF/context.xml ]
			then
				sed -i 's/<!-- hsqldb --><Resource/<!-- hsqldb --><!-- Resource/;s/<\/Resource><!-- hsqldb -->/<\/Resource --><!-- hsqldb -->/;s/<!-- oracle --><!-- Resource/<!-- oracle --><Resource/;s/<\/Resource --><!-- oracle -->/<\/Resource><!-- oracle -->/' $TOMCAT_ROOT/webapps/$TOMCAT_WEBAPP/META-INF/context.xml
			else
				echo "ERROR: $TOMCAT_ROOT/webapps/$TOMCAT_WEBAPP/META-INF/context.xml is not writeable, unable to setup oracle connection"
				exit 3
			fi
		fi
		W=${DB_WAIT:-1}
		N=0
		while [ $N -lt $W ]
		do
			N=`expr $N + 1`
			sqlplus $DB_USER/$DB_PASSWORD@//$DB_HOST:$DB_PORT << EOF
whenever sqlerror exit 1;
select 1 from dual;
EOF
			RET=$?
			if [ $RET -ne 0 ]
			then
				if [ $W -eq 1 -o $N -eq $W ]
				then
					echo "ERROR: Unable to connect to database" >&2
					exit 4
				else
					echo "Waiting 5s for database ($N)"
					sleep 5
				fi
			fi
		done
		sqlplus $DB_USER/$DB_PASSWORD@//$DB_HOST:$DB_PORT << EOF
whenever sqlerror exit 1;
select 1 from m_system;
EOF
		RET=$?
		if [ $RET -ne 0 ]
		then
			if [ "$DB_SETUP" = "true" -o "$DB_SETUP" = "yes" ]
			then
				if [ -f $TOMCAT_ROOT/webapps/$TOMCAT_WEBAPP/WEB-INF/db/simplicite-oracle.sql ]
				then
					echo "Loading database..."
					sqlplus $DB_USER/$DB_PASSWORD@//$DB_HOST:$DB_PORT < $TOMCAT_ROOT/webapps/$TOMCAT_WEBAPP/WEB-INF/db/simplicite-oracle.sql
					RET=$?
					if [ $RET -ne 0 ]
					then
						echo "ERROR: Load database error" >&2
						exit 7
					fi
					echo "Done"
				else
					echo "ERROR: No script to load database" >&2
					exit 6
				fi
			else
				echo "ERROR: Database is not setup" >&2
				exit 5
			fi
		fi
	elif [ $DB_VENDOR = "mssql" ]
	then
		[ "$DB_HOST" = "" ] && DB_PORT=127.0.0.1
		[ "$DB_PORT" = "" ] && DB_PORT=1433
		if [ "$DB_NAME" = "" -o "$DB_USER" = "" -o "$DB_PASSWORD" = "" ]
		then
			echo "ERROR: Missing database name, user and/or password" >&2
			exit 2	
		fi
		echo "SQLServer database: $DB_HOST / $DB_PORT / $DB_NAME / $DB_USER"
		if [ $GENERIC_DB = 0 ]
		then
			JAVA_OPTS="$JAVA_OPTS -Ddb.vendor='$DB_VENDOR' -Ddb.user='$DB_USER' -Ddb.password='$DB_PASSWORD' -Ddb.driver='com.microsoft.sqlserver.jdbc.SQLServerDriver' -Ddb.url='sqlserver://$DB_HOST:$DB_PORT;databaseName=$DB_NAME'"
		else
			JAVA_OPTS="$JAVA_OPTS -Dmssql.user=$DB_USER -Dmssql.password=$DB_PASSWORD -Dmssql.host=$DB_HOST -Dmssql.port=$DB_PORT -Dmssql.database=$DB_NAME"
			if [ -w $TOMCAT_ROOT/webapps/$TOMCAT_WEBAPP/META-INF/context.xml ]
			then
				sed -i 's/<!-- hsqldb --><Resource/<!-- hsqldb --><!-- Resource/;s/<\/Resource><!-- hsqldb -->/<\/Resource --><!-- hsqldb -->/;s/<!-- mssql --><!-- Resource/<!-- mssql --><Resource/;s/<\/Resource --><!-- mssql -->/<\/Resource><!-- mssql -->/' $TOMCAT_ROOT/webapps/$TOMCAT_WEBAPP/META-INF/context.xml
			else
				echo "ERROR: $TOMCAT_ROOT/webapps/$TOMCAT_WEBAPP/META-INF/context.xml is not writeable, unable to setup mssql connection"
				exit 3
			fi
		fi
		W=${DB_WAIT:-1}
		N=0
		while [ $N -lt $W ]
		do
			N=`expr $N + 1`
			sqlcmd -S $DB_HOST,$DB_PORT -U $DB_USER -P $DB_PASSWORD -b -Q "select 1"
			RET=$?
			if [ $RET -ne 0 ]
			then
				if [ $W -eq 1 -o $N -eq $W ]
				then
					echo "ERROR: Unable to connect to database" >&2
					exit 4
				else
					echo "Waiting 5s for database ($N)"
					sleep 5
				fi
			fi
		done
		sqlcmd -S $DB_HOST,$DB_PORT -U $DB_USER -P $DB_PASSWORD -d $DB_NAME -b -Q "select 1 from m_system"
		RET=$?
		if [ $RET -ne 0 ]
		then
			if [ "$DB_SETUP" = "true" -o "$DB_SETUP" = "yes" ]
			then
				if [ -f $TOMCAT_ROOT/webapps/$TOMCAT_WEBAPP/WEB-INF/db/simplicite-mssql.sql ]
				then
					echo "Loading database..."
					sqlcmd -S $DB_HOST,$DB_PORT -U $DB_USER -P $DB_PASSWORD -d $DB_NAME -i $TOMCAT_ROOT/webapps/$TOMCAT_WEBAPP/WEB-INF/db/simplicite-mssql.sql
					RET=$?
					if [ $RET -ne 0 ]
					then
						echo "ERROR: Load database error" >&2
						exit 7
					fi
					echo "Done"
				else
					echo "ERROR: No script to load database" >&2
					exit 6
				fi
			else
				echo "ERROR: Database is not setup" >&2
				exit 5
			fi
		fi
	fi
elif [ -w $TOMCAT_ROOT/webapps ]
then
	echo -n "Generating default webapp... "
	mkdir $TOMCAT_ROOT/webapps/$TOMCAT_WEBAPP
	mkdir $TOMCAT_ROOT/webapps/$TOMCAT_WEBAPP/WEB-INF
	mkdir $TOMCAT_ROOT/webapps/$TOMCAT_WEBAPP/META-INF
	cat > $TOMCAT_ROOT/webapps/$TOMCAT_WEBAPP/WEB-INF/web.xml << EOF
<?xml version="1.0" encoding="UTF-8"?>
<web-app
	xmlns="http://xmlns.jcp.org/xml/ns/javaee"
	xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
	xsi:schemaLocation="http://xmlns.jcp.org/xml/ns/javaee http://xmlns.jcp.org/xml/ns/javaee/web-app_4_0.xsd"
	version="4.0">
	<welcome-file-list>
		<welcome-file>index.jsp</welcome-file>
	</welcome-file-list>
</web-app>
EOF
	cat > $TOMCAT_ROOT/webapps/$TOMCAT_WEBAPP/META-INF/context.xml << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE Context>
<Context>
	<Manager pathname=""/>
	<JarScanner scanClassPath="false"/>
</Context>
EOF
	cp -f $TOMCAT_ROOT/favicon.ico $TOMCAT_ROOT/webapps/$TOMCAT_WEBAPP
	cat > $TOMCAT_ROOT/webapps/$TOMCAT_WEBAPP/index.jsp << EOF
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8"/>
<title>It works!</title>
</head>
<body>
<pre>
OS: <%= System.getProperty("os.name") + " " + System.getProperty("os.arch") + " " + System.getProperty("os.version") %>
JVM: <%= System.getProperty("java.version") + " " + System.getProperty("java.vendor") + " " + System.getProperty("java.vm.name") + " " + System.getProperty("java.vm.version") %>
Encoding: <%= System.getProperty("file.encoding") %>
Server: <%= request.getServletContext().getServerInfo() %>
System date: <%= new java.util.Date() %>
Environment variables:
<%
java.util.Map<String, String> env = System.getenv();
for (String name : env.keySet())
	out.println("\t" + name + " = " + env.get(name));
%>System properties:
<%
java.util.Properties p = System.getProperties();
java.util.Enumeration keys = p.keys();
while (keys.hasMoreElements()) {
	Object key = keys.nextElement();
	out.println("\t" + key + " = " + p.get(key));
}
%></pre>
</body>
</html>
EOF
	cat > $TOMCAT_ROOT/webapps/$TOMCAT_WEBAPP/api.jsp << EOF
<%@ page language="java" contentType="application/json; charset=UTF-8" pageEncoding="UTF-8"%>{
	"os": "<%= System.getProperty("os.name") + " " + System.getProperty("os.arch") + " " + System.getProperty("os.version") %>",
	"jvm": "<%= System.getProperty("java.version") + " " + System.getProperty("java.vendor") + " " + System.getProperty("java.vm.name") + " " + System.getProperty("java.vm.version") %>",
	"encoding": "<%= System.getProperty("file.encoding") %>",
	"server": "<%= request.getServletContext().getServerInfo() %>",
	"systemdate": "<%= new java.util.Date() %>"
}
EOF
	echo "Done"
fi

if [ "$CORS" = "true" ]
then
	if [ -w $TOMCAT_ROOT/webapps/$TOMCAT_WEBAPP/WEB-INF/web.xml ]
	then
		sed -i 's/<!-- cors --><!-- /<!-- cors --></;s/ --><!-- cors -->/><!-- cors -->/' $TOMCAT_ROOT/webapps/$TOMCAT_WEBAPP/WEB-INF/web.xml
		sed -i "s~@cors.origins@~${CORS_ORIGINS:-\*}~;s~@cors.credentials@~${CORS_CREDENTIALS:-false}~;s~@cors.maxage@~${CORS_MAXAGE:-1728000}~" $TOMCAT_ROOT/webapps/$TOMCAT_WEBAPP/WEB-INF/web.xml
	else
		echo "WARNING: $TOMCAT_ROOT/webapps/$TOMCAT_WEBAPP/WEB-INF/web.xml is not writeable, unable to set CORS options"
	fi
fi

if [ "$API_EXTRA_PATTERNS" != "" ]
then
	if [ -w $TOMCAT_ROOT/webapps/$TOMCAT_WEBAPP/META-INF/context.xml ]
	then
		sed -i "/APISessionValve/s/ extraPatterns=\".*\"//g;/APISessionValve/s/\/>/ extraPatterns=\"$API_EXTRA_PATTERNS\"\/>/" $TOMCAT_ROOT/webapps/$TOMCAT_WEBAPP/META-INF/context.xml
	else
		echo "WARNING: $TOMCAT_ROOT/webapps/$TOMCAT_WEBAPP/META-INF/context.xml is not writeable, unable to set API extra patterns"
	fi
fi

if [ "$JPDA" = "true" ]
then
	if [ -w $TOMCAT_ROOT/bin/startup.sh ]
	then
		[ "$JPDA_SUSPEND" = "true" ] && export JPDA_SUSPEND=y
		[ "$JPDA_SUSPEND" = "false" ] && export JPDA_SUSPEND=n
		sed -i '/^exec /s/" start /" jpda start /' $TOMCAT_ROOT/bin/startup.sh
	else
		echo "WARNING: $TOMCAT_ROOT/bin/startup.sh is not writeable, unable to set debug mode"
	fi
else
	[ -w $TOMCAT_ROOT/bin/startup.sh ] && sed -i '/^exec /s/" jpda start /" start /' $TOMCAT_ROOT/bin/startup.sh
fi

cd $TOMCAT_ROOT/bin
./startup.sh
cd ..

if [ "$1" = "-t"  -o "$1" = "--tail" ]
then
	LOG=logs/catalina.out
	while [ ! -f $LOG ]; do echo -n "."; sleep 1; done
	tail -f $LOG
fi

exit 0
