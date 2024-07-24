#!/bin/bash

if [ "$JAVA_HOME" = "" ]
then
	echo "JAVA_HOME is not set" >&2
	exit 1
fi
export PATH=$JAVA_HOME/bin:$PATH

[ "$TOMCAT_ROOT" = "" ] && TOMCAT_ROOT=$(dirname $0)
TOMCAT_ROOT=$(realpath $TOMCAT_ROOT)
echo "Tomcat root: $TOMCAT_ROOT"

if [ "$JACOCO_MODULES" = "" ]
then
	echo "No JaCoCo module(s) configured" >&2
	exit 1
fi

JCCHOME=${JACOCO_HOME:-/usr/local/jacoco}
if [ -d $JCCHOME ]
then
	[ -d $JCCHOME/lib ] && JCCHOME=$JCCHOME/lib
	JCCDESTFILE=${JACOCO_DESTFILE:-${TOMCAT_ROOT}/webapps/jacoco/jacoco.exec}
	if [ -f ${JCCDESTFILE} ]
	then
		JCCREPORTDIR=${JACOCO_REPORTDIR:-${TOMCAT_ROOT}/webapps/jacoco/report}
		rm -fr $JCCREPORTDIR
		mkdir -p $JCCREPORTDIR
		java -jar ${JCCHOME}/jacococli.jar \
			report ${JCCDESTFILE} \
			--html ${JCCREPORTDIR} \
			--sourcefiles ${TOMCAT_ROOT}/webapps/${TOMCAT_WEBAPP:-ROOT}/WEB-INF/src \
			--classfiles ${TOMCAT_ROOT}/webapps/${TOMCAT_WEBAPP:-ROOT}/WEB-INF/bin
	else
		echo "Warning: JaCoCo exec file does not (yet) exists"
		exit 3
	fi
else
	echo "Erro: JaCoCo is not present"
	exit 2
fi

exit 0
