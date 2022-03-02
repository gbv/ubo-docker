#!/usr/bin/bash
set -e
set -o xtrace
echo "UBO Starter Script"
sleep 5 # wait for database (TODO: replace with wait-for-it)

MCR_SAVE_DIR="${MCR_CONFIG_DIR}save/"

MCR_CONFIG_DIR_ESCAPED=$(echo "$MCR_CONFIG_DIR" | sed 's/\//\\\//g')
MCR_DATA_DIR_ESCAPED=$(echo "$MCR_DATA_DIR" | sed 's/\//\\\//g')
MCR_SAVE_DIR_ESCAPED=$(echo "$MCR_SAVE_DIR" | sed 's/\//\\\//g')

SOLR_URL_ESCAPED=$(echo "$SOLR_URL" | sed 's/\//\\\//g')
SOLR_CORE_ESCAPED=$(echo "$SOLR_CORE" | sed 's/\//\\\//g')
SOLR_CLASSIFICATION_CORE_ESCAPED=$(echo "$SOLR_CLASSIFICATION_CORE" | sed 's/\//\\\//g')

JDBC_NAME_ESCAPED=$(echo "$JDBC_NAME" | sed 's/\//\\\//g')
JDBC_PASSWORD_ESCAPED=$(echo "$JDBC_PASSWORD" | sed 's/\//\\\//g')
JDBC_DRIVER_ESCAPED=$(echo "$JDBC_DRIVER" | sed 's/\//\\\//g')
JDBC_URL_ESCAPED=$(echo "$JDBC_URL" | sed 's/\//\\\//g')
HIBERNATE_SCHEMA_ESCAPED=$(echo "$JDBC_URL" | sed 's/\//\\\//g')

MYCORE_PROPERTIES="${MCR_CONFIG_DIR}mycore.properties"
PERSISTENCE_XML="${MCR_CONFIG_DIR}resources/META-INF/persistence.xml"

function downloadDriver {
  FILENAME=$(basename $1)
  if [[ ! -f "${MCR_CONFIG_DIR}lib/$FILENAME" ]]
  then
    curl -o "${MCR_CONFIG_DIR}lib/$FILENAME" "$1"
  fi
}

function setDockerValues() {
    echo "Set Docker Values to Config!"
    if [ -n "${SOLR_URL}" ]; then
      sed -ri "s/#?(MCR\.Solr\.ServerURL=).+/\1${SOLR_URL_ESCAPED}/" "${MYCORE_PROPERTIES}";
    fi

    if [ -n "${SOLR_CORE}" ]; then
      sed -ri "s/#?(MCR\.Solr\.Core\.main\.Name=).+/\1${SOLR_CORE_ESCAPED}/" "${MYCORE_PROPERTIES}";
    fi

    if [ -n "${SOLR_CLASSIFICATION_CORE}" ]; then
      sed -ri "s/#?(MCR\.Solr\.Core\.classification\.Name=).+/\1${SOLR_CLASSIFICATION_CORE_ESCAPED}/" "${MYCORE_PROPERTIES}"
    fi

    if [ -n "${JDBC_NAME}" ]; then
      sed -ri "s/(name=\"javax.persistence.jdbc.user\" value=\").*(\")/\1${JDBC_NAME_ESCAPED}\2/" "${PERSISTENCE_XML}"
    fi

    if [ -n "${JDBC_PASSWORD}" ]; then
      sed -ri "s/(name=\"javax.persistence.jdbc.password\" value=\").*(\")/\1${JDBC_PASSWORD_ESCAPED}\2/" "${PERSISTENCE_XML}"
    fi

    if [ -n "${JDBC_DRIVER}" ]; then
      sed -ri "s/(name=\"javax.persistence.jdbc.driver\" value=\").*(\")/\1${JDBC_DRIVER_ESCAPED}\2/" "${PERSISTENCE_XML}"
    fi

    if [ -n "${JDBC_URL}" ]; then
      sed -ri "s/(name=\"javax.persistence.jdbc.url\" value=\").*(\")/\1${JDBC_URL_ESCAPED}\2/" "${PERSISTENCE_XML}"
    fi

    if [ -n "${SOLR_CLASSIFICATION_CORE}" ]; then
      sed -ri "s/(name=\"hibernate.default_schema\" value=\").*(\")/\1${HIBERNATE_SCHEMA_ESCAPED}\2/" "${PERSISTENCE_XML}"
    fi

    sed -ri "s/(name=\"hibernate.hbm2ddl.auto\" value=\").*(\")/\1update\2/" "${PERSISTENCE_XML}"

    if  grep -q "MCR.datadir=" "${MYCORE_PROPERTIES}" ; then
          sed -ri "s/#?(MCR\.datadir=).+/\1${MCR_DATA_DIR_ESCAPED}/" "${MYCORE_PROPERTIES}"
    else
          echo "MCR.datadir=${MCR_DATA_DIR}">>"${MYCORE_PROPERTIES}"
    fi

    if  grep -q "MCR.Save.FileSystem=" "${MYCORE_PROPERTIES}" ; then
          sed -ri "s/#?(MCR\.Save\.FileSystem=).+/\1${MCR_SAVE_DIR_ESCAPED}/" "${MYCORE_PROPERTIES}"
    else
          echo "MCR.Save.FileSystem=${MCR_SAVE_DIR}">>"${MYCORE_PROPERTIES}"
    fi

    case $JDBC_DRIVER in
      org.postgresql.Driver) downloadDriver "https://jdbc.postgresql.org/download/postgresql-42.2.9.jar";;
      org.mariadb.jdbc.Driver) downloadDriver "https://repo.maven.apache.org/maven2/org/mariadb/jdbc/mariadb-java-client/2.5.4/mariadb-java-client-2.5.4.jar";;
      org.hsqldb.jdbcDriver) downloadDriver "https://repo.maven.apache.org/maven2/org/hsqldb/hsqldb/2.5.0/hsqldb-2.5.0.jar";;
      org.h2.Driver) downloadDriver "https://repo.maven.apache.org/maven2/com/h2database/h2/1.4.200/h2-1.4.200.jar";;
      com.mysql.jdbc.Driver) downloadDriver "https://repo.maven.apache.org/maven2/mysql/mysql-connector-java/8.0.19/mysql-connector-java-8.0.19.jar";;
    esac

    mkdir -p "${MCR_CONFIG_DIR}lib"

    downloadDriver https://repo1.maven.org/maven2/org/hibernate/hibernate-c3p0/5.3.9.Final/hibernate-c3p0-5.3.9.Final.jar
    downloadDriver https://repo1.maven.org/maven2/com/mchange/c3p0/0.9.5.2/c3p0-0.9.5.2.jar
    downloadDriver https://repo1.maven.org/maven2/com/mchange/mchange-commons-java/0.2.15/mchange-commons-java-0.2.15.jar

    sed -ri "s/<mapping-file>META-INF\/mycore-viewer-mappings.xml<\/mapping-file>//" "${PERSISTENCE_XML}"
    sed -ri "s/<mapping-file>META-INF\/mycore-iview2-mappings.xml<\/mapping-file>//" "${PERSISTENCE_XML}"
    sed -ri "s/<mapping-file>META-INF\/mycore-ifs-mappings.xml<\/mapping-file>//" "${PERSISTENCE_XML}"


    if [ -f "${MCR_CONFIG_DIR}jwt.secret" ]; then
      echo "jwt.secret already exists."
    else
      echo "jwt.secret does not exists, create it.."
      openssl rand -out "${MCR_CONFIG_DIR}jwt.secret" 4096
    fi;
}

function setUpMyCoRe {
    /opt/ubo/ubo-cli/target/bin/ubo.sh create configuration directory
    setDockerValues
    sed -ri "s/(<\/properties>)/<property name=\"hibernate\.connection\.provider_class\" value=\"org\.hibernate\.connection\.C3P0ConnectionProvider\" \/>\n<property name=\"hibernate\.c3p0\.min_size\" value=\"2\" \/>\n<property name=\"hibernate\.c3p0\.max_size\" value=\"50\" \/>\n<property name=\"hibernate\.c3p0\.acquire_increment\" value=\"2\" \/>\n<property name=\"hibernate\.c3p0\.max_statements\" value=\"30\" \/>\n<property name=\"hibernate\.c3p0\.timeout\" value=\"1800\" \/>\n\1/" "${PERSISTENCE_XML}"
    /opt/ubo/ubo-cli/target/bin/ubo.sh init superuser
    /opt/ubo/ubo-cli/target/bin/ubo.sh update all classifications from directory /opt/ubo/ubo-cli/src/main/setup/classifications
    /opt/ubo/ubo-cli/target/bin/ubo.sh update permission update permission create-mods for id POOLPRIVILEGE with rulefile /opt/ubo/ubo-cli/src/main/setup/acl/acl-rule-always-allowed.xml described by always allowed
    /opt/ubo/ubo-cli/target/bin/ubo.sh update permission update permission create-users for id POOLPRIVILEGE with rulefile /opt/ubo/ubo-cli/src/main/setup/acl/acl-rule-administrators-only.xml described by administrators only
    /opt/ubo/ubo-cli/target/bin/ubo.sh update permission update permission administrate-users for id POOLPRIVILEGE with rulefile /opt/ubo/ubo-cli/src/main/setup/acl/acl-rule-administrators-only.xml described by administrators only
    /opt/ubo/ubo-cli/target/bin/ubo.sh update permission update permission read for id default with rulefile /opt/ubo/ubo-cli/src/main/setup/acl/acl-rule-always-allowed.xml described by always allowed
    /opt/ubo/ubo-cli/target/bin/ubo.sh update permission update permission writedb for id default with rulefile /opt/ubo/ubo-cli/src/main/setup/acl/acl-rule-administrators-only.xml described by administrators only
    /opt/ubo/ubo-cli/target/bin/ubo.sh update permission update permission read for id restapi:/ with rulefile /opt/ubo/ubo-cli/src/main/setup/acl/acl-rule-always-allowed.xml described by always allowed
    /opt/ubo/ubo-cli/target/bin/ubo.sh update permission deletedb for id default with rulefile /opt/ubo/ubo-cli/src/main/setup/acl/acl-rule-administrators-only.xml described by administrators only
    /opt/ubo/ubo-cli/target/bin/ubo.sh reload solr configuration main in core main
}

sed -ri "s/(-DMCR.AppName=).+( \\\\)/\-DMCR.ConfigDir=${MCR_CONFIG_DIR_ESCAPED}\2/" /opt/ubo/ubo-cli/target/bin/ubo.sh
sed -ri "s/(-DMCR.ConfigDir=).+( \\\\)/\-DMCR.ConfigDir=${MCR_CONFIG_DIR_ESCAPED}\2/" /opt/ubo/ubo-cli/target/bin/ubo.sh

if [ -f "$MYCORE_PROPERTIES" ]; then
  echo "Exists set docker values!"
  setDockerValues
else
  echo "Set up mycore home!"
  setUpMyCoRe
fi

rm -rf /usr/local/tomcat/webapps/*
cp /opt/ubo/ubo-webapp/target/ubo-*.war "/usr/local/tomcat/webapps/${APP_CONTEXT}.war"
export JAVA_OPTS="-DMCR.ConfigDir=${MCR_CONFIG_DIR} -Xmx${XMX} -Xms${XMS} -XX:+CrashOnOutOfMemoryError"
catalina.sh run
