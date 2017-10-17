#!/bin/bash

export JAVA_HOME=/usr/lib/jvm/java-1.8.0
export PATH=$JAVA_HOME/bin:$PATH

[ "$TOMCAT_ROOT" = "" ] && TOMCAT_ROOT=`dirname $0`
echo "Tomcat root: $TOMCAT_ROOT"

export JAVA_OPTS="$JAVA_OPTS -server -Dfile.encoding=UTF-8 -Dgit.basedir=$TOMCAT_ROOT/webapps/ROOT/WEB-INF/git -Dplatform.autoupgrade=true"
export JAVA_OPTS="$JAVA_OPTS -Dtomcat.adminport=${TOMCAT_ADMIN_PORT:-8005} -Dtomcat.httpport=${TOMCAT_HTTP_PORT:-8080} -Dtomcat.httpsport=${TOMCAT_HTTPS_PORT:-8443}"

[ "$DB_VENDOR" = "" ] && DB_VENDOR=hsqldb
[ "$DB_VENDOR" = "mariadb" ] && DB_VENDOR=mysql
[ "$DB_VENDOR" = "pgsql" ] && DB_VENDOR=postgresql
echo "Database vendor: $DB_VENDOR"

if [ $DB_VENDOR = "mysql" ]
then
	echo "exit" | mysql --host=$DB_HOST --port=$DB_PORT --user=$DB_USER --password=$DB_PASSWORD
	RET=$?
	if [ $RET -ne 0 ]
	then
		echo "Unable to connect to database $DB_VENDOR / $DB_HOST / $DB_PORT / $DB_USER"
		exit 1
	fi
	N=`echo "select count(*) from m_system" | mysql --host=$DB_HOST --port=$DB_PORT --user=$DB_USER --password=$DB_PASSWORD`
	if [ "$N" = "" -o "$N" = "0" ]
	then
		if [ -f $TOMCAT_ROOT/webapps/ROOT/WEB-INF/db/simplicite-mysql.dmp ]
		then
			echo "Loading database $DB_VENDOR / $DM_HOST / $DB_PORT / $DB_USER..."
			mysql --host=$DB_HOST --port=$DB_PORT --user=$DB_USER --password=$DB_PASSWORD < $TOMCAT_ROOT/webapps/ROOT/WEB-INF/db/simplicite-mysql.dmp
			echo "Done"
		else
			echo "Unable to load database $DB_VENDOR / $DB_HOST / $DB_PORT / $DB_USER"
			exit 2
		fi
	fi
	sed -i 's/<!-- hsqldb --><Resource/<!-- hsqldb --><!-- Resource/;s/<\/Resource><!-- hsqldb -->/<\/Resource --><!-- hsqldb -->/;s/<!-- mysql --><!-- Resource/<!-- mysql --><Resource/;s/<\/Resource --><!-- mysql -->/<\/Resource><!-- mysql -->/' $TOMCAT_ROOT/webapps/ROOT/META-INF/context.xml
	JAVA_OPTS="$JAVA_OPTS -Dmysql.user=$DB_USER -Dmysql.password=$DB_PASSWORD -Dmysql.host=$DB_HOST -Dmysql.port=$DB_PORT -Dmysql.database=$DB_NAME"
elif [ $DB_VENDOR = "postgresql" ]
then
	# TODO: check database and load dump if empty
	sed -i 's/<!-- hsqldb --><Resource/<!-- hsqldb --><!-- Resource/;s/<\/Resource><!-- hsqldb -->/<\/Resource --><!-- hsqldb -->/;s/<!-- postgressql --><!-- Resource/<!-- postgresql --><Resource/;s/<\/Resource --><!-- postgresql -->/<\/Resource><!-- postgresql -->/' $TOMCAT_ROOT/webapps/ROOT/META-INF/context.xml
	JAVA_OPTS="$JAVA_OPTS -Dpostgresql.user=$DB_USER -Dpostgresql.password=$DB_PASSWORD -Dpostgresql.host=$DB_HOST -Dpostgresql.port=$DB_PORT -Dpostgresql.database=$DB_NAME"
fi

echo "Java options: $JAVA_OPTS"

[ ! -d $TOMCAT_ROOT/work ] && mkdir $TOMCAT_ROOT/work
[ ! -d $TOMCAT_ROOT/temp ] && mkdir $TOMCAT_ROOT/temp
[ ! -d $TOMCAT_ROOT/logs ] && mkdir $TOMCAT_ROOT/logs
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