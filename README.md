![Simplicit&eacute; Software](https://platform.simplicite.io/logos/logo250-grey.png)
* * *

Tomcat for Simplicit&eacute;&reg;
=================================

This repository contains an optimized and customized version of Apache Tomcat&reg; suitable for Simplicit&eacute;&reg; instances.

The default webapps have been removed, other changes are in the `conf` folder and 3 additional JARs have been included in the `lib` folder:

- `mysql-connector-java-x.y.z-bin` the MySQL/MariaDB JDBC driver
- `postgresql-x.y.z` the PostgreSQL JDBC driver

Usage
-----

Before launching Tomcat:

* make sure to create the `temp`, `logs` and `webapps`folders (and deploy web applications, at least a `ROOT` web application, in this last folder)
  NB: these 3 folders are excluded of Git repository by entries in the `.gitignore` file
* define the **JVM properties** the `conf/server.xml` file is expecting by setting the `JAVA_OPTS` environment variable:

	export JAVA_OPTS="-Dtomcat.adminport=8005 -Dtomcat.httpport=8080 -Dtomcat.httpsport=8443 -Dtomcat.ajpport=8009 $JAVA_OPTS"

Upgrade
-------

To upgrade:

* Stop Tomcat
* Pull/checkout changes on the Git repository
* Restart Tomcat

Sample init script
------------------

To automate the Tomcat start/stop create a `/etc/init.d/tomcat` init script with:

```sh
#!/bin/sh
#
# Tomcat Control Script
#
# chkconfig: 2345 55 25
#
# description:  Start up the tomcat engine.

# Source function library.
. /etc/init.d/functions

RETVAL=$?

JAVA_HOME=/usr/lib/jvm/java-11
export JAVA_HOME

PATH=$JAVA_HOME/bin:$PATH
export PATH

TOMCAT_USER="simplicite"
TOMCAT_HOME="/home/$TOMCAT_USER/tomcat"

# JVM options
JAVA_OPTS="-server -Dfile.encoding=UTF-8"

# Server
JAVA_OPTS="$JAVA_OPTS -Dserver.vendor=tomcat -Dserver.version=10"

# Small
#JAVA_OPTS="$JAVA_OPTS -Xms256m -Xmx512m"
# Medium
JAVA_OPTS="$JAVA_OPTS -Xms512m -Xmx1024m"
# Large
#JAVA_OPTS="$JAVA_OPTS -Xms1024m -Xmx2048m"

# Ports
JAVA_OPTS=""$JAVA_OPTS -Dtomcat.adminport=8005 -Dtomcat.httpport=8080 -Dtomcat.httpsport=8443" -Dtomcat.ajpport=8009"

# Git repository
JAVA_OPTS="$JAVA_OPTS -Dgit.basedir=/home/$TOMCAT_USER/git"

export JAVA_OPTS

CATALINA_PID=$TOMCAT_HOME/catalina.pid
export CATALINA_PID

case "$1" in
start)
    echo "Starting tomcat engine"
    cd $TOMCAT_HOME/bin
    /bin/su $TOMCAT_USER -c "/bin/sh ./startup.sh"
    ;;
stop)
    echo "Stopping tomcat engine"
    cd $TOMCAT_HOME/bin
    /bin/su $TOMCAT_USER -c "/bin/sh ./shutdown.sh"
    cd ..
    rm -fr conf/Catalina work/Catalina $CATALINA_PID
    ;;
*)
    echo "Usage: $0 {start|stop}"
    exit 1
    ;;
esac

exit $RETVAL
```

And enable this init script by:

	chkconfig tomcat on
