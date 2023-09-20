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
	set DB_USER=sa
	set DB_PASSWORD=""
	set DB_DRIVER=org.hsqldb.jdbcDriver
	set DB_URL=hsqldb:file:%TOMCAT_ROOT%/webapps/ROOT/WEB-INF/db/simplicite;shutdown=true;sql.ignore_case=true
)
set JAVA_OPTS=%JAVA_OPTS% -Ddb.vendor=%DB_VENDOR% -Ddb.user=%DB_USER% -Ddb.password=%DB_PASSWORD% -Ddb.driver=%DB_DRIVER% -Ddb.url=%DB_URL%

if not exist %TOMCAT_ROOT%\work ( mkdir %TOMCAT_ROOT%\work )
if not exist %TOMCAT_ROOT%\temp ( mkdir %TOMCAT_ROOT%\temp )
if not exist %TOMCAT_ROOT%\logs ( mkdir %TOMCAT_ROOT%\logs )

cd %TOMCAT_ROOT%\bin
call .\catalina.bat run
exit
