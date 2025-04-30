#!/bin/bash
# =========================================================================== #
#   ___ _            _ _    _ _         ___       __ _                        #
#  / __(_)_ __  _ __| (_)__(_) |_ ___  / __| ___ / _| |___ __ ____ _ _ _ ___  #
#  \__ \ | '  \| '_ \ | / _| |  _/ -_) \__ \/ _ \  _|  _\ V  V / _` | '_/ -_) #
#  |___/_|_|_|_| .__/_|_\__|_|\__\___| |___/\___/_|  \__|\_/\_/\__,_|_| \___| #
#              |_|                                                            #
# =========================================================================== #

if [ "$1" = "--help" ]
then
	echo "Usage $(basename $0)" >&2
	exit -1
fi

[ "$JAVA_HOME" = "" ] && JAVA_HOME="/usr/lib/jvm/java"
if [ ! -d $JAVA_HOME ]
then
	echo "JAVA_HOME = $JAVA_HOME is not correctly configured" >&2
	exit 1
fi
export PATH=$JAVA_HOME/bin:$PATH

[ "$TOMCAT_ROOT" = "" ] && TOMCAT_ROOT=$(dirname $0)
TOMCAT_ROOT=$(realpath $TOMCAT_ROOT)
echo "Tomcat root: $TOMCAT_ROOT"

export JAVA_OPTS="$JAVA_OPTS -server -Djava.awt.headless=true -Dfile.encoding=UTF-8 -Dtomcat.adminport=${TOMCAT_ADMIN_PORT:-8005}"

cd $TOMCAT_ROOT/bin
./shutdown.sh
cd ..

if [ "$1" = "-t" -o "$1" = "--tail" ]
then
	LOG=logs/catalina.out
	while [ ! -f $LOG ]; do echo -n "."; sleep 1; done
	tail -f $LOG
fi

exit 0