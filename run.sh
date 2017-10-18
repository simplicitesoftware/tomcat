#!/bin/bash

export JAVA_HOME=/usr/lib/jvm/java-1.8.0
export PATH=$JAVA_HOME/bin:$PATH

[ "$TOMCAT_ROOT" = "" ] && TOMCAT_ROOT=`dirname $0`
echo "Tomcat root: $TOMCAT_ROOT"

[ ! -d $TOMCAT_ROOT/work ] && mkdir $TOMCAT_ROOT/work
[ ! -d $TOMCAT_ROOT/temp ] && mkdir $TOMCAT_ROOT/temp
[ ! -d $TOMCAT_ROOT/logs ] && mkdir $TOMCAT_ROOT/logs
[ ! -d $TOMCAT_ROOT/webapps ] && mkdir $TOMCAT_ROOT/webapps

export JAVA_OPTS="$JAVA_OPTS -server -Dfile.encoding=UTF-8 -Dgit.basedir=$TOMCAT_ROOT/webapps/ROOT/WEB-INF/git -Dplatform.autoupgrade=true"
export JAVA_OPTS="$JAVA_OPTS -Dtomcat.adminport=${TOMCAT_ADMIN_PORT:-8005} -Dtomcat.httpport=${TOMCAT_HTTP_PORT:-8080} -Dtomcat.httpsport=${TOMCAT_HTTPS_PORT:-8443}"

if [ -d $TOMCAT_ROOT/webapps/ROOT ]
then
	[ "$DB_VENDOR" = "" ] && DB_VENDOR=hsqldb
	[ "$DB_VENDOR" = "mariadb" ] && DB_VENDOR=mysql
	[ "$DB_VENDOR" = "pgsql" ] && DB_VENDOR=postgresql
	echo "Database vendor: $DB_VENDOR"
	if [ $DB_VENDOR = "mysql" ]
	then
		echo "exit" | mysql --silent --host=$DB_HOST --port=$DB_PORT --user=$DB_USER --password=$DB_PASSWORD --database=$DB_NAME
		RET=$?
		if [ $RET -ne 0 ]
		then
			echo "Unable to connect to database $DB_VENDOR / $DB_HOST / $DB_PORT / $DB_NAME / $DB_USER" >&2
			exit 1
		fi
		EXISTS=`echo "show tables like 'm_system'" | mysql --silent --host=$DB_HOST --port=$DB_PORT --user=$DB_USER --password=$DB_PASSWORD --database=$DB_NAME`
		if [ "$EXISTS" = "" ]
		then
			if [ "$DB_SETUP" = "true" ]
			then
				if [ -f $TOMCAT_ROOT/webapps/ROOT/WEB-INF/db/simplicite-mysql.dmp ]
				then
					echo "Loading database $DB_VENDOR / $DM_HOST / $DB_PORT / $DB_NAME / $DB_USER..."
					mysql --host=$DB_HOST --port=$DB_PORT --user=$DB_USER --password=$DB_PASSWORD < $TOMCAT_ROOT/webapps/ROOT/WEB-INF/db/simplicite-mysql.dmp
					RET=$?
					if [ $RET -ne 0 ]
					then
						echo "Load database error on $DB_VENDOR / $DB_HOST / $DB_PORT / $DB_NAME / $DB_USER" >&2
						exit 4
					fi
					echo "Done"
				else
					echo "No dump to load database $DB_VENDOR / $DB_HOST / $DB_PORT / $DB_NAME / $DB_USER" >&2
					exit 3
				fi
			else
				echo Database $DB_VENDOR / $DB_HOST / $DB_PORT / $DB_NAME / $DB_USER is not setup" >&2
				exit 2
			fi
		fi
		sed -i 's/<!-- hsqldb --><Resource/<!-- hsqldb --><!-- Resource/;s/<\/Resource><!-- hsqldb -->/<\/Resource --><!-- hsqldb -->/;s/<!-- mysql --><!-- Resource/<!-- mysql --><Resource/;s/<\/Resource --><!-- mysql -->/<\/Resource><!-- mysql -->/' $TOMCAT_ROOT/webapps/ROOT/META-INF/context.xml
		JAVA_OPTS="$JAVA_OPTS -Dmysql.user=$DB_USER -Dmysql.password=$DB_PASSWORD -Dmysql.host=$DB_HOST -Dmysql.port=$DB_PORT -Dmysql.database=$DB_NAME"
	elif [ $DB_VENDOR = "postgresql" ]
	then
		echo "\q" | PGPASSWORD=$DB_PASSWORD psql -q -h $DB_HOST -p $DB_PORT -U $DB_USER $DB_NAME
		RET=$?
		if [ $RET -ne 0 ]
		then
			echo "Unable to connect to database $DB_VENDOR / $DB_HOST / $DB_PORT / $DB_NAME / $DB_USER" >&2
			exit 1
		fi
		EXISTS=`echo "select tablename from pg_catalog.pg_tables where tablename = 'm_system'" | PGPASSWORD=$DB_PASSWORD psql -t -h $DB_HOST -p $DB_PORT -U $DB_USER $DB_NAME`
		if [ "$EXISTS" = "" ]
		then
			if [ "$DB_SETUP" = "true" ]
			then
				if [ -f $TOMCAT_ROOT/webapps/ROOT/WEB-INF/db/simplicite-postgresql.dmp ]
				then
					echo "Loading database $DB_VENDOR / $DM_HOST / $DB_PORT / $DB_NAME / $DB_USER..."
					PGPASSWORD=$DB_PASSWORD psql -t -h $DB_HOST -p $DB_PORT -U $DB_USER $DB_NAME < $TOMCAT_ROOT/webapps/ROOT/WEB-INF/db/simplicite-postgresql.dmp
					RET=$?
					if [ $RET -ne 0 ]
					then
						echo "Load database error on $DB_VENDOR / $DB_HOST / $DB_PORT / $DB_NAME / $DB_USER" >&2
						exit 3
					fi
					echo "Done"
				else
					echo "No dump to load database $DB_VENDOR / $DB_HOST / $DB_PORT / $DB_NAME / $DB_USER" >&2
					exit 2
				fi
			else
				echo Database $DB_VENDOR / $DB_HOST / $DB_PORT / $DB_NAME / $DB_USER is not setup" >&2
				exit 2
			fi
		fi
		sed -i 's/<!-- hsqldb --><Resource/<!-- hsqldb --><!-- Resource/;s/<\/Resource><!-- hsqldb -->/<\/Resource --><!-- hsqldb -->/;s/<!-- postgressql --><!-- Resource/<!-- postgresql --><Resource/;s/<\/Resource --><!-- postgresql -->/<\/Resource><!-- postgresql -->/' $TOMCAT_ROOT/webapps/ROOT/META-INF/context.xml
		JAVA_OPTS="$JAVA_OPTS -Dpostgresql.user=$DB_USER -Dpostgresql.password=$DB_PASSWORD -Dpostgresql.host=$DB_HOST -Dpostgresql.port=$DB_PORT -Dpostgresql.database=$DB_NAME"
	fi
else
	mkdir $TOMCAT_ROOT/webapps/ROOT
	echo "It works!" > $TOMCAT_ROOT/webapps/ROOT/index.jsp
fi

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