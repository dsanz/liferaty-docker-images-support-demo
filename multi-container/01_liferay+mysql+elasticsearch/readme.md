The simplest multi-container application starts 3 containers using basic docker compose features.

## Goal
To connect Liferay to a predefined mysql database and a single elasticsearch, running in separate containers

## Requirements
* Do not create child images unless strictly needed: use env vars and mounts where possible
* Define an elasticsearch cluster, using most recent elasticsearch version for the latest available liferay DXP image
* Connect liferay to the elasticsearch node
* Tell mysql to create the DB if it does not exist
    * Set `MYSQL_DATABASE` env var. That name is fixed and can not be changed
* Make **all data** to survive to container deletion
    * Use volume to mount /var/lib/mysql in the container, as explained in the [image documentation](https://hub.docker.com/_/mysql/)
    * Use vulime to mount default store file path (${liferay_home}/data/document_library)
* Make liferay aware of where database is
    * Use env vars to tell mysql the DB name and credentials to use
    * Use env vars to tell liferay about the DB connection properties
    * Have .env file to share variable values across both containers 
* Ensure mysql is ready to work when Liferay connects to it
    * Provide `wait-for-mysql.sh` custom script to the liferay container that waits for mysql service to become ready
    * Script calls a local copy of [wait-for-it](https://github.com/vishnubob/wait-for-it)
    
## Not covered yet
* Database timezone
* Database character encoding
* Ensure character encoding and timezone are the same in DB and JVM
* Elastic search plugins
* Elastic search [advanced configuration](https://www.elastic.co/guide/en/elasticsearch/reference/7.5/docker.html)