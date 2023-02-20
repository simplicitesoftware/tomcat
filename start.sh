#!/bin/bash

[ "$JAVA_HOME" = "" ] && JAVA_HOME="/usr/lib/jvm/java"
if [ ! -d $JAVA_HOME ]
then
	echo "ERROR: JAVA_HOME = $JAVA_HOME is not correctly configured" >&2
	exit 1
fi
echo "Java home: $JAVA_HOME"
export PATH=$JAVA_HOME/bin:$PATH

echo "User: $(whoami)"

[ "$HOSTNAME" = "" ] && export HOSTNAME=$(hostname)
[ "$IP_ADDR" = "" ] && export IP_ADDR=$(hostname -i)
echo "Hostname: $HOSTNAME ($IP_ADDR)"

[ "$TOMCAT_ROOT" = "" ] && TOMCAT_ROOT=$(dirname $0)
TOMCAT_ROOT=$(realpath $TOMCAT_ROOT)
echo "Tomcat root: $TOMCAT_ROOT"

if [ -d $TOMCAT_ROOT/.ssh -o ! -z "$SSH_KNOWN_HOSTS" ]
then
	rm -fr $HOME/.ssh
	mkdir $HOME/.ssh
	[ -d $TOMCAT_ROOT/.ssh ] && cp -r $TOMCAT_ROOT/.ssh/* $HOME/.ssh
	# Convert OpenSSH key if needed
	[ -f $HOME/.ssh/id_rsa ] && grep -q 'BEGIN OPENSSH PRIVATE KEY' $HOME/.ssh/id_rsa && ssh-keygen -p -N "" -m pem -f $HOME/.ssh/id_rsa
	if [ ! -z "$SSH_KNOWN_HOSTS" ]
	then
		touch $HOME/.ssh/known_hosts
		for HOST in $SSH_KNOWN_HOSTS
		do
			H=$(grep "^$HOST " $HOME/.ssh/known_hosts)
			[ "$H" = "" ] && ssh-keyscan $HOST >> $HOME/.ssh/known_hosts
		done
	fi
	chmod -R go-rwX $HOME/.ssh
fi

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

export JAVA_OPTS="$JAVA_OPTS -server -Dserver.vendor=tomcat -Dserver.version=9 -Djava.awt.headless=true -Dfile.encoding=UTF-8 -Duser.timezone=${TOMCAT_TIMEZONE:-${TZ:-$(date +%Z)}} -Dplatform.autoupgrade=true -Dtomcat.webapp=$TOMCAT_WEBAPP"
export JAVA_OPTS="$JAVA_OPTS -Dtomcat.adminport=${TOMCAT_ADMIN_PORT:-8005} -Dtomcat.httpport=${TOMCAT_HTTP_PORT:-8080} -Dtomcat.httpsport=${TOMCAT_HTTPS_PORT:-8443} -Dtomcat.httpredirectport=${TOMCAT_HTTPREDIRECTPORT:-443} -Dtomcat.ajpredirectport=${TOMCAT_AJPREDIRECTPORT:-443}"
export JAVA_OPTS="$JAVA_OPTS -Dtomcat.maxhttpheadersize=${TOMCAT_MAXHTTPHEADERSIZE:-8192} -Dtomcat.maxthreads=${TOMCAT_MAXTHREADS:-200} -Dtomcat.maxconnections=${TOMCAT_MAXCONNECTIONS:-8192} -Dtomcat.maxpostsize=${TOMCAT_MAXPOSTSIZE:--1}"
[ "$GZIP" = "true" -o "$TOMCAT_COMPRESSION" = "on" ] && export JAVA_OPTS="$JAVA_OPTS -Dtomcat.compression=on"
if [ "$SSL" = "true" -o ${TOMCAT_SSL_PORT:-0} -gt 0 ]
then
	export JAVA_OPTS="$JAVA_OPTS -Dtomcat.sslport=${TOMCAT_SSL_PORT:-8444} -Dtomcat.sslkeystorefile=${KEYSTORE_FILE:-$TOMCAT_ROOT/conf/server.jks} -Dtomcat.sslkeystorepassword=${KEYSTORE_PASSWORD:-password}"
	grep -q '<!-- SSL Connector' $TOMCAT_ROOT/conf/server.xml
	if [ $? = 0 -a -w $TOMCAT_ROOT/conf/server.xml ]
	then
		sed -i 's/<!-- SSL Connector/<Connector/;s/Connector SSL -->/Connector>/' $TOMCAT_ROOT/conf/server.xml
	else
		echo "WARNING: $TOMCAT_ROOT/conf/server.xml is not writeable, unable to enable the SSL connector"
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
		echo "WARNING: $TOMCAT_ROOT/conf/server.xml is not writeable, unable to enable the AJP connector"
	fi
fi
export JAVA_OPTS="$JAVA_OPTS -Dgit.basedir=${GIT_BASEDIR:-$TOMCAT_ROOT/webapps/$TOMCAT_WEBAPP/WEB-INF/git}"
[ ${TOMCAT_JMX_PORT:-0} -gt 0 ] && JMX="true"
[ "$JMX" = "true" ] && export JAVA_OPTS="$JAVA_OPTS -Dplatform.mbean=true -Dcom.sun.management.jmxremote -Dcom.sun.management.jmxremote.port=${TOMCAT_JMX_PORT:-8555} -Dcom.sun.management.jmxremote.local.only=false -Dcom.sun.management.jmxremote.ssl=false -Dcom.sun.management.jmxremote.authenticate=false"
[ "$DEBUG" = "true" ] && export JAVA_OPTS="$JAVA_OPTS -Dplatform.debug=true"
[ ${TOMCAT_JPDA_PORT:-0} -gt 0 ] && JPDA="true"
[ "$JPDA" = "true" ] && export JPDA_ADDRESS=${TOMCAT_JPDA_HOST:-0.0.0.0}:${TOMCAT_JPDA_PORT:-8000}
[ "$WEBSOCKETS" = "true" -o "$WEBSOCKETS" = "false" ] && export JAVA_OPTS="$JAVA_OPTS -Dserver.websocket=$WEBSOCKETS"
[ "$GOD_MODE" = "true" -o "$GOD_MODE" = "false" ] && export JAVA_OPTS="$JAVA_OPTS -Dplatform.godmode=$GOD_MODE"
[ "$TOMCAT_LOG_ARGS" = "true" -o "$TOMCAT_LOG_ARGS" = "false" ] && export JAVA_OPTS="$JAVA_OPTS -Dtomcat.logargs=$TOMCAT_LOG_ARGS"
[ "$TOMCAT_LOG_ENV" = "true" -o "$TOMCAT_LOG_ENV" = "false" ] && export JAVA_OPTS="$JAVA_OPTS -Dtomcat.logenv=$TOMCAT_LOG_ENV"
[ "$TOMCAT_LOG_PROPS" = "true" -o "$TOMCAT_LOG_PROPS" = "false" ] && export JAVA_OPTS="$JAVA_OPTS -Dtomcat.logprops=$TOMCAT_LOG_PROPS"
[ "$SERVER_URL" != "" ] && export JAVA_OPTS="$JAVA_OPTS -Dapplication.url=${SERVER_URL}"
if [ "$JACOCO_MODULES" != "" ]
then
	JCCHOME=${JACOCO_HOME:-/usr/local/jacoco}
	if [ -d $JCCHOME ]
	then
		[ -d $JCCHOME/lib ] && JCCHOME=$JCCHOME/lib
		JCCDESTFILE=${JACOCO_DESTFILE:-/var/lib/jacoco/jacoco.exec}
		JCCDESTDIR=`dirname $JCCDESTFILE`
		[ ! -d $DESTDIR ] && mkdir -p $JCCDESTDIR
		rm -f $JCCDESTFILE
		JCCSERVER=""
		[ "$JACOCO_SERVER" = "true" -o "$JACOCO_ADDRESS" != "" -o "$JACOCO_PORT" != "" ] && JCCSERVER=",output=tcpserver,address=${JACOCO_ADDRESS:-*},port=${JACOCO_PORT:-8001}"
		JCCINCLUDES=""
		JCCEXCLUDES=""
		for MODULE in ${JACOCO_MODULES//,/ }
		do
			[ "$JCCINCLUDES" != "" ] && JCCINCLUDES="${JCCINCLUDES}:"
			JCCINCLUDES="${JCCINCLUDES}com.simplicite.*.${MODULE}.*"
			[ "$JCCEXCLUDES" != "" ] && JCCEXCLUDES="${JCCEXCLUDES}:"
			JCCEXCLUDES="${JCCEXCLUDES}com.simplicite.tests.${MODULE}.*"
		done
		JCCOPTS="-javaagent:${JCCHOME}/jacocoagent.jar=destfile=${JCCDESTFILE},includes=${JCCINCLUDES},excludes=${JCCEXCLUDES}${JCCSERVER}"
		echo "JaCoCo options: $JCCOPTS"
		JAVA_OPTS="$JAVA_OPTS $JCCOPTS"
	else
		echo "WARNING: JaCoCo is not present"
	fi
fi

SYSPARAMS=$(env | grep '^SYSPARAM_' | sed "s/=/\|/;s/'/''/g" | awk -F\| '{ print "update m_system set sys_value2 = \x27"$2"\x27 where sys_code = \x27"substr($1, 10)"\x27;" }')
[ "$SYSPARAMS" != "" ] && SYSPARAMS="${SYSPARAMS}commit;"

if [ -d $TOMCAT_ROOT/webapps/$TOMCAT_WEBAPP ]
then
	[ "$DB_VENDOR" = "" ] && DB_VENDOR=hsqldb
	[ "$DB_VENDOR" = "mariadb" ] && DB_VENDOR=mysql
	[ "$DB_VENDOR" = "pgsql" -o "$DB_VENDOR" = "postgres" ] && DB_VENDOR=postgresql
	[ "$DB_VENDOR" = "sqlserver" ] && DB_VENDOR=mssql
	echo "Database vendor: $DB_VENDOR"
	# Check if generic database configuration is enabled (e.g. in Docker images)
	grep -q '<!-- database --><Resource' $TOMCAT_ROOT/webapps/$TOMCAT_WEBAPP/META-INF/context.xml
	GENERIC_DB=$?
	if [ $DB_VENDOR = "hsqldb" -a $GENERIC_DB = 0 ]
	then
		JAVA_OPTS="$JAVA_OPTS -Ddb.vendor='$DB_VENDOR' -Ddb.user='sa' -Ddb.password='' -Ddb.driver='org.hsqldb.jdbcDriver' -Ddb.url='hsqldb:file:$TOMCAT_ROOT/webapps/$TOMCAT_WEBAPP/WEB-INF/db/simplicite;shutdown=true;sql.ignore_case=true'"
		if [ "$SYSPARAMS" != "" ]
		then
			echo "Setting system parameters..."
			WEBINF=$TOMCAT_ROOT/webapps/$TOMCAT_WEBAPP/WEB-INF
			DRIVER=$(find $WEBINF -name hsqldb-\*.jar -print)
			SQLTOOL=$(find $WEBINF -name sqltool-\*.jar -print)
			echo $SYSPARAMS | java $JAVA_OPTS -cp $DRIVER:$SQLTOOL org.hsqldb.cmdline.SqlTool --inlineRc="url=jdbc:hsqldb:file:$TOMCAT_ROOT/webapps/${TOMCAT_WEBAPP:-ROOT}/WEB-INF/db/simplicite;shutdown=true;sql.ignore_case=true,user=sa,password=" --continueOnErr=true > /dev/null
			RES=$?
			[ $RES -eq 0 ] && echo "Done" || echo "Failed"
		fi
	elif [ $DB_VENDOR = "mysql" ]
	then
		[ "$DB_HOST" = "" ] && DB_HOST=127.0.0.1
		[ "$DB_PORT" = "" ] && DB_PORT=3306
		[ "$DB_SSL" = "" ] && DB_SSL=false
		[ "$DB_MYISAM" = "" ] && DB_MYISAM=false
		if [ "$DB_NAME" = "" -o "$DB_USER" = "" -o "$DB_PASSWORD" = "" ]
		then
			echo "ERROR: Missing database name, user and/or password" >&2
			exit 2	
		fi
		echo "MySQL database: $DB_HOST / $DB_PORT / $DB_NAME / $DB_USER"
		if [ $GENERIC_DB = 0 ]
		then
			JAVA_OPTS="$JAVA_OPTS -Ddb.vendor='$DB_VENDOR' -Ddb.user='$DB_USER' -Ddb.password='$DB_PASSWORD' -Ddb.driver='com.mysql.cj.jdbc.Driver' -Ddb.url='mysql://$DB_HOST:$DB_PORT/$DB_NAME?autoReconnect=true&useSSL=$DB_SSL&allowPublicKeyRetrieval=true&characterEncoding=utf8&characterResultSets=utf8&serverTimezone=${TOMCAT_TIMEZONE:-${TZ:-$(date +%Z)}}$DB_OPTS'"
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
		T=${DB_WAIT_INTERVAL:-5}
		N=0
		while [ $N -lt $W ]
		do
			N=$(expr $N + 1)
			echo "exit" | mysql --silent --host=$DB_HOST --port=$DB_PORT --user=$DB_USER --password=$DB_PASSWORD --database=$DB_NAME
			RET=$?
			if [ $RET -ne 0 ]
			then
				if [ $W -eq 1 -o $N -eq $W ]
				then
					echo "ERROR: Unable to connect to database" >&2
					exit 4
				else
					echo "Waiting $T seconds for database ($N)"
					sleep $T
				fi
			fi
		done
		EXISTS=$(echo "show tables like 'm_system'" | mysql --silent --host=$DB_HOST --port=$DB_PORT --user=$DB_USER --password=$DB_PASSWORD --database=$DB_NAME)
		if [ "$EXISTS" = "" ]
		then
			if [ "$DB_SETUP" = "true" -o "$DB_SETUP" = "yes" ]
			then
				if [ -f $TOMCAT_ROOT/webapps/$TOMCAT_WEBAPP/WEB-INF/db/simplicite-mysql.dmp ]
				then
					if [ $DB_MYISAM = "true" -o $DB_MYISAM = "yes" ]
					then
						echo "Forcing MyISAM engine"
						sed -i 's/InnoDB/MyISAM/g' $TOMCAT_ROOT/webapps/$TOMCAT_WEBAPP/WEB-INF/db/simplicite-mysql.dmp
						echo "Done"
					fi
					echo "Loading database..."
					mysql --silent --host=$DB_HOST --port=$DB_PORT --user=$DB_USER --password=$DB_PASSWORD $DB_NAME < $TOMCAT_ROOT/webapps/$TOMCAT_WEBAPP/WEB-INF/db/simplicite-mysql.dmp
					RET=$?
					if [ $RET -ne 0 ]
					then
						echo "ERROR: Load database error" >&2
						exit 7
					fi
					if [ "$DBDOC" != "" ]
					then
						mysql --silent --host=$DB_HOST --port=$DB_PORT --user=$DB_USER --password=$DB_PASSWORD $DB_NAME --execute="update m_system set sys_value='$DBDOC' where sys_code='DOC_DIR'"
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
		if [ "$SYSPARAMS" != "" ]
		then
			echo "Setting system parameters..."
			mysql --silent --host=$DB_HOST --port=$DB_PORT --user=$DB_USER --password=$DB_PASSWORD $DB_NAME --execute="$(echo $SYSPARAMS)"
			echo "Done"
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
			JAVA_OPTS="$JAVA_OPTS -Ddb.vendor='$DB_VENDOR' -Ddb.user='$DB_USER' -Ddb.password='$DB_PASSWORD' -Ddb.driver='org.postgresql.Driver' -Ddb.url='postgresql://$DB_HOST:$DB_PORT/$DB_NAME?ssl=$DB_SSL$DB_OPTS'"
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
		T=${DB_WAIT_INTERVAL:-5}
		N=0
		while [ $N -lt $W ]
		do
			N=$(expr $N + 1)
			echo "\q" | PGPASSWORD=$DB_PASSWORD psql --quiet -h $DB_HOST -p $DB_PORT -U $DB_USER $DB_NAME
			RET=$?
			if [ $RET -ne 0 ]
			then
				if [ $W -eq 1 -o $N -eq $W ]
				then
					echo "ERROR: Unable to connect to database" >&2
					exit 4
				else
					echo "Waiting $T seconds for database ($N)"
					sleep $T
				fi
			fi
		done
		EXISTS=$(echo "select tablename from pg_catalog.pg_tables where tablename = 'm_system'" | PGPASSWORD=$DB_PASSWORD psql -t -h $DB_HOST -p $DB_PORT -U $DB_USER $DB_NAME)
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
					if [ "$DBDOC" != "" ]
					then
						PGPASSWORD=$DB_PASSWORD psql --quiet -h $DB_HOST -p $DB_PORT -U $DB_USER $DB_NAME -c "update m_system set sys_value='$DBDOC' where sys_code='DOC_DIR'"
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
		if [ "$SYSPARAMS" != "" ]
		then
			echo "Setting system parameters..."
			PGPASSWORD=$DB_PASSWORD psql --quiet -h $DB_HOST -p $DB_PORT -U $DB_USER $DB_NAME -c "$(echo $SYSPARAMS)"
			echo "Done"
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
			JAVA_OPTS="$JAVA_OPTS -Ddb.vendor='$DB_VENDOR' -Ddb.user='$DB_USER' -Ddb.password='$DB_PASSWORD' -Ddb.driver='oracle.jdbc.driver.OracleDriver' -Ddb.url='oracle:thin:@$DB_HOST:$DB_PORT:$DB_NAME$DB_OPTS'"
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
		T=${DB_WAIT_INTERVAL:-5}
		N=0
		while [ $N -lt $W ]
		do
			N=$(expr $N + 1)
			sqlplus -S $DB_USER/$DB_PASSWORD@//$DB_HOST:$DB_PORT/$DB_NAME << EOF > /dev/null 2>&1
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
					echo "Waiting $T seconds for database ($N)"
					sleep $T
				fi
			fi
		done
		sqlplus -S $DB_USER/$DB_PASSWORD@//$DB_HOST:$DB_PORT/$DB_NAME << EOF > /dev/null 2>&1
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
					sqlplus -S $DB_USER/$DB_PASSWORD@//$DB_HOST:$DB_PORT/$DB_NAME < $TOMCAT_ROOT/webapps/$TOMCAT_WEBAPP/WEB-INF/db/simplicite-oracle.sql
					RET=$?
					if [ $RET -ne 0 ]
					then
						echo "ERROR: Load database error" >&2
						exit 7
					fi
					if [ "$DBDOC" != "" ]
					then
						sqlplus -S $DB_USER/$DB_PASSWORD@//$DB_HOST:$DB_PORT/$DB_NAME << EOF > /dev/null 2>&1
whenever sqlerror exit 1;
update m_system set sys_value='$DBDOC' where sys_code='DOC_DIR';
commit;
EOF
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
		if [ "$SYSPARAMS" != "" ]
		then
			echo "Setting system parameters..."
			echo $SYSPARAMS | sqlplus -S $DB_USER/$DB_PASSWORD@//$DB_HOST:$DB_PORT/$DB_NAME
			echo "Done"
		fi
	elif [ $DB_VENDOR = "mssql" ]
	then
		[ "$DB_HOST" = "" ] && DB_PORT=127.0.0.1
		[ "$DB_PORT" = "" ] && DB_PORT=1433
		[ "$DB_SSL" = "" ] && DB_SSL=false
		if [ "$DB_NAME" = "" -o "$DB_USER" = "" -o "$DB_PASSWORD" = "" ]
		then
			echo "ERROR: Missing database name, user and/or password" >&2
			exit 2	
		fi
		echo "SQLServer database: $DB_HOST / $DB_PORT / $DB_NAME / $DB_USER"
		if [ $GENERIC_DB = 0 ]
		then
			JAVA_OPTS="$JAVA_OPTS -Ddb.vendor='$DB_VENDOR' -Ddb.user='$DB_USER' -Ddb.password='$DB_PASSWORD' -Ddb.driver='com.microsoft.sqlserver.jdbc.SQLServerDriver' -Ddb.url='sqlserver://$DB_HOST:$DB_PORT;databaseName=$DB_NAME;encrypt=$DB_SSL;trustServerCertificate=true$DB_OPTS'"
		else
			JAVA_OPTS="$JAVA_OPTS -Dmssql.user=$DB_USER -Dmssql.password=$DB_PASSWORD -Dmssql.host=$DB_HOST -Dmssql.port=$DB_PORT -Dmssql.database=$DB_NAME -Dmssql.ssl=$DB_SSL"
			if [ -w $TOMCAT_ROOT/webapps/$TOMCAT_WEBAPP/META-INF/context.xml ]
			then
				sed -i 's/<!-- hsqldb --><Resource/<!-- hsqldb --><!-- Resource/;s/<\/Resource><!-- hsqldb -->/<\/Resource --><!-- hsqldb -->/;s/<!-- mssql --><!-- Resource/<!-- mssql --><Resource/;s/<\/Resource --><!-- mssql -->/<\/Resource><!-- mssql -->/' $TOMCAT_ROOT/webapps/$TOMCAT_WEBAPP/META-INF/context.xml
			else
				echo "ERROR: $TOMCAT_ROOT/webapps/$TOMCAT_WEBAPP/META-INF/context.xml is not writeable, unable to setup mssql connection"
				exit 3
			fi
		fi
		W=${DB_WAIT:-1}
		T=${DB_WAIT_INTERVAL:-5}
		N=0
		while [ $N -lt $W ]
		do
			N=$(expr $N + 1)
			sqlcmd -S $DB_HOST,$DB_PORT -U $DB_USER -P $DB_PASSWORD -b -Q "select 1"
			RET=$?
			if [ $RET -ne 0 ]
			then
				if [ $W -eq 1 -o $N -eq $W ]
				then
					echo "ERROR: Unable to connect to database" >&2
					exit 4
				else
					echo "Waiting $T seconds for database ($N)"
					sleep $T
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
					if [ "$DBDOC" != "" ]
					then
						sqlcmd -S $DB_HOST,$DB_PORT -U $DB_USER -P $DB_PASSWORD -b -Q "update m_system set sys_value='$DBDOC' where sys_code='DOC_DIR'"
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
		if [ "$SYSPARAMS" != "" ]
		then
			echo "Setting system parameters..."
			sqlcmd -S $DB_HOST,$DB_PORT -U $DB_USER -P $DB_PASSWORD -b -Q "$(echo $SYSPARAMS)"
			echo "Done"
		fi
	else
		echo "ERROR: Unknown database vendor ($DB_VENDOR)" >&2
		exit 8
	fi
elif [ -w $TOMCAT_ROOT/webapps ]
then
	echo -n "Generating default webapp... "
	mkdir $TOMCAT_ROOT/webapps/$TOMCAT_WEBAPP
	mkdir $TOMCAT_ROOT/webapps/$TOMCAT_WEBAPP/WEB-INF
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
	mkdir $TOMCAT_ROOT/webapps/$TOMCAT_WEBAPP/WEB-INF/classes
	cat > $TOMCAT_ROOT/webapps/$TOMCAT_WEBAPP/WEB-INF/classes/logging.properties << EOF
handlers = java.util.logging.ConsoleHandler
java.util.logging.ConsoleHandler.level = FINE
java.util.logging.ConsoleHandler.formatter = java.util.logging.SimpleFormatter
java.util.logging.ConsoleHandler.encoding = UTF-8
EOF
	cat > $TOMCAT_ROOT/webapps/$TOMCAT_WEBAPP/WEB-INF/classes/log4j2.xml << EOF
<?xml version="1.0" encoding="UTF-8"?>
<Configuration status="info">
	<Appenders>
		<Console name="CONSOLE" target="SYSTEM_OUT">
			<PatternLayout pattern="%highlight{%date|%marker|%level|%message%n%throwable}{FATAL=magenta, ERROR=red, WARN=yellow, INFO=green, DEBUG=blue, TRACE=blue}"/>
		</Console>
	</Appenders>
	<Loggers>
		<Root level="debug">
			<AppenderRef ref="CONSOLE"/>
		</Root>
	</Loggers>
</Configuration>
EOF
	mkdir $TOMCAT_ROOT/webapps/$TOMCAT_WEBAPP/META-INF
	cat > $TOMCAT_ROOT/webapps/$TOMCAT_WEBAPP/META-INF/context.xml << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE Context>
<Context>
	<Manager pathname=""/>
	<JarScanner scanClassPath="false" scanAllDirectories="false" scanAllFiles="false" scanBootstrapClassPath="false" scanManifest="false">
		<JarScanFilter defaultTldScan="false" defaultPluggabilityScan="false"/>
	</JarScanner>
	<Valve className="com.simplicite.tomcat.valves.APISessionValve" debug="true"/>
</Context>
EOF
	cp -f $TOMCAT_ROOT/favicon.ico $TOMCAT_ROOT/webapps/$TOMCAT_WEBAPP
	cat > $TOMCAT_ROOT/webapps/$TOMCAT_WEBAPP/index.jsp << EOF
<% java.util.logging.Logger.getLogger(getClass().getName()).info("Request from " + request.getRemoteAddr()); %><!DOCTYPE html>
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
Hostname: <%= java.net.InetAddress.getLocalHost().getHostName() %>
Remote host: <%= request.getRemoteHost() %>
Remote port: <%= request.getRemotePort() %>
Remote address: <%= request.getRemoteAddr() %>
Session ID: <%= request.getSession().getId() %>
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
	mkdir $TOMCAT_ROOT/webapps/$TOMCAT_WEBAPP/api
	cat > $TOMCAT_ROOT/webapps/$TOMCAT_WEBAPP/api/index.jsp << EOF
<%@ page language="java" contentType="application/json; charset=UTF-8" pageEncoding="UTF-8"%>{
	"os": "<%= System.getProperty("os.name") + " " + System.getProperty("os.arch") + " " + System.getProperty("os.version") %>",
	"jvm": "<%= System.getProperty("java.version") + " " + System.getProperty("java.vendor") + " " + System.getProperty("java.vm.name") + " " + System.getProperty("java.vm.version") %>",
	"encoding": "<%= System.getProperty("file.encoding") %>",
	"server": "<%= request.getServletContext().getServerInfo() %>",
	"hostname": "<%= java.net.InetAddress.getLocalHost().getHostName() %>",
	"sessionId": "<%= request.getSession().getId() %>",
	"systemdate": "<%= new java.util.Date() %>"
}
EOF
	echo "Done"
fi

if [ "$LOG4J_ROOT_LEVEL" != "" ]
then
	if [ -w $TOMCAT_ROOT/webapps/$TOMCAT_WEBAPP/WEB-INF/classes/log4j2.xml ]
	then
		sed -i "/Root/s/level=\"debug\"/level=\"$LOG4J_ROOT_LEVEL\"/" $TOMCAT_ROOT/webapps/$TOMCAT_WEBAPP/WEB-INF/classes/log4j2.xml
	else
		echo "WARNING: $TOMCAT_ROOT/webapps/$TOMCAT_WEBAPP/WEB-INF/classes/log4j2.xml is not writeable, unable to set root log level"
	fi
fi
if [ "$LOG4J_CONSOLE" = "true" -o "$LOG4J_CONSOLE" = "false" ]
then
	if [ -w $TOMCAT_ROOT/webapps/$TOMCAT_WEBAPP/WEB-INF/classes/log4j2.xml ]
	then
		if [ $LOG4J_CONSOLE = "false" ]
		then
			sed -i 's/<AppenderRef ref="SIMPLICITE-CONSOLE"\/>/<!-- AppenderRef ref="SIMPLICITE-CONSOLE"\/ -->/' $TOMCAT_ROOT/webapps/$TOMCAT_WEBAPP/WEB-INF/classes/log4j2.xml
		else
			sed -i 's/<!-- AppenderRef ref="SIMPLICITE-CONSOLE"\/ -->/<AppenderRef ref="SIMPLICITE-CONSOLE"\/>/' $TOMCAT_ROOT/webapps/$TOMCAT_WEBAPP/WEB-INF/classes/log4j2.xml
		fi
	else
		echo "WARNING: $TOMCAT_ROOT/webapps/$TOMCAT_WEBAPP/WEB-INF/classes/log4j2.xml is not writeable, unable to enable/disable console appender"
	fi
fi
if [ $"LOG4J_FILE" = "true" -o $"LOG4J_FILE" = "false" ]
then
	if [ -w $TOMCAT_ROOT/webapps/$TOMCAT_WEBAPP/WEB-INF/classes/log4j2.xml ]
	then
		if [ $LOG4J_FILE = "false" ]
		then
			sed -i 's/<AppenderRef ref="SIMPLICITE-FILE"\/>/<!-- AppenderRef ref="SIMPLICITE-FILE"\/ -->/' $TOMCAT_ROOT/webapps/$TOMCAT_WEBAPP/WEB-INF/classes/log4j2.xml
		else
			sed -i 's/<!-- AppenderRef ref="SIMPLICITE-FILE"\/ -->/<AppenderRef ref="SIMPLICITE-FILE"\/>/' $TOMCAT_ROOT/webapps/$TOMCAT_WEBAPP/WEB-INF/classes/log4j2.xml
		fi
	else
		echo "WARNING: $TOMCAT_ROOT/webapps/$TOMCAT_WEBAPP/WEB-INF/classes/log4j2.xml is not writeable, unable to enable/disable file appender"
	fi
fi
if [ "$LOGGING_CONSOLE_LEVEL" != "" ]
then
	if [ -w $TOMCAT_ROOT/webapps/$TOMCAT_WEBAPP/WEB-INF/classes/logging.properties ]
	then
		sed -i "/java.util.logging.ConsoleHandler.level/s/FINE/$LOGGING_CONSOLE_LEVEL/" $TOMCAT_ROOT/webapps/$TOMCAT_WEBAPP/WEB-INF/classes/logging.properties
	else
		echo "WARNING: $TOMCAT_ROOT/webapps/$TOMCAT_WEBAPP/WEB-INF/classes/logging.properties is not writeable, unable to set console log level"
	fi
fi
if [ "$LOGGING_FILE_LEVEL" != "" ]
then
	if [ -w $TOMCAT_ROOT/webapps/$TOMCAT_WEBAPP/WEB-INF/classes/logging.properties ]
	then
		sed -i "/java.util.logging.FileHandler.level/s/FINE/$LOGGING_FILE_LEVEL/" $TOMCAT_ROOT/webapps/$TOMCAT_WEBAPP/WEB-INF/classes/logging.properties
	else
		echo "WARNING: $TOMCAT_ROOT/webapps/$TOMCAT_WEBAPP/WEB-INF/classes/logging.properties is not writeable, unable to set file log level"
	fi
fi

if [ "$HEALTH_WHITELIST" != "" ]
then
	if [ -w $TOMCAT_ROOT/webapps/$TOMCAT_WEBAPP/WEB-INF/web.xml ]
	then
		sed -i 's/<!-- healthwhitelist --><!-- /<!-- healthwhitelist --></;s/ --><!-- healthwhitelist -->/><!-- healthwhitelist -->/' $TOMCAT_ROOT/webapps/$TOMCAT_WEBAPP/WEB-INF/web.xml
		sed -i "s~@healthwhitelist@~${HEALTH_WHITELIST}~" $TOMCAT_ROOT/webapps/$TOMCAT_WEBAPP/WEB-INF/web.xml
	else
		echo "WARNING: $TOMCAT_ROOT/webapps/$TOMCAT_WEBAPP/WEB-INF/web.xml is not writeable, unable to set health check white list"
	fi
fi

if [ "$IO_WHITELIST" != "" ]
then
	if [ -w $TOMCAT_ROOT/webapps/$TOMCAT_WEBAPP/WEB-INF/web.xml ]
	then
		sed -i 's/<!-- iowhitelist --><!-- /<!-- iowhitelist --></;s/ --><!-- iowhitelist -->/><!-- iowhitelist -->/' $TOMCAT_ROOT/webapps/$TOMCAT_WEBAPP/WEB-INF/web.xml
		sed -i "s~@iowhitelist@~${IO_WHITELIST}~" $TOMCAT_ROOT/webapps/$TOMCAT_WEBAPP/WEB-INF/web.xml
	else
		echo "WARNING: $TOMCAT_ROOT/webapps/$TOMCAT_WEBAPP/WEB-INF/web.xml is not writeable, unable to set I/O endpoint white list"
	fi
fi

if [ "$GIT_WHITELIST" != "" ]
then
	if [ -w $TOMCAT_ROOT/webapps/$TOMCAT_WEBAPP/WEB-INF/web.xml ]
	then
		sed -i 's/<!-- gitwhitelist --><!-- /<!-- gitwhitelist --></;s/ --><!-- gitwhitelist -->/><!-- gitwhitelist -->/' $TOMCAT_ROOT/webapps/$TOMCAT_WEBAPP/WEB-INF/web.xml
		sed -i "s~@gitwhitelist@~${GIT_WHITELIST}~" $TOMCAT_ROOT/webapps/$TOMCAT_WEBAPP/WEB-INF/web.xml
	else
		echo "WARNING: $TOMCAT_ROOT/webapps/$TOMCAT_WEBAPP/WEB-INF/web.xml is not writeable, unable to set Git enpoint white list"
	fi
fi

if [ "$MAVEN_WHITELIST" != "" ]
then
	if [ -w $TOMCAT_ROOT/webapps/$TOMCAT_WEBAPP/WEB-INF/web.xml ]
	then
		sed -i 's/<!-- mavenwhitelist --><!-- /<!-- mavenwhitelist --></;s/ --><!-- mavenwhitelist -->/><!-- mavenwhitelist -->/' $TOMCAT_ROOT/webapps/$TOMCAT_WEBAPP/WEB-INF/web.xml
		sed -i "s~@healthwhitelist@~${MAVEN_WHITELIST}~" $TOMCAT_ROOT/webapps/$TOMCAT_WEBAPP/WEB-INF/web.xml
	else
		echo "WARNING: $TOMCAT_ROOT/webapps/$TOMCAT_WEBAPP/WEB-INF/web.xml is not writeable, unable to set Maven repository white list"
	fi
fi

if [ "$API_WHITELIST" != "" ]
then
	if [ -w $TOMCAT_ROOT/webapps/$TOMCAT_WEBAPP/WEB-INF/web.xml ]
	then
		sed -i 's/<!-- apiwhitelist --><!-- /<!-- apiwhitelist --></;s/ --><!-- apiwhitelist -->/><!-- apiwhitelist -->/' $TOMCAT_ROOT/webapps/$TOMCAT_WEBAPP/WEB-INF/web.xml
		sed -i "s~@apiwhitelist@~${API_WHITELIST}~" $TOMCAT_ROOT/webapps/$TOMCAT_WEBAPP/WEB-INF/web.xml
	else
		echo "WARNING: $TOMCAT_ROOT/webapps/$TOMCAT_WEBAPP/WEB-INF/web.xml is not writeable, unable to set API enpoint white list"
	fi
fi

if [ "$UI_WHITELIST" != "" ]
then
	if [ -w $TOMCAT_ROOT/webapps/$TOMCAT_WEBAPP/WEB-INF/web.xml ]
	then
		sed -i 's/<!-- uiwhitelist --><!-- /<!-- uiwhitelist --></;s/ --><!-- uiwhitelist -->/><!-- uiwhitelist -->/' $TOMCAT_ROOT/webapps/$TOMCAT_WEBAPP/WEB-INF/web.xml
		sed -i "s~@apiwhitelist@~${UI_WHITELIST}~" $TOMCAT_ROOT/webapps/$TOMCAT_WEBAPP/WEB-INF/web.xml
	else
		echo "WARNING: $TOMCAT_ROOT/webapps/$TOMCAT_WEBAPP/WEB-INF/web.xml is not writeable, unable to set UI enpoint white list"
	fi
fi

if [ "$CORS" = "true" ]
then
	if [ -w $TOMCAT_ROOT/webapps/$TOMCAT_WEBAPP/WEB-INF/web.xml ]
	then
		sed -i 's/<!-- cors --><!-- /<!-- cors --></;s/ --><!-- cors -->/><!-- cors -->/' $TOMCAT_ROOT/webapps/$TOMCAT_WEBAPP/WEB-INF/web.xml
		sed -i "s~@cors.origins@~${CORS_ORIGINS:-\*}~;s~@cors.credentials@~${CORS_CREDENTIALS:-true}~;s~@cors.maxage@~${CORS_MAXAGE:-1728000}~" $TOMCAT_ROOT/webapps/$TOMCAT_WEBAPP/WEB-INF/web.xml
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

if [ "$SECURE_COOKIES" = "true" ]
then
	if [ -w $TOMCAT_ROOT/webapps/$TOMCAT_WEBAPP/WEB-INF/web.xml ]
	then
		sed -i 's/<!-- cookie-config>/<cookie-config>/;s/<\/cookie-config -->/<\/cookie-config>/' $TOMCAT_ROOT/webapps/$TOMCAT_WEBAPP/WEB-INF/web.xml
	else
		echo "WARNING: $TOMCAT_ROOT/webapps/$TOMCAT_WEBAPP/WEB-INF/web.xml is not writeable, unable to set cookiee-related options"
	fi
fi

if [ "$CLUSTER" = "true" ]
then
	#export JAVA_OPTS="$JAVA_OPTS -Dtomcat.clusteraddress=$IP_ADDR"
	grep -q '<!-- CLUSTER Cluster' $TOMCAT_ROOT/conf/server.xml
	if [ $? = 0 -a -w $TOMCAT_ROOT/conf/server.xml -a -w $TOMCAT_ROOT/webapps/$TOMCAT_WEBAPP/META-INF/context.xml ]
	then
		sed -i 's/<!-- CLUSTER Cluster/<Cluster/;s/Cluster CLUSTER -->/Cluster>/' $TOMCAT_ROOT/conf/server.xml
		sed -i 's/<Context/<Context distributable="true"/' $TOMCAT_ROOT/webapps/$TOMCAT_WEBAPP/META-INF/context.xml
	else
		echo "WARNING: $TOMCAT_ROOT/conf/server.xml or $TOMCAT_ROOT/webapps/$TOMCAT_WEBAPP/META-INF/context.xml is not writeable, unable to enable clustering"
	fi
fi

if [ "$1" = "-r" -o "$1" = "--run" ]
then
	cd $TOMCAT_ROOT/bin

	if [ "$JPDA" = "true" ]
	then
		echo ""
		echo "ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ"
		echo "ZZZ Tomcat is running in debug mode, this is not suitable for production ZZZ"
		echo "ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ"
		echo ""
		exec ./catalina.sh jpda run
	else
		exec ./catalina.sh run
	fi
else
	cd $TOMCAT_ROOT/bin

	if [ "$JPDA" = "true" ]
	then
		if [ -w startup.sh ]
		then
			echo ""
			echo "ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ"
			echo "ZZZ Tomcat is running in debug mode, this is not suitable for production ZZZ"
			echo "ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ"
			echo ""
			[ "$JPDA_SUSPEND" = "true" ] && export JPDA_SUSPEND=y
			[ "$JPDA_SUSPEND" = "false" ] && export JPDA_SUSPEND=n
			sed -i '/^exec /s/" start /" jpda start /' startup.sh
		else
			echo "WARNING: $TOMCAT_ROOT/bin/startup.sh is not writeable, unable to set debug mode"
		fi
	else
		[ -w startup.sh ] && sed -i '/^exec /s/" jpda start /" start /' startup.sh
	fi

	./startup.sh
	cd ..
	
	if [ "$1" = "-t" -o "$1" = "--tail" ]
	then
		LOG=logs/catalina.out
		while [ ! -f $LOG ]; do echo -n "."; sleep 1; done
		tail -f $LOG
	fi
fi

exit 0
