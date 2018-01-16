#!/bin/bash

if [ "$JAVA_HOME" = "" ]
then
	echo "JAVA_HOME is not set" >&2
	exit 1
fi
export PATH=$JAVA_HOME/bin:$PATH

[ "$TOMCAT_ROOT" = "" ] && TOMCAT_ROOT=`dirname $0`
echo "Tomcat root: $TOMCAT_ROOT"

[ ! -d $TOMCAT_ROOT/work ] && mkdir $TOMCAT_ROOT/work
[ ! -d $TOMCAT_ROOT/temp ] && mkdir $TOMCAT_ROOT/temp
[ ! -d $TOMCAT_ROOT/logs ] && mkdir $TOMCAT_ROOT/logs
[ ! -d $TOMCAT_ROOT/webapps ] && mkdir $TOMCAT_ROOT/webapps

export JAVA_OPTS="$JAVA_OPTS -server -Dfile.encoding=UTF-8 -Dgit.basedir=$TOMCAT_ROOT/webapps/ROOT/WEB-INF/git -Dplatform.autoupgrade=true"
export JAVA_OPTS="$JAVA_OPTS -Dtomcat.adminport=${TOMCAT_ADMIN_PORT:-8005} -Dtomcat.httpport=${TOMCAT_HTTP_PORT:-8080} -Dtomcat.httpsport=${TOMCAT_HTTPS_PORT:-8443} -Dtomcat.ajpport=${TOMCAT_AJP_PORT:-8009}"

if [ -d $TOMCAT_ROOT/webapps/ROOT ]
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
		EXISTS=`echo "show tables like 'm_system'" | mysql --silent --host=$DB_HOST --port=$DB_PORT --user=$DB_USER --password=$DB_PASSWORD --database=$DB_NAME`
		if [ "$EXISTS" = "" ]
		then
			if [ "$DB_SETUP" = "true" ]
			then
				if [ -f $TOMCAT_ROOT/webapps/ROOT/WEB-INF/db/simplicite-mysql.dmp ]
				then
					echo "Loading database..."
					mysql --host=$DB_HOST --port=$DB_PORT --user=$DB_USER --password=$DB_PASSWORD $DB_NAME < $TOMCAT_ROOT/webapps/ROOT/WEB-INF/db/simplicite-mysql.dmp
					RET=$?
					if [ $RET -ne 0 ]
					then
						echo "Load database error" >&2
						exit 5
					fi
					echo "Done"
				else
					echo "No dump to load database" >&2
					exit 4
				fi
			else
				echo "Database is not setup" >&2
				exit 3
			fi
		fi
		sed -i 's/<!-- hsqldb --><Resource/<!-- hsqldb --><!-- Resource/;s/<\/Resource><!-- hsqldb -->/<\/Resource --><!-- hsqldb -->/;s/<!-- mysql --><!-- Resource/<!-- mysql --><Resource/;s/<\/Resource --><!-- mysql -->/<\/Resource><!-- mysql -->/' $TOMCAT_ROOT/webapps/ROOT/META-INF/context.xml
		JAVA_OPTS="$JAVA_OPTS -Dmysql.user=$DB_USER -Dmysql.password=$DB_PASSWORD -Dmysql.host=$DB_HOST -Dmysql.port=$DB_PORT -Dmysql.database=$DB_NAME"
	elif [ $DB_VENDOR = "postgresql" ]
	then
		[ "$DB_PORT" = "" ] && DB_PORT=5432
		echo "PostgreSQL database: $DB_HOST / $DB_PORT / $DB_NAME / $DB_USER"
		echo "\q" | PGPASSWORD=$DB_PASSWORD psql -q -h $DB_HOST -p $DB_PORT -U $DB_USER $DB_NAME
		RET=$?
		if [ $RET -ne 0 ]
		then
			echo "Unable to connect to database" >&2
			exit 2
		fi
		EXISTS=`echo "select tablename from pg_catalog.pg_tables where tablename = 'm_system'" | PGPASSWORD=$DB_PASSWORD psql -t -h $DB_HOST -p $DB_PORT -U $DB_USER $DB_NAME`
		if [ "$EXISTS" = "" ]
		then
			if [ "$DB_SETUP" = "true" ]
			then
				if [ -f $TOMCAT_ROOT/webapps/ROOT/WEB-INF/db/simplicite-postgresql.dmp ]
				then
					echo "Loading database..."
					PGPASSWORD=$DB_PASSWORD psql -t -h $DB_HOST -p $DB_PORT -U $DB_USER $DB_NAME < $TOMCAT_ROOT/webapps/ROOT/WEB-INF/db/simplicite-postgresql.dmp
					RET=$?
					if [ $RET -ne 0 ]
					then
						echo "Load database error" >&2
						exit 5
					fi
					echo "Done"
				else
					echo "No dump to load database" >&2
					exit 4
				fi
			else
				echo "Database is not setup" >&2
				exit 3
			fi
		fi
		sed -i 's/<!-- hsqldb --><Resource/<!-- hsqldb --><!-- Resource/;s/<\/Resource><!-- hsqldb -->/<\/Resource --><!-- hsqldb -->/;s/<!-- postgresql --><!-- Resource/<!-- postgresql --><Resource/;s/<\/Resource --><!-- postgresql -->/<\/Resource><!-- postgresql -->/' $TOMCAT_ROOT/webapps/ROOT/META-INF/context.xml
		JAVA_OPTS="$JAVA_OPTS -Dpostgresql.user=$DB_USER -Dpostgresql.password=$DB_PASSWORD -Dpostgresql.host=$DB_HOST -Dpostgresql.port=$DB_PORT -Dpostgresql.database=$DB_NAME"
	elif [ $DB_VENDOR = "oracle" ]
	then
		[ "$DB_PORT" = "" ] && DB_PORT=1521
		echo "Oracle database: $DB_HOST / $DB_PORT / $DB_NAME / $DB_USER"
		sed -i 's/<!-- hsqldb --><Resource/<!-- hsqldb --><!-- Resource/;s/<\/Resource><!-- hsqldb -->/<\/Resource --><!-- hsqldb -->/;s/<!-- oracle --><!-- Resource/<!-- oracle --><Resource/;s/<\/Resource --><!-- oracle -->/<\/Resource><!-- oracle -->/' $TOMCAT_ROOT/webapps/ROOT/META-INF/context.xml
		JAVA_OPTS="$JAVA_OPTS -Doracle.user=$DB_USER -Doracle.password=$DB_PASSWORD -Doracle.host=$DB_HOST -Doracle.port=$DB_PORT -Doracle.database=$DB_NAME"
	elif [ $DB_VENDOR = "sqlserver" ]
	then
		[ "$DB_PORT" = "" ] && DB_PORT=1433
		echo "SQLServer database: $DB_HOST / $DB_PORT / $DB_NAME / $DB_USER"
		sed -i 's/<!-- hsqldb --><Resource/<!-- hsqldb --><!-- Resource/;s/<\/Resource><!-- hsqldb -->/<\/Resource --><!-- hsqldb -->/;s/<!-- sqlserver --><!-- Resource/<!-- sqlserver --><Resource/;s/<\/Resource --><!-- sqlserver -->/<\/Resource><!-- sqlserver -->/' $TOMCAT_ROOT/webapps/ROOT/META-INF/context.xml
		JAVA_OPTS="$JAVA_OPTS -Dsqlserver.user=$DB_USER -Dsqlserver.password=$DB_PASSWORD -Dsqlserver.host=$DB_HOST -Dsqlserver.port=$DB_PORT -Dsqlserver.database=$DB_NAME"
	fi
else
	mkdir $TOMCAT_ROOT/webapps/ROOT
	cat > $TOMCAT_ROOT/webapps/ROOT/index.jsp << EOF
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
</pre>
</body>
</html>
EOF
fi

sed -i 's/<!-- appender-ref ref="SIMPLICITE-CONSOLE"\/ -->/<appender-ref ref="SIMPLICITE-CONSOLE"\/>/' $TOMCAT_ROOT/webapps/ROOT/WEB-INF/classes/log4j.xml

echo "Java options: $JAVA_OPTS"

cd $TOMCAT_ROOT/bin
./startup.sh
cd ..

if [ "$1" = "-t" ]
then
	LOG=logs/catalina.out
	while [ ! -f $LOG ]; do echo -n "."; sleep 1; done
	tail -f $LOG
fi

exit 0