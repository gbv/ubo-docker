#!/usr/bin/bash
set -e

echo "UBO Starter Script"
sleep 5 # wait for database (TODO: replace with wait-for-it)
MCR_HOME=/root/.mycore/${APP_CONTEXT}/

function downloadDriver {
  FILENAME=$(basename $1)
  if [[ ! -f "${MCR_HOME}lib/$FILENAME" ]]
  then
    curl -o "${MCR_HOME}lib/$FILENAME" "$1"
  fi
  if [[ ! -f "/opt/ubo/target/${FILENAME}" ]]
  then
    cp "${MCR_HOME}lib/$FILENAME" "/opt/ubo/target/${FILENAME}"
  fi
}

function setUpMyCoRe {
    JAVA_OPTS="-DMCR.AppName=${APP_CONTEXT}" /opt/ubo/target/bin/ubo.sh create configuration directory

    sed -ri "s/(name=\"javax.persistence.jdbc.user\" value=\").*(\")/\1${JDBC_NAME}\2/" "${MCR_HOME}resources/META-INF/persistence.xml"
    sed -ri "s/(name=\"javax.persistence.jdbc.password\" value=\").*(\")/\1${JDBC_PASSWORD}\2/" "${MCR_HOME}resources/META-INF/persistence.xml"
    sed -ri "s/(name=\"javax.persistence.jdbc.driver\" value=\").*(\")/\1${JDBC_DRIVER}\2/" "${MCR_HOME}resources/META-INF/persistence.xml"
    sed -ri "s/(name=\"javax.persistence.jdbc.url\" value=\").*(\")/\1${JDBC_URL}\2/" "${MCR_HOME}resources/META-INF/persistence.xml"
    #sed -ri "s/(name=\"hibernate.hbm2ddl.auto\" value=\").*(\")/\1update\2/" "${MCR_HOME}resources/META-INF/persistence.xml"
    sed -ri "s/<mapping-file>META-INF\/mycore-viewer-mappings.xml<\/mapping-file>//" "${MCR_HOME}resources/META-INF/persistence.xml"
    sed -ri "s/#?(MCR\.Solr\.ServerURL=).+/\1${SOLR_URL}/" "${MCR_HOME}mycore.properties"
    sed -ri "s/#?(MCR\.Solr\.ServerURL=).+/\1${SOLR_URL}/" "${MCR_HOME}mycore.properties"
    sed -ri "s/#?(MCR\.Solr\.Core\.main\.Name=).+/\1${SOLR_CORE}/" "${MCR_HOME}mycore.properties"
    sed -ri "s/#?(MCR\.Solr\.Core\.main\.Name=).+/\1${SOLR_CORE}/" "${MCR_HOME}mycore.properties"
    mkdir -p "${MCR_HOME}lib"

    case $JDBC_DRIVER in
      org.postgresql.Driver) downloadDriver "https://jdbc.postgresql.org/download/postgresql-42.2.9.jar";;
      org.mariadb.jdbc.Driver) downloadDriver "https://repo.maven.apache.org/maven2/org/mariadb/jdbc/mariadb-java-client/2.5.4/mariadb-java-client-2.5.4.jar";;
      org.hsqldb.jdbcDriver) downloadDriver "https://repo.maven.apache.org/maven2/org/hsqldb/hsqldb/2.5.0/hsqldb-2.5.0.jar";;
      org.h2.Driver) downloadDriver "https://repo.maven.apache.org/maven2/com/h2database/h2/1.4.200/h2-1.4.200.jar";;
      com.mysql.jdbc.Driver) downloadDriver "https://repo.maven.apache.org/maven2/mysql/mysql-connector-java/8.0.19/mysql-connector-java-8.0.19.jar";;
    esac

    JAVA_OPTS="-DMCR.AppName=${APP_CONTEXT}" /opt/ubo/target/bin/ubo.sh init superuser
    JAVA_OPTS="-DMCR.AppName=${APP_CONTEXT}" /opt/ubo/target/bin/ubo.sh update all classifications from directory /opt/ubo/src/main/setup/classifications
    JAVA_OPTS="-DMCR.AppName=${APP_CONTEXT}" /opt/ubo/target/bin/ubo.sh update permission create-mods for id POOLPRIVILEGE with rulefile src/main/resources/acl-rule-always-allowed.xml described by always allowed
    JAVA_OPTS="-DMCR.AppName=${APP_CONTEXT}" /opt/ubo/target/bin/ubo.sh update permission read for id default with rulefile /opt/ubo/src/main/resources/acl-rule-always-allowed.xml described by always allowed
    JAVA_OPTS="-DMCR.AppName=${APP_CONTEXT}" /opt/ubo/target/bin/ubo.sh update permission read for id restapi:/ with rulefile /opt/ubo/src/main/resources/acl-rule-always-allowed.xml described by always allowed
    JAVA_OPTS="-DMCR.AppName=${APP_CONTEXT}" /opt/ubo/target/bin/ubo.sh update permission read for id restapi:/ with rulefile /opt/ubo/src/main/resources/acl-rule-always-allowed.xml described by always allowed
    JAVA_OPTS="-DMCR.AppName=${APP_CONTEXT}" /opt/ubo/target/bin/ubo.sh reload solr configuration main in core main
}

[ "$(ls -A "$MCR_HOME")" ] && echo "MyCoRe-Home is not empty" || setUpMyCoRe

rm -rf /usr/local/tomcat/webapps/*
cp /opt/ubo/target/ubo-*.war "/usr/local/tomcat/webapps/${APP_CONTEXT}.war"
catalina.sh run
