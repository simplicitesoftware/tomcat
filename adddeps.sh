#!/bin/bash

if [ "$JAVA_HOME" = "" ]
then
	echo "JAVA_HOME is not set" >&2
	exit 1
fi
export PATH=$JAVA_HOME/bin:$PATH

[ "$TOMCAT_ROOT" = "" ] && TOMCAT_ROOT=`dirname $0`
TOMCAT_ROOT=`realpath $TOMCAT_ROOT`
echo "Tomcat root: $TOMCAT_ROOT"

if [ "$MAVEN_HOME" = "" ]
then
	echo "MAVEN_HOME is not set" >&2
	exit 1
fi

if [ "$1" = "" -o "$1" = "--help" ]
then
	echo "Usage `basename $0` [--force] <list of groupId:artifactId:version>" >&2
	exit 1
fi

FORCE=0
if [ "$1" = "--force" ]
then
	FORCE=1
	shift
fi

pushd `dirname $0` > /dev/null
DIR=`pwd`
popd > /dev/null
TMP="/tmp/`basename $0 .sh`-$$"

LIB="$TOMCAT_ROOT/webapps/${TOMCAT_WEBAPP:-ROOT}/WEB-INF/lib"
if [ ! -w $LIB ]
then
	echo "Target lib directory ($LIB) does not exists or is not writeable" >&2
	exit 2
fi
GLB="$TOMCAT_ROOT/webapps/${TOMCAT_WEBAPP:-ROOT}/WEB-INF/classes/com/simplicite/globals.properties"

REG="$HOME/.m2"

trap "rm -fr $REG $TMP" EXIT

mkdir $TMP
pushd $TMP > /dev/null

echo "Generating pom.xml..."

cat << EOF > pom.xml
<project xmlns="http://maven.apache.org/POM/4.0.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
  <modelVersion>4.0.0</modelVersion>
  <groupId>com.simplicite</groupId>
  <artifactId>tmp</artifactId>
  <version>0.0.0</version>
  <name>Temporary</name>
  <dependencies>
EOF

PROPS=""
N=0
for DEP in $*
do
	GROUP=`echo $DEP | cut -d : -f 1`
	ARTIFACT=`echo $DEP | cut -d : -f 2`
	VERSION=`echo $DEP | cut -d : -f 3`

	if [ ! -z "$GROUP" -a ! -z "$ARTIFACT" -a ! -z "$VERSION" ]
	then
		cat << EOF >> pom.xml
    <dependency>
      <groupId>$GROUP</groupId>
      <artifactId>$ARTIFACT</artifactId>
      <version>$VERSION</version>
    </dependency>
EOF
		PROPS="$PROPS,$GROUP\\\\:$ARTIFACT\\\\:$VERSION"
		N=`expr $N + 1`
	else
		echo -e "\e[31mERROR: Ignored malformed dependency: $DEP\e[0m" >&2
	fi
done

cat << EOF >> pom.xml
  </dependencies>
</project>
EOF

if [ $N -eq 0 ]
then
	echo -e "\e[31mERROR: No dependency to add: $DEP\e[0m" >&2
	exit 3
fi

echo "Done"

echo "Resolution of dependencies..."
$MAVEN_HOME/bin/mvn -q -U dependency:copy-dependencies
RES=$?
[ $RES -ne 0 ] && exit 4
echo "Done"

TRG="target/dependency"

echo "Copying dependencies..."
for FILE in `ls -1 $TRG | sort -r`
do
	if [ -f $LIB/$FILE ]
	then
		echo -e "\e[33m- $FILE already exists, ignored\e[0m"
	else
		P=`echo $FILE | sed -r 's/(.*)-[0-9]+(\..+)*.jar$/\1/'`
		F=`ls $LIB/$P-*.jar 2> /dev/null | head -1`
		if [ "$F" != "" ]
		then
			if [ $FORCE -eq 0 ]
			then
				echo -e "\e[33m- Another version of $FILE already exists (`basename $F`), ignored\e[0m"
			else
				echo -e "\e[31m- Another version of $FILE already exists (`basename $F`), copied but \e[1mZZZZZ THIS MAY RESULT IN UNEXPECTED BEHAVIOR ZZZZZ\e[0m"
				cp $TRG/$FILE $LIB
			fi
		else
			echo -e "\e[32m- $FILE copied\e[0m"
			cp $TRG/$FILE $LIB
		fi
	fi
done
sed -i "/platform.devdependencies=/s/$/$PROPS/" $GLB
echo "Done"

popd > /dev/null

exit 0
