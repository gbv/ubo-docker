# Bind paths /root/.mycore/ubo/
FROM alpine/git as git
ARG UBO_BRANCH=master
RUN mkdir /opt/ubo
WORKDIR /opt/
ADD https://api.github.com/repos/MyCoRe-Org/ubo/git/refs/heads/$UBO_BRANCH ubo-version.json
RUN git --version && \
    git clone https://github.com/MyCoRe-Org/ubo.git
WORKDIR /opt/ubo
RUN git checkout ${UBO_BRANCH}

FROM maven:3-jdk-11 as maven
RUN groupadd maven && \
    useradd -m -g maven maven
USER maven
COPY --from=git --chown=maven:maven /opt/ubo/ /opt/ubo
WORKDIR /opt/ubo
RUN mvn --version && \
    mvn clean install -Djetty -DskipTests && \
    rm -rf ~/.m2

FROM tomcat:9.0.35-jdk11
EXPOSE 8080
EXPOSE 8009
USER root
WORKDIR /usr/local/tomcat/
ARG PACKET_SIZE="65536"
ENV JAVA_OPTS="-Xmx1g -Xms1g"
ENV APP_CONTEXT="ubo"
COPY docker-entrypoint.sh /usr/local/bin/ubo.sh
RUN ["chmod", "+x", "/usr/local/bin/ubo.sh"]
RUN rm -rf /usr/local/tomcat/webapps/*
RUN sed -ri "s/<\/Service>/<Connector protocol=\"AJP\/1.3\" packetSize=\"$PACKET_SIZE\" tomcatAuthentication=\"false\" scheme=\"https\" secretRequired=\"false\" allowedRequestAttributesPattern=\".*\" encodedSolidusHandling=\"decode\" address=\"0.0.0.0\" port=\"8009\" redirectPort=\"8443\" \/>&/g" /usr/local/tomcat/conf/server.xml
COPY --from=maven --chown=root:root /opt/ubo/ /opt/ubo/
CMD ["bash", "/usr/local/bin/ubo.sh"]
