@echo off

rem set JAVA_HOME=<path to your JDK home>
rem set PATH=%JAVA_HOME%\bin;%PATH%

set TOMCAT_ROOT=%CD%
set TOMCAT_ADMIN_PORT=8005
set TOMCAT_HTTP_PORT=8080
set TOMCAT_HTTPS_PORT=8443

set JAVA_OPTS=%JAVA_OPTS% -server -Dfile.encoding=UTF-8 -Dgit.basedir=%TOMCAT_ROOT%\webapps\ROOT\WEB-INF\git -Dtomcat.adminport=%TOMCAT_ADMIN_PORT% -Dtomcat.httpport=%TOMCAT_HTTP_PORT% -Dtomcat.httpsport=%TOMCAT_HTTPS_PORT%
if not exist %TOMCAT_ROOT%\work mkdir %TOMCAT_ROOT%\work
if not exist %TOMCAT_ROOT%\temp mkdir %TOMCAT_ROOT%\temp
if not exist %TOMCAT_ROOT%\logs mkdir %TOMCAT_ROOT%\logs
cd %TOMCAT_ROOT%\bin
.\startup.bat
exit