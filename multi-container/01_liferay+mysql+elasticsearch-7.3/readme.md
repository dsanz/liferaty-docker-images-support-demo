This multi-container application starts 3 containers using docker compose features.

## Goal
To connect Liferay to a predefined mysql database and a single elasticsearch, running in separate containers

## Takeaways
* To use DXP images, we have to provide the mysql driver jar URL. Maven forces the usage of https, so we need to configure the portal property
* To [use ES7](https://portal.liferay.dev/docs/7-2/deploy/-/knowledge_base/d/upgrading-to-elasticsearch-7), we need to 
  * Use DXP SP1 or CE GA2
  * Install the ES 7 connector (for CE or DXP)
  * Blacklist ES6 connector bundles
* ES7 needs some extra analyzers to work with ootb Liferay. These are not in the default image, one has to install them with a ES tool or provide them in the plugins directory 

## Requirements (iteration 01)
* Define an elasticsearch node, using most recent elasticsearch version for the latest available liferay DXP image
    * Consider specific settings to have reasonable defaults (memory, system limits)
* Connect liferay to the elasticsearch node
    * Provide default configuration
* Make **all data** to survive to container deletion
    * Use volume to mount default store file path (${liferay_home}/data/document_library)
    * Use volume to mount elasticsearch indices    
* Ensure elasticsearch is ready to work when Liferay connects to it

## Requirements (iteration 00)
* Do not create child images unless strictly needed: use env vars and mounts where possible
* Tell mysql to create the DB if it does not exist
    * Set `MYSQL_DATABASE` env var. That name is fixed and can not be changed
* Make DB to survive to container deletion
    * Use volume to mount /var/lib/mysql in the container, as explained in the [image documentation](https://hub.docker.com/_/mysql/)
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
* Elastic search [advanced configuration](https://www.elastic.co/guide/en/elasticsearch/reference/7.5/docker.html)