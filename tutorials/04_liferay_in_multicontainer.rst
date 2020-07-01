Liferay in a multi container setting
************************************

This tutorial will enable reader to understand and run simple examples of multicontainer applications where Liferay plays a central role.

.. contents::

Introduction
============
Before exploring multi-container settings, let's take a quick look to some basics about orchestration and docker-compose, which will be helpful to better understand what comes next.

Bye Liferay container, hello Liferay service
--------------------------------------------
After a quick glance over the previous tutorials or the skillmap use cases (except for the ones dealing with multicontainer settings), reader will realize that the way to run a container is always the same:

.. code-block:: bash

 docker run <options> <image>

Running a docker engine command in the host is nothing but exercising the `Docker Client CLI API <https://docs.docker.com/engine/reference/commandline/cli/>`_. This is just one of many ways to run containers.

When your application needs *different* containers (say, the Liferay and a mysql for the DB storage), then working with the docker client CLI becomes a hard task: both containers need to be provided with same network settings so that they can talk to each other, they should start at the same time, status needs to be monitored for each container, etc. Even in simple cases like this, you'll likely need to code some scripts to work with both containers in a consistent way.

These, amongst others, were the reasons to develop container orchestrators. What if, rather than direct commands, we could describe the **desired system state** in a *declarative way*, by providing some sort of descriptor?.

Such a file descriptor would somehow substitute direct invocations to the ``docker run`` command above. Therefore, it must contain the elements required to run the containers:

.. code-block:: bash

 service 1:
    image: <image 1>
    <options for image 1>
 service 2:
    image: <image 2>:
    <options for image 2>

Now imagine we can run the orchestrator using that descriptor file. The orchestrator takes care of managing such services by creating the required containers with the right options, monitoring them, stopping them, etc. That would save a lot of work!

That's the essence of what we're about to discover in this tutorial. You would no longer work with containers, but with **services** you declare, with given properties, resources and desired state. Let the orchestrator do the rest.

Hello world (docker-compose)
----------------------------
To illustrate the above in a minimal but real setting, consider this docker-compose yaml file (`04_files/01_hello_world_compose.yml <./04_files/01_hello_world_compose.yml>`_):

.. code-block:: yaml

 version: '3'
 services:
   liferay:
     image: liferay/portal:7.3.1-ga2
     ports:
       - 8080:8080

This is declaring a service called ``liferay``, implemented by a container using the ``liferay/portal:7.3.1-ga2`` image, and exposing port 8080 in the container to the 8080 in the host.

You might have guessed that the above has some resemblance with the docker run options you're familiar with:

.. code-block:: bash

 $ docker run -it -p 8080:8080 liferay/portal:7.3.1-ga2

However, to run this, we'll not use ``docker run`` but ``docker-compose``. Please note that `docker-compose <https://docs.docker.com/compose/>`_ is a separate tool which has to be installed in your host machine along with the docker engine.

docker-compose has a `specific CLI <https://docs.docker.com/compose/reference/overview/>`_. It's not a goal of this tutorial to describe it thoroughly as focus is to help reader to acquire a basic understanding of how services are declared and used.

A note about file naming: as sample file is not named ``docker-compose.yml`` as the standard convention suggests, we'll have to tell what file do we want docker-compose to read. This is achieved with the ``-f`` option.

We'll start the services in the above composition by using the ``up`` command:

.. code-block:: bash

 $ docker-compose -f 04_files/01_hello_world_compose.yml up
 WARNING: The Docker Engine you're using is running in swarm mode.

 Compose does not use swarm mode to deploy services to multiple nodes in a swarm. All containers will be scheduled on the current node.

 To deploy your application across the swarm, use `docker stack deploy`.

 Creating network "04_files_default" with the default driver
 Creating 04_files_liferay_1 ... done
 Attaching to 04_files_liferay_1
 liferay_1  | [LIFERAY] To SSH into this container, run: "docker exec -it cc1d973c7d83 /bin/bash".
 liferay_1  |
 liferay_1  | [LIFERAY] Using zulu8 JDK. You can use another JDK by setting the "JAVA_VERSION" environment varible.
 ...
 liferay_1  | [LIFERAY] Starting Liferay Portal. To stop the container with CTRL-C, run this container with the option "-it".
 ...
 liferay_1  | 30-Jun-2020 06:49:21.484 INFO [main] org.apache.catalina.startup.Catalina.start Server startup in [56,371] milliseconds

What we've just run is not merely syntactic sugar for ``docker run`` command. There are significant differences under the hoods. Let's review what docker-compose did:

* First, it realizes that this host runs the docker engine in swarm mode. Let's ignore this for now, it has to do with other orchestrator installed in the host system
* Creates a network called ``04_files_default``. As you can see, docker-compose chooses the name of the containing folder (04-files) as a way to create unique names.
* Creates a container called ``04_files_liferay_1`` with the supplied image
* After this, attaches to the container so that container output can be logged with the token ``liferay_1`` as prefix. This is similar to the usage of ``-it`` flags in ``docker run``

As opposed to ``docker run``, where containers use the default bridge network, docker-compose creates a dedicated network with the default driver, let's take a look:

.. code-block:: bash

 $ docker network ls
 NETWORK ID          NAME                                                       DRIVER              SCOPE
 415b78d7f0bc        04_files_default                                           bridge              local
 ...

You can now access liferay from your host as you'd do if you ran the tomcat directly.

If you hit ``Ctrl-C`` you'll stop all the services. In this sense, docker-compose works in *attached* mode by default.

**Bonus exercise**: using ``docker inspect <container id>``, examine a ``liferay/portal:7.3.1-ga2`` container run with ``docker run`` and another one run via ``docker-compose up``. Note the main differences.

Adding the database service
===========================
Now that we have a working docker-compose example, we can move forward and add more services. Let's begin by the most obvious one: the database.

As explained before, orchestrating services is not just about running them together. In this section, we'll explore how to make them *work* together, both in terms of needs and, of course, in terms of docker-compose file directives required.

The first attempt to have multi-container service composition would roughly be about choosing a compatible database image (say, mysql) and add it as a new service, like this:

.. code-block:: diff

 version: '3'
 services:
   liferay:
     image: liferay/portal:7.2.1-ga2
     ports:
      - 8080:8080
 +  database:
 +    image: mysql:8.0

Well, that's a good start: two services were put together. However, the above won't even start. That's far from being enough. We have to make them *work* together. Let's see how.

Configuring the mysql container
-------------------------------
The bare minimum elements needed by the `mysql image <https://hub.docker.com/_/mysql>`_ are

.. code-block:: diff

  version: '3'
   services:
     liferay:
       image: liferay/portal:7.2.1-ga2
       ports:
        - 8080:8080
     database:
       image: mysql:8.0
 +     environment:

Communicating both containers
-----------------------------
Although docker-compose creates a dedicated network and makes it available to all containers, we are going to create a new network for our composition.

