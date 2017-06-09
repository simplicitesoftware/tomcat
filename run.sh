#!/bin/bash

#export JAVA_HOME=<path to your JDK home>
#export PATH=$JAVA_HOME/bin:$PATH

export TOMCAT_ROOT=`dirname $0`
export TOMCAT_ADMIN_PORT=8005
export TOMCAT_HTTP_PORT=8080
export TOMCAT_HTTPS_PORT=8443

export JAVA_OPTS="$JAVA_OPTS -server -Dfile.encoding=UTF-8 -Dgit.basedir=$TOMCAT_ROOT/webapps/ROOT/WEB-INF/git -Dtomcat.adminport=$TOMCAT_ADMIN_PORT -Dtomcat.httpport=$TOMCAT_HTTP_PORT -Dtomcat.httpsport=$TOMCAT_HTTPS_PORT"
[ ! -d $TOMCAT_ROOT/work ] && mkdir $TOMCAT_ROOT/work
[ ! -d $TOMCAT_ROOT/temp ] && mkdir $TOMCAT_ROOT/temp
[ ! -d $TOMCAT_ROOT/logs ] && mkdir $TOMCAT_ROOT/logs
cd $TOMCAT_ROOT/bin
./startup.sh
