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

JCCHOME=${JACOCO_HOME:-/usr/local/jacoco}
if [ -d $JCCHOME ]
then
	[ -d $JCCHOME/lib ] && JCCHOME=$JCCHOME/lib
	JCCDESTFILE=${JACOCO_DESTFILE:-${TOMCAT_ROOT}/webapps/jacoco/jacoco.exec}
	if [ -f ${JCCDESTFILE} ]
	then
		JCCREPORTDIR=${JACOCO_REPORTDIR:-${TOMCAT_ROOT}/webapps/jacoco}
		[ ! -d $JCCREPORTDIR ] && mkdir -p $JCCREPORTDIR
		#rm -fr $JCCREPORTDIR/*

		SRC=""
		CLS=""
		for MODULE in ${JACOCO_MODULES//,/ }
		do
			# Avoid including tests
			for PKG in commons objects extobjects workflows dispositions adapters
			do
				SRC="$SRC --sourcefiles ${TOMCAT_ROOT}/webapps/${TOMCAT_WEBAPP:-ROOT}/WEB-INF/src/com/simplicite/$PKG/$MODULE"
				CLS="$CLS --classfiles ${TOMCAT_ROOT}/webapps/${TOMCAT_WEBAPP:-ROOT}/WEB-INF/bin/com/simplicite/$PKG/$MODULE"
			done
		done

		java -jar ${JCCHOME}/jacococli.jar \
			report ${JCCDESTFILE} \
			--html ${JCCREPORTDIR} \
			$SRC \
			$CLS
	else
		echo "Warning: JaCoCo exec file does not exists"
		exit 3
	fi
else
	echo "Error: JaCoCo is not present"
	exit 2
fi

exit 0
