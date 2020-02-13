# Iteration 04: load balancing and session management

This multi-container liferay application starts a liferay cluster with load balancing and user session management, using docker swarm. We switch back to ES7

## Goals
* Use ES7
* Understand how docker swarm manages networking and load balancing between services
* Evaluate some mechanism to keep user session: sticky session vs tomcat session replication 

## Requirements 
* Gather information about how to
  * Make sticky session work in swarm mode for the liferay nodes. 
  * Replicate tomcat session
* Implement one of the mechanisms above
* Document how networking works in the chosen configuration  
* Re-enable ES7 without the need to restart the container

## Takeaways

## Not covered yet
* Database timezone
* Database character encoding
* Ensure character encoding and timezone are the same in DB and JVM
* Elastic search [advanced configuration](https://www.elastic.co/guide/en/elasticsearch/reference/7.5/docker.html)

# Previous iterations

## Iteration 03: clustering liferay
* Define replicas for the liferay service
* Do not replicate container configuration for each liferay node
* Allow replicas to form a liferay cluster (JDBC_ping)
* Run this in docker-compose and docker swarm
* Automate the operations to start/stop/scale the app, both for docker-compose and docker swarm

## Iteration 02: add elasticsearch 6
* Define a ES6 node and connect liferay to it

## Iteration 01: add elasticsearch 7
* Define an elasticsearch node, using most recent elasticsearch version for the latest available liferay DXP image
    * Consider specific settings to have reasonable defaults (memory, system limits)
* Connect liferay to the elasticsearch node
    * Provide default configuration
* Make **all data** to survive to container deletion
    * Use volume to mount default store file path (${liferay_home}/data/document_library)
    * Use volume to mount elasticsearch indices    
* Ensure elasticsearch is ready to work when Liferay connects to it

## Iteration 00: connect liferay and mysql containers
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
    