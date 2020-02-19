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
* JDBC_PING does not like old data. So, to start a fresh instance, it's better to remove the old mysql volume before starting the services. Otherwise, jgroups reports timeouts which make the container to become unhealthy and then stopped
* [Traefik](https://docs.traefik.io/) is a docker friendly _edge router_ which can be easily configured from a compose file. We'll try this option in this iteration.

### JDBC_PING
If containers are started and stopped, membership stored in the DB will still be used to set the initial view. This causes problems when the whole stack is stopped, then restarted.
The problem is that jgrups sets connection timeouts which end up expiring when jgroups decides that current view has to be discarded as nobody responds.

As a result, portal takes too long to start, making healthchecks to fail. This makes swarm to kill the container and restart it.

To solve this, each time mysql container is restarted, we remove the data from JGROUPSPING table in the assumption that DB server will be stopped/restarted along with the liferay ones.
This is a compromise solution that may be removed later.

### Traefik configuration
Traefik allows some really useful things:
 * To start with a minimal configuration, then enhance it
 * Configure it via docker-compose labels
 * Auto-update status from docker runtime 
These are compelling advantages to use traefik as load balancer for a simple cluster configuration.

__Note__: liferay service take some time to be marked as _healthy_. As a result, traefik will not show the associated services and routing information from the beginning. Information is ready once docker reports liferay service availability 

## Not covered yet
* Database timezone
* Database character encoding
* Ensure character encoding and timezone are the same in DB and JVM
* Elastic search [advanced configuration](https://www.elastic.co/guide/en/elasticsearch/reference/7.5/docker.html)
* Ordered container shutdown, to avoid premature service unavailability

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
    