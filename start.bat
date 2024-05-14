@echo off

chcp 65001

if not defined JAVA_HOME ( set JAVA_HOME=C:\Program Files\Java\jdk-17 )
set PATH=%JAVA_HOME%\bin;%PATH%

set TOMCAT_ROOT=%CD%
if not defined TOMCAT_ADMIN_PORT ( set TOMCAT_ADMIN_PORT=8005 )
if not defined TOMCAT_HTTP_PORT  ( set TOMCAT_HTTP_PORT=8080  )
if not defined TOMCAT_HTTPS_PORT ( set TOMCAT_HTTPS_PORT=8443 )
set JAVA_OPTS=%JAVA_OPTS% -server -Dfile.encoding=UTF-8 -Dgit.basedir=%TOMCAT_ROOT%\webapps\ROOT\WEB-INF\git -Dtomcat.adminport=%TOMCAT_ADMIN_PORT% -Dtomcat.httpport=%TOMCAT_HTTP_PORT% -Dtomcat.httpsport=%TOMCAT_HTTPS_PORT%

if not defined DB_VENDOR (
	set DB_VENDOR=hsqldb
	set DB_USER="sa"
	set DB_PASSWORD=""
	set DB_DRIVER="org.hsqldb.jdbcDriver"
	set DB_URL="hsqldb:file:%TOMCAT_ROOT%/webapps/ROOT/WEB-INF/db/simplicite;shutdown=true;sql.ignore_case=true"
)
if %DB_VENDOR%==mariadb set DB_VENDOR=mysql
if %DB_VENDOR%==pgsql set DB_VENDOR=postgresql
if %DB_VENDOR%==mssql set DB_VENDOR=sqlserver
if not defined DB_DRIVER (
	if %DB_VENDOR%==mysql set DB_DRIVER="com.mysql.cj.jdbc.Driver"
	if %DB_VENDOR%==postgresql set DB_DRIVER="org.postgresql.Driver"
	if %DB_VENDOR%==oracle set DB_DRIVER="oracle.jdbc.driver.OracleDriver"
	if %DB_VENDOR%==sqlserver set DB_DRIVER="com.microsoft.sqlserver.jdbc.SQLServerDriver"
)
if not defined DB_URL (
	if not defined DB_NAME set DB_NAME=simplicite
	if not defined DB_HOST set DB_HOST=127.0.0.1
	if not defined DB_SSL set DB_SSL=false
	if %DB_VENDOR%==mysql (
		if not defined DB_PORT set DB_PORT=3306
		set DB_URL="mysql://%DB_HOST%:%DB_PORT%/%DB_NAME%?autoReconnect=true&useSSL=%DB_SSL%&allowPublicKeyRetrieval=true&characterEncoding=utf8&characterResultSets=utf8%DB_OPTS%"
	)
	if %DB_VENDOR%==postgresql (
		if not defined DB_PORT set DB_PORT=5432
		set DB_URL="postgresql://%DB_HOST%:%DB_PORT%/%DB_NAME%?ssl=%DB_SSL%%DB_OPTS%"
	)
	if %DB_VENDOR%==oracle (
		if not defined DB_PORT set DB_PORT=1521
		set DB_URL="oracle:thin:@//%DB_HOST%:%DB_PORT%/%DB_NAME%%DB_OPTS%"
	)
	if %DB_VENDOR%==sqlserver (
		if not defined DB_PORT set DB_PORT=1433
		set DB_URL="sqlserver://%DB_HOST%:%DB_PORT%;databaseName=%DB_NAME%;encrypt=%DB_SSL%;trustServerCertificate=true%DB_OPTS%"
	)
)
if not defined DB_USER set DB_USER=simplicite
if not defined DB_PASSWORD set DB_PASSWORD=simplicite
set JAVA_OPTS=%JAVA_OPTS% -Ddb.vendor=%DB_VENDOR% -Ddb.user=%DB_USER% -Ddb.password=%DB_PASSWORD% -Ddb.driver=%DB_DRIVER% -Ddb.url=%DB_URL%

if not exist %TOMCAT_ROOT%\work ( mkdir %TOMCAT_ROOT%\work )
if not exist %TOMCAT_ROOT%\temp ( mkdir %TOMCAT_ROOT%\temp )
if not exist %TOMCAT_ROOT%\logs ( mkdir %TOMCAT_ROOT%\logs )

cd %TOMCAT_ROOT%\bin
call .\catalina.bat run
exit
