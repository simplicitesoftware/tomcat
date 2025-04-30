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
	echo "Usage $(basename $0) [<port, e.g. 3003>]" >&2
	exit -1
fi

[ "$JAVA_HOME" = "" ] && JAVA_HOME="/usr/lib/jvm/java"
if [ ! -d $JAVA_HOME ]
then
	echo "ERROR: JAVA_HOME = $JAVA_HOME is not correctly configured" >&2
	exit 1
fi
echo "Java home: $JAVA_HOME"
export PATH=$JAVA_HOME/bin:$PATH

[ "$TOMCAT_ROOT" = "" ] && TOMCAT_ROOT=$(dirname $0)
TOMCAT_ROOT=$(realpath $TOMCAT_ROOT)
echo "Tomcat root: $TOMCAT_ROOT"

LSP_PORT=${1:-3003}

LSP_DIR=$TOMCAT_ROOT/webapps/${TOMCAT_WEBAPP:-ROOT}/WEB-INF/lsp
echo "LSP dir: $LSP_DIR)"
if [ -d $LSP_DIR -a -f $LSP_DIR/simplicite-lsp.jar ]
then
	pushd $LSP_DIR > /dev/null
	java -server -Djava.awt.headless=true -Dfile.encoding=UTF-8 \
		--add-exports=jdk.compiler/com.sun.tools.javac.api=ALL-UNNAMED \
		--add-exports=jdk.compiler/com.sun.tools.javac.code=ALL-UNNAMED \
		--add-exports=jdk.compiler/com.sun.tools.javac.comp=ALL-UNNAMED \
		--add-exports=jdk.compiler/com.sun.tools.javac.main=ALL-UNNAMED \
		--add-exports=jdk.compiler/com.sun.tools.javac.tree=ALL-UNNAMED \
		--add-exports=jdk.compiler/com.sun.tools.javac.model=ALL-UNNAMED \
		--add-exports=jdk.compiler/com.sun.tools.javac.util=ALL-UNNAMED \
		--add-opens=jdk.compiler/com.sun.tools.javac.api=ALL-UNNAMED \
		-Duser.home=$LSP_DIR \
		-Dlsp.dir=$LSP_DIR \
		-Dlsp.port=${LSP_PORT} \
		-Dlsp.process=false \
		-Dtomcat.root=$TOMCAT_ROOT \
		-Dtomcat.webapp=${TOMCAT_WEBAPP:-ROOT} \
		-jar simplicite-lsp.jar > $TOMCAT_ROOT/logs/simplicite-lsp.log
	popd > /dev/null
else
	echo "LSP is not present, ignoring"
fi

exit 0
