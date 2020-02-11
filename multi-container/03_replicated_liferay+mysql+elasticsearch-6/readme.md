This multi-container liferay application starts many containers. It allows to set up a basic liferay cluser.

## Goal
* Determine if it's possible to have _replicas_ of the liferay container to form a cluster or we have to define each cluster node as a _separate service_
* Become knowledgeable about how to specify and run service replicas in docker, and  how it affects container definition and portal configuration

## Takeaways
To form a Liferay cluster in the docker way, we need several _services_ running the liferay container to communicate each other. Ideally, the liferay service should be defined once, then _scaled_. 
 
 A less ideal solution would be to define a service per cluster node. This approach is sub-optimal as it sets a fixed number of nodes and prevents leveraging one of the most salient features available in containerized apps: service scaling. 

### Service scaling
Scaling is about running the **same** service in several separate containers, according to the desired service state. A single definition for liferay service has many advantages:
* Lets the orchestrator (e.g. [swarm](https://docs.docker.com/engine/swarm/)) manage service replicas to meet the desired state for the service in a declarative way, as opposed to manually managing _n_ liferay services
* Secondly, your composition allows flexible-sized clusters, as opposed to re-declare additional liferay services with the same image but slightly different configuration. 
* Service definition is more compact and maintainable  
  
To make liferay service scaling possible, service must be defined in a way that allow **seamless replication**. This has some implications:
* _Get rid of port bindings_ (8080:8080) for all the containers. If 2 containers try to run on the same host, the second one won't start.  
* _Get rid of setting container names_: they can not be fixed as replicas are managed automatically
* _Liferay cluster configuration must be the same across all containers_: for example, specific IPs should not be required, or if they are, container must self-configure before starting Liferay.
* _Get rid of fixed configuration for load-balancing/sticky session_: these mechanisms should be ready to work with different number of replicas (out of scope for this iteration) 

There are different mechanisms to scale a service, which depend on the technology you use. In this iteration we'll make it work for docker-compose and docker swarm.
 
### Liferay Service configuration
In this iteration, Liferay service is defined as follows:
* No port bindings 
* All cluster configuration is provided via properties (as env vars)
* JDBC_ping manages jgroups views
* No changes in the cache distribution configuration 

In general, we'll favor simplicity and reusability in the configuration. This allows us to speed up the iterations as a change will apply consistently where necessary. To achieve this, we'll make extensive use of environment variables so that all config files, as well as the docker-compose file, can get the values from the variables rather than hardcoding them. This is not taken to the extreme as we're just applying it to env vars provisioning: config files we put in the containers may require manual changes. 
 
Usage of env vars in the docker-compose file has some limitations, namely:
* Variable substitution only works in the values of the docker-compose, not in the keys. This prevents us to use them to name volumes and networks. We're using fixed names for them. 
* In the service definition, it's not possible to reuse env vars created in the dockerfile, such as $LIFERAY_HOME. They seem available only at container runtime.

Nevertheless, the use of a .env file is still very useful. We can define values that are available to the docker engine, so that service definitions can use them. This allows to populate environment variables to different containers (mysql database user for example). In the case of Liferay, that information can be reused in the JDBC ping definition, as Jgroups substitutes variable references for their values.

Interesting reads: [Docker ARG, ENV and .env - a Complete Guide](https://vsupalov.com/docker-arg-env-variable-guide/)  
   
### docker-compose
docker-compose can scale a service. In compose file format v2 one could specify `scale: 2` as part of the service configuration. There also was the `docker-compose scale` [deprecated command](https://docs.docker.com/compose/reference/scale/).

In compose file v.3, scale option is not present. The syntax to specify replicas is ignored by docker-compose (only understood by docker swarm) but you can run more instances of the liferay service by running `docker-compose up --scale liferay=2`

As a result, using docker-compose with file format v3, there is no hint in the docker-compose about which services are scaled and how many instances of each are meant to run. You need to list the running containers to figure it out.

I was able to scale the liferay service and have a 2-node cluster. Each node has a different IP that can be accessed from the host. You need to know that IP as there are no port bindings (localhost:8080 no longer reaches a container).
 
 ### Docker swarm
Docker engine can work in swarm mode. File format can still be docker-compose like, but it's important to know that docker-compose and docker stack ignore different parts of this file.
 
Moreover, some of these differences directly affect the way services are defined. These are the roadblocks I found in order to properly run a compose in swarm:
 * **Container name is ignored by docker stack**: there is no way to give names to containers. We stopped doing it for the liferay containers (for the purpose of scaling them with docker-compose), but now, this affects to any container. As container name works as hostname, liferay service needs a different mechanism to know about where database and search engine are. This can now be achieved via network aliases.
 * **ulimits are ignored by docker stack**: As a result, it's no longer possible to set some important limits. This seems an issue for [elasticsearch and the memory lock limit](https://stackoverflow.com/questions/55500300/elastic-in-docker-stack-swarm). Fortunately, the other limits we set can be omitted. This does not imply a satisfactory solution as now we depend on host os pre-defined limits. Current solution is to avoid memory lock and document this limitation. Also see how much of this affects ES7 images.
 * **.env file is ignored  by docker stack**: env variables are empty when containers are run. This prevents mysql and liferay to set the right user for the DB. This blocker can be worked around in a couple of ways:
   * Letting docker-compose to make the substitution, then piping the result to docker stack deploy: `docker-compose config | docker stack deploy --compose-file - 03_liferay-cluster`
   * Creating the right environment before running the command. Several examples:
      * Source the env file. Requires exporting all the variables in the .env file, which becomes a bash script:
      * Use the env command with the right names and values: `env $(cat .env | tr "\\n" " ") && docker stack deploy --compose-file - 03_liferay-cluster`
 * **Service replicas are ignored by docker-compose**: you can specify replicas in the compose file under the `deploy` key, but only docker stack will honor them. This forces us to use separate mechanisms to scale the service.

Interesting reads: [docker-compose and docker stack ignore different parts of the compose file (official docs)](https://docs.docker.com/compose/compose-file/#volume-configuration-reference) , [differences stack file and compose file (stackoverflow)](https://stackoverflow.com/questions/43099408/whats-the-difference-between-a-stack-file-and-a-compose-file)  

Steps to run this composition in a swarm
 * Initialize your docker engine to become a single-node swarm:
    * `docker swarm init --advertise-addr <IP|interface>` (I've used wlp61s0 which is my wifi interface)
 * Change the docker-compose to accommodate the above elements.
 * Deploy the stack to the swarm (provided that the environmental variables in the .env file are defined): `docker stack deploy --compose-file docker-compose.yml 03_liferay-cluster`

## Requirements (iteration 03)
* Define replicas for the liferay service
* Do not replicate container configuration for each liferay node
* Allow replicas to form a liferay cluster

## Requirements (iteration 02)
* Define a ES6 node and connect liferay to it

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
* Load balancing, sticky session, tomcat session replication
* Database timezone
* Database character encoding
* Ensure character encoding and timezone are the same in DB and JVM
* Elastic search [advanced configuration](https://www.elastic.co/guide/en/elasticsearch/reference/7.5/docker.html)