Tomcat for Simplicit&eacute;&reg; sandboxes
===========================================

This repository contains an optimized and customized version of Apache Tomcat&reg; suitable for Simplicitt&eacute;&reg; sandboxes

The default webapps have been removed, other changes are in the `conf` folder and 3 additional JARs have been included in the `lib` folder:

- `simplicite-valves.jar` contains the optional valves that you can use along with Simplicit&eacute;
- `mysql-connector-java-x.y.z-bin` the MySQL/MariaDB JDBC driver
- `postgresql-x.y.z` the PostgreSQL JDBC driver

The `conf/server.xml` file uses JVM properties that you must define prior to launching Tomcat, e.g.:

	export JAVA_OPTS="-Dtomcat.adminport=8005 -Dtomcat.httpport=8080 -Dtomcat.httpsport=8443 $JAVA_OPTS"
