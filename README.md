# ubo-docker
This is a dockerfile for the project https://github.com/mycore-org/ubo

## Environment Variables
- JDBC_NAME - The Username of the Database
- JDBC_PASSWORD - The Password of the User
- JDBC_DRIVER - The diver to use for JDBC
- JDBC_URL - The URL to use for JDBC
- APP_CONTEXT - The context of the webapp
- SOLR_URL - The url to the solr server
- SOLR_CORE - The name of the main solr core
- SOLR_CLASSIFICATION_CORE - The name of the main solr core

## Mount points
/mcr/home/ - the configuration dir
/mcr/data/ - the data dir (will be separated in mycore.properties by docker)

## build and deploy
```
sudo docker build --pull --no-cache . -t vzgreposis/ubo:master
sudo docker push  vzgreposis/ubo:master
```
