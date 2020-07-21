Liferay in a multi container setting
************************************

This tutorial will enable reader to understand and run simple examples of multicontainer applications where Liferay plays a central role, including a liferay cluster. All samples are provided in separate files `in this folder <04_files/>`_, therefore, the best way to run though this tutorial is to clone the repository and try the samples.

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
To illustrate the above in a minimal but real setting, consider the docker-compose yaml file in `sample #1 <./04_files/01_hello_world_compose.yml>`_:

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

``docker-compose`` has a `specific CLI <https://docs.docker.com/compose/reference/overview/>`_. It's not a goal of this tutorial to describe it thoroughly as focus is to help reader to acquire a basic understanding of how services are declared and used.

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

The first attempt to have multi-container service composition would roughly be about choosing a compatible database image (say, mysql) and add it as a new service, as shown in `sample #2 <./04_files/02_liferay_mysql_bare.yml>`_:

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
The bare minimum elements needed by the `mysql image <https://hub.docker.com/_/mysql>`_ are the **database name** to create for the first time, the ``root`` **superuser account password** and, optionally, the **credentials of an user** which will be granted superuser permissions for the specified database. That's enough to start a fresh new database server.

All this information can be provided to the container via *environment variables*, which have their own place in the ``docker-compose.yml`` as shown in `sample #3 <04_files/03_liferay_mysql_configured_DB.yml>`_:

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
 +       MYSQL_ROOT_PASSWORD: testroot
 +       MYSQL_DATABASE: lportal
 +       MYSQL_USER: mysqluser
 +       MYSQL_PASSWORD: test

With this, mysql container will be able to start, and an empty database called ``lportal`` will be created. In addition, ``mysqluser`` user can operate as a superuser on that database.

Looks better, but we must ensure that liferay can talk to the database if we want something useful...

Communicating both containers: the network
------------------------------------------
By default, docker-compose creates a dedicated `bridge <https://docs.docker.com/network/bridge/>`_ network and makes it available to all containers, meaning that containers **in the same host** can see each other and access to the services in them without the need of exposing ports. That's the reason why mysql port (3306) is not exposed in the container, as it's not required to access mysql from outside the composition.

We are going to create a new network for our composition to showcase the syntax. One can create several networks in a given composition, and make them available to the containers at discretion. This will affect the number of network interfaces and routing rules configured for each container.

Network driver will use the **bridge** driver as all the examples are meant to run in a **single** docker host. This tutorial is not covering the cases where **many** docker hosts run a composed application, in which case, the *overlay* driver should be used.

To create a network, add its name into the ``networks`` section. Optionally, set the ``driver`` to use. Then, reference it from the containers which should use that network. That's an excellent chance to give a host name to the container *in that network* via the ``aliases`` directive. The result would look like `sample #4 <04_files/04_liferay_mysql_networking.yml>`_:

.. code-block:: diff

  version: '3'
  services
    liferay:
      image: liferay/portal:7.2.1-ga2
      ports:
        - 8080:8080
 +    networks:
 +      - liferay-net
    database:
      image: mysql:8.0
      environment:
        MYSQL_ROOT_PASSWORD: testroot
        MYSQL_DATABASE: lportal
        MYSQL_USER: mysqluser
        MYSQL_PASSWORD: test
 +    networks:
 +      liferay-net:
 +        aliases:
 +          - database
 +networks:
 +  liferay-net:
 +    driver: bridge

First, we've told docker-compose to add a new network called ``liferay-net`` using the ``bridge`` network driver. We used a new top-level ``networks`` directive. Then, we made the two services to join that network, using a service-level ``networks`` directive. In the database container, we set an alias ``database`` in that network.

As a result, services can "see" each other by specifying either the IP address or the aliases they have in the network. This last option is really handy as it allows to **provide a container alias in other container's configuration**.

Configuring Liferay to use the database service
-----------------------------------------------

Now that containers *are* in a network, and have known host names in it, it's time to configure liferay to use the database service. Note that this is not a **service-level** configuration (such as the name of the available networks, the ports, the alias, or the service name), but an **application-level** configuration, which is specific to the apps shipped with the container.

In the case of Liferay, this configuration is traditionally provided via ``portal-ext.properties`` file. That's a perfectly valid solution, however, it forces us to add an extra file to the container via bind mount, and ensure those properties get updated if the docker-compose file changes. Fortunately, Liferay also provides a mechanism based on *environment variables* with specific names, which overrides portal properties.

This is very suitable for container settings, because it allows to pass portal properties from the docker host environment, as illustrated in `sample #5 <04_files/05_liferay_mysql_connected.yml>`_:

.. code-block:: diff

  version: '3'
  services:
    liferay:
      image: liferay/portal:7.2.1-ga2
 +    environment:
 +      LIFERAY_JDBC_PERIOD_DEFAULT_PERIOD_DRIVER_UPPERCASEC_LASS_UPPERCASEN_AME: com.mysql.cj.jdbc.Driver
 +      LIFERAY_JDBC_PERIOD_DEFAULT_PERIOD_URL: jdbc:mysql://database:3306/lportal?useUnicode=true&characterEncoding=UTF-8&useFastDateParsing=false
 +      LIFERAY_JDBC_PERIOD_DEFAULT_PERIOD_USERNAME: mysqluser
 +      LIFERAY_JDBC_PERIOD_DEFAULT_PERIOD_PASSWORD: test
      ports:
        - 8080:8080
      networks:
        - liferay-net
    database:
      image: mysql:8.0
      environment:
        MYSQL_ROOT_PASSWORD: testroot
        MYSQL_DATABASE: lportal
        MYSQL_USER: mysqluser
        MYSQL_PASSWORD: test
      networks:
        liferay-net:
          aliases:
            - database
  networks:
    liferay-net:
      driver: bridge

This is the first composition that *connects* both services so that liferay service will persist its data via the database service. We're getting closer. However, that's not enough. Let's run this to discover why.

Before running this composition, please make sure that any older container you may have created in this tutorial from previous snippets is deleted:

.. code-block:: bash

 $ docker container rm 04_files_database_1
 04_files_database_1
 $ docker container rm 04_files_liferay_1
 04_files_liferay_1

This will force docker-compose to create new containers, and not reusing the previous ones (if already created). This way we can see what happens if you try to run this composition from scratch:

.. code-block:: bash

 $ docker-compose -f 04_files/05_liferay_mysql_connected.yml up
 ...
 Creating 04_files_database_1 ... done
 Creating 04_files_liferay_1  ... done
 Attaching to 04_files_liferay_1, 04_files_database_1
 ...
 database_1  | 2020-07-02 14:28:23+00:00 [Note] [Entrypoint]: Entrypoint script for MySQL Server 8.0.19-1debian9 started.
 liferay_1   | [LIFERAY] To SSH into this container, run: "docker exec -it 94c0961bd735 /bin/bash".
 ... <more logs from the initialization of both containers>
 database_1  | 2020-07-02 14:28:23+00:00 [Note] [Entrypoint]: Initializing database files
 ...
 database_1  | 2020-07-02 14:28:27+00:00 [Note] [Entrypoint]: Database files initialized
 ...
 database_1  | 2020-07-02 14:28:27+00:00 [Note] [Entrypoint]: Temporary server started.
 ...
 liferay_1   | 2020-07-02 14:28:29.683 ERROR [main][HikariPool:541] HikariPool-1 - Exception during pool initialization.
 liferay_1   | com.mysql.cj.jdbc.exceptions.CommunicationsException: Communications link failure__The last packet sent successfully to the server was 0 milliseconds ago. The driver has not received any packets from the server. [Sanitized]
 liferay_1   | 	at com.mysql.cj.jdbc.exceptions.SQLError.createCommunicationsException(SQLError.java:174)
 ...
 liferay_1   | Caused by: com.mysql.cj.exceptions.CJCommunicationsException: Communications link failure__The last packet sent successfully to the server was 0 milliseconds ago. The driver has not received any packets from the server. [Sanitized]
 ...
 liferay_1   | Caused by: java.net.ConnectException: Connection refused (Connection refused)
 ...
 database_1  | 2020-07-02 14:28:29+00:00 [Note] [Entrypoint]: Creating database lportal
 database_1  | 2020-07-02 14:28:29+00:00 [Note] [Entrypoint]: Creating user mysqluser
 database_1  | 2020-07-02 14:28:29+00:00 [Note] [Entrypoint]: Giving user mysqluser access to schema lportal
 database_1  |
 database_1  | 2020-07-02 14:28:29+00:00 [Note] [Entrypoint]: Stopping temporary server
 ...
 liferay_1   | Caused by: java.net.ConnectException: Connection refused (Connection refused)
 ...
 liferay_1   |  java.lang.RuntimeException: org.springframework.beans.factory.BeanCreationException: Error creating bean with name 'com.liferay.portal.kernel.util.InfrastructureUtil#0' defined in class path resource [META-INF/infrastructure-spring.xml]: Cannot resolve reference to bean 'liferayTransactionManager' while setting bean property 'transactionManager'; nested exception is org.springframework.beans.factory.BeanCreationException: Error creating bean with name 'liferayTransactionManager' defined in class path resource [META-INF/hibernate-spring.xml]: Cannot resolve reference to bean 'liferayHibernateSessionFactory' while setting constructor argument; nested exception is org.springframework.beans.factory.BeanCreationException: Error creating bean with name 'liferayHibernateSessionFactory' defined in class path resource [META-INF/hibernate-spring.xml]: Invocation of init method failed; nested exception is com.mysql.cj.jdbc.exceptions.CommunicationsException: Communications link failure
 ...
 liferay_1   | 02-Jul-2020 14:28:31.011 INFO [main] org.apache.catalina.startup.Catalina.start Server startup in [7,991] milliseconds
 database_1  | 2020-07-02T14:28:31.378568Z 0 [System] [MY-010910] [Server] /usr/sbin/mysqld: Shutdown complete (mysqld 8.0.19)  MySQL Community Server - GPL.
 ...
 database_1  | 2020-07-02 14:28:31+00:00 [Note] [Entrypoint]: MySQL init process done. Ready for start up.
 ...
 database_1  | 2020-07-02T14:28:32.182502Z 0 [System] [MY-010116] [Server] /usr/sbin/mysqld (mysqld 8.0.19) starting as process 1
 database_1  | 2020-07-02T14:28:32.750098Z 0 [Warning] [MY-010068] [Server] CA certificate ca.pem is self signed.
 database_1  | 2020-07-02T14:28:32.753948Z 0 [Warning] [MY-011810] [Server] Insecure configuration for --pid-file: Location '/var/run/mysqld' in the path is accessible to all OS users. Consider choosing a different directory.
 database_1  | 2020-07-02T14:28:32.775889Z 0 [System] [MY-010931] [Server] /usr/sbin/mysqld: ready for connections. Version: '8.0.19'  socket: '/var/run/mysqld/mysqld.sock'  port: 3306  MySQL Community Server - GPL.
 database_1  | 2020-07-02T14:28:32.859155Z 0 [System] [MY-011323] [Server] X Plugin ready for connections. Socket: '/var/run/mysqld/mysqlx.sock' bind-address: '::' port: 33060

 ^CGracefully stopping... (press Ctrl+C again to force)
 Stopping 04_files_liferay_1  ... done
 Stopping 04_files_database_1 ... done

As you can see, the mysql container needs some time to create the configured database. During that time, liferay container attempts to connect to such database and generates errors as it's not ready yet.

This is not acceptable solution. Even if both containers could start ok, and in subsequent startups the database is already created, the point is that there's no guarantee that the service is ready before being used. Both services need to be syncrhonized.

Syncrhonizing services
----------------------
docker-compose allows to start services in a `predefined order <https://docs.docker.com/compose/startup-order/>`_. However, starting a container does not mean that container is **ready** to work. For instance, liferay containers take less than a minute to serve the first page. A similar thing happens for mysql when the DB is created for the first time.

The problem we want to solve is: how can liferay service start *after* mysql service is able to accept database connections?

Solution comes via scripting. Containerized applications must run some piece of code which prevents the app to be launched if the dependent services are not ready. This piece of logic, and the general problem it addresses, is out of the scope of docker itself as docker just deals with container management. In other words, this falls into application's responsibility.

So, we must make liferay startup wait till the database service is ready to accept connections. Fortunately, there are 2 elements that makes this requirement easy to achieve:

#. The liferay container allows to hook up scripts to specific `lifecycle phases <https://grow.liferay.com/people/Advanced+Liferay+operation+use+cases#run-my-own-scripts-in-the-container-before-liferay-starts>`_.
#. There's a generic script called `wait-for-it.sh <https://github.com/vishnubob/wait-for-it>`_ which can be used to check the availability of connections to a host:port

Being it easy to achieve, solution requires to provide extra code to the liferay container, therefore, each application will have different, specific wait requirements.

Implementing this requires the wait-for-it.sh script to be provided to the container, then invoked in an app-specific way from another script, which will be hooked into the configuration phase. The former can be added to the container at ``$liferay_home``, and the latter has to be copied into the ``/mnt/liferay/scripts`` for the container to detect and execute it. This yields to the following file structure to be bind-mounted into the container:

.. code-block:: bash

 liferay/
 ├── files
 │   └── wait-for-it.sh
 └── scripts
     └── wait-for-mysql.sh

The logic for wait-for-mysql.sh is as follows:

.. code-block:: bash

 #!/usr/bin/env bash
 chmod a+x /opt/liferay/wait-for-it.sh
 bash /opt/liferay/wait-for-it.sh -s -t 60 database:3306

Few things to note:

* ``wait-for-it.sh`` is *guaranteed* to be copied into ``$liferay_home`` (/opt/liferay) before ``wait-for-mysql.sh`` is run
* ``wait-for-mysql.sh`` can use the database service hostname as it's available in the container and resolved to the database container's IP address. If service changes its alias in the network, script must reflect that.
* Database *port* (3306) is *reachable* from the liferay container even if it's not exposed by the mysql container, because both containers are in the same network.

The last element we need is to configure the bind-mount into the liferay container. Time use the ``volumes`` directive to bind-mount our file structure onto the liferay container, as shown in `sample #6 <04_files/06_liferay_mysql_synchronized.yml>`_:

.. code-block:: diff

  version: '3'
  services:
    liferay:
      image: liferay/portal:7.2.1-ga2
      environment:
        LIFERAY_JDBC_PERIOD_DEFAULT_PERIOD_DRIVER_UPPERCASEC_LASS_UPPERCASEN_AME: com.mysql.cj.jdbc.Driver
        LIFERAY_JDBC_PERIOD_DEFAULT_PERIOD_URL: jdbc:mysql://database:3306/lportal?useUnicode=true&characterEncoding=UTF-8&useFastDateParsing=false
        LIFERAY_JDBC_PERIOD_DEFAULT_PERIOD_USERNAME: mysqluser
        LIFERAY_JDBC_PERIOD_DEFAULT_PERIOD_PASSWORD: test
      ports:
        - 8080:8080
      networks:
        - liferay-net
 +    volumes:
 +      - ./06_liferay:/mnt/liferay
    database:
      image: mysql:8.0
      environment:
        MYSQL_ROOT_PASSWORD: testroot
        MYSQL_DATABASE: lportal
        MYSQL_USER: mysqluser
        MYSQL_PASSWORD: test
      networks:
        liferay-net:
          aliases:
            - database
  networks:
    liferay-net:
      driver: bridge

The above will make the contents of `./06_liferay/ <./04_files/06_liferay>`_ available in ``/mnt/liferay/`` folder in the container. Please note that this location is relative to the directory where the docker-compose.yml file lives, and not where docker-compose command is run.

As a result, the liferay container entry point will do the following *before* running tomcat:

#. Copy whatever it finds in ``/mnt/liferay/files`` to ``$liferay_home``. That will make the ``$liferay_home/wait-for-it.sh`` available for running
#. Run whatever it finds in ``/mnt/liferay/scripts``

This is the result:

.. code-block:: bash

 $ docker-compose -f 04_files/06_liferay_mysql_synchronized.yml up
 ...
 Creating 04_files_liferay_1  ... done
 Creating 04_files_database_1 ... done
 Attaching to 04_files_database_1, 04_files_liferay_1
 database_1  | 2020-07-03 10:23:44+00:00 [Note] [Entrypoint]: Entrypoint script for MySQL Server 8.0.19-1debian9 started.
 ...
 database_1  | 2020-07-03 10:23:44+00:00 [Note] [Entrypoint]: Initializing database files
 ...
 database_1  | 2020-07-03T10:23:44.851891Z 0 [System] [MY-013169] [Server] /usr/sbin/mysqld (mysqld 8.0.19) initializing of server in progress as process 46
 liferay_1   | [LIFERAY] To SSH into this container, run: "docker exec -it 1a95f6c71c90 /bin/bash".
 liferay_1   |
 liferay_1   | [LIFERAY] Copying files from /mnt/liferay/files:
 liferay_1   |
 liferay_1   | /mnt/liferay/files
 liferay_1   | └── wait-for-it.sh
 liferay_1   |
 liferay_1   | [LIFERAY] ... into /opt/liferay.
 liferay_1   |
 liferay_1   | [LIFERAY] Executing scripts in /mnt/liferay/scripts:
 liferay_1   |
 liferay_1   | [LIFERAY] Executing wait-for-mysql.sh.
 liferay_1   | wait-for-it.sh: waiting 60 seconds for database:3306
 ...
 database_1  | 2020-07-03 10:23:48+00:00 [Note] [Entrypoint]: Database files initialized
 database_1  | 2020-07-03 10:23:48+00:00 [Note] [Entrypoint]: Starting temporary server
 ...
 database_1  | 2020-07-03 10:23:51+00:00 [Note] [Entrypoint]: Creating database lportal
 database_1  | 2020-07-03 10:23:51+00:00 [Note] [Entrypoint]: Creating user mysqluser
 database_1  | 2020-07-03 10:23:51+00:00 [Note] [Entrypoint]: Giving user mysqluser access to schema lportal
 database_1  |
 database_1  | 2020-07-03 10:23:51+00:00 [Note] [Entrypoint]: Stopping temporary server
 ...
 database_1  | 2020-07-03 10:23:53+00:00 [Note] [Entrypoint]: Temporary server stopped
 database_1  |
 database_1  | 2020-07-03 10:23:53+00:00 [Note] [Entrypoint]: MySQL init process done. Ready for start up.
 database_1  |
 ...
 database_1  | 2020-07-03T10:23:54.199832Z 0 [System] [MY-011323] [Server] X Plugin ready for connections. Socket: '/var/run/mysqld/mysqlx.sock' bind-address: '::' port: 33060
 liferay_1   | wait-for-it.sh: database:3306 is available after 9 seconds
 ...
 liferay_1   | 03-Jul-2020 10:23:55.458 INFO [main] org.apache.catalina.startup.Catalina.load Server initialization in [492] milliseconds
 ...
 liferay_1   | 2020-07-03 10:24:29.240 WARN  [main][ReleaseLocalServiceImpl:238] Table 'lportal.Release_' doesn't exist
 liferay_1   | 2020-07-03 10:24:29.243 INFO  [main][ReleaseLocalServiceImpl:129] Create tables and populate with default data
 ...
 liferay_1   | 03-Jul-2020 10:25:17.168 INFO [main] org.apache.catalina.startup.Catalina.start Server startup in [81,708] milliseconds

We can see how liferay waits 9 seconds till mysql is ready to accept connections. This allows a normal portal startup which includes database tables creation.

Adding data persistence beyond database service lifespan
--------------------------------------------------------

Subsequent runs of the above composition will be faster because ``docker-compose`` tries to reuse the containers if the configuration does not change. This means that they will be *started* rather than new ones being created. docker-compose informs about which specific operation is applying to the containers:

* **Creating** means that the container did not exist in the docker host previously, so it will be created and run for the first time.
* **Recreating** means that container already exists in the docker host and it's stopped. Its configuration in the docker-compose.yml has changed so the container can not be started again. Therefore, it is removed, then re-created with the same name and new options.
* **Starting** means that the container already exists in the docker host, it's stopped, and its configuration did not change from the previous run, so it can be started with the same options. In this case, writeable layer is kept.

By default, database container will store database files on the container writeable layer. This is not particular for the database service. Any container which modifies files originally present in the image will create a copy of them in the writeable layer. This has 2 implications:

* **Performance**: container filesystems are *layered* meaning that they store the files in separate areas (layers) and use a `Copy On Write <https://docs.docker.com/storage/storagedriver/#the-copy-on-write-cow-strategy>`_ strategy, good to save space, not as performant as the native filesystem.
* **Lifetime**: writeable layer is disposed when container is removed. Although it's kept when container is stopped (allowing restarting it), container management tools may delete containers along with their data.

As you may have guessed from the above statements, relying on the writable layer of the container to store the database tables seems not the best idea: database files shall be stored outside of the container filesystem for optimum performance and to enable container disposability. This can be done by delegating the storage of a specific directory in the container to an external storage device (see `Providing files to the container <https://grow.liferay.com/people/The+Liferay+Container+Lifecycle#providing-files-to-the-container>`_ for details).

We'll leverage docker-compose to create and manage a **volume**, which will be mounted on the ``/var/lib/mysql`` directory in the container. That directory is the place where mysql stores all database files. This time, we'll not use a bind mount but a real volume, which requires some extra directives as shown in `sample #7 <04_files/07_liferay_mysql_permanent_storage.yml>`_:

.. code-block:: diff

  version: '3'
  services:
    liferay:
      image: liferay/portal:7.2.1-ga2
      environment:
        LIFERAY_JDBC_PERIOD_DEFAULT_PERIOD_DRIVER_UPPERCASEC_LASS_UPPERCASEN_AME: com.mysql.cj.jdbc.Driver
        LIFERAY_JDBC_PERIOD_DEFAULT_PERIOD_URL: jdbc:mysql://database:3306/lportal?useUnicode=true&characterEncoding=UTF-8&useFastDateParsing=false
        LIFERAY_JDBC_PERIOD_DEFAULT_PERIOD_USERNAME: mysqluser
        LIFERAY_JDBC_PERIOD_DEFAULT_PERIOD_PASSWORD: test
      ports:
        - 8080:8080
      networks:
        - liferay-net
      volumes:
        - ./06_liferay:/mnt/liferay
    database:
      image: mysql:8.0
      environment:
        MYSQL_ROOT_PASSWORD: testroot
        MYSQL_DATABASE: lportal
        MYSQL_USER: mysqluser
        MYSQL_PASSWORD: test
      networks:
        liferay-net:
          aliases:
            - database
 +    volumes:
 +      - volume-mysql:/var/lib/mysql
  networks:
    liferay-net:
      driver: bridge
 +volumes:
 +  volume-mysql:

The **top-level** ``volumes`` directive instructs docker-compose to create a volume called ``volume-mysql`` using the default volume driver, which is the ``local`` driver, meaning that the volume is stored in the host machine and made available to the containers managed by the local docker engine.

In addition, the **service-level** ``volumes`` directive associates the ``mysql-volume`` volume with the ``database`` service, indicating a mount point in the container (``/var/lib/mysql``). This allows mysql tables to be stored in the volume rather than in the container writeable layer.

Using variables in the docker-compose file
------------------------------------------
The last step in this section addresses the problem of ensuring consistency across the docker-compose file via variables. Some of the named elements we've used across the previous sections can be specified using variables. More specifically, the values we give to the yaml keys, as illustrated by `sample #8 <04_files/08_liferay_mysql_with_variables.yml>`_:.

.. code-block:: diff

  version: '3'
  services:
    liferay:
      image: liferay/portal:7.2.1-ga2
      environment:
        LIFERAY_JDBC_PERIOD_DEFAULT_PERIOD_DRIVER_UPPERCASEC_LASS_UPPERCASEN_AME: com.mysql.cj.jdbc.Driver
 -      LIFERAY_JDBC_PERIOD_DEFAULT_PERIOD_URL: jdbc:mysql://database:3306/lportal?useUnicode=true&characterEncoding=UTF-8&useFastDateParsing=false
 +      LIFERAY_JDBC_PERIOD_DEFAULT_PERIOD_URL: jdbc:mysql://database:3306/${mysql_database_name}?useUnicode=true&characterEncoding=UTF-8&useFastDateParsing=false
 -      LIFERAY_JDBC_PERIOD_DEFAULT_PERIOD_USERNAME: mysqluser
 +      LIFERAY_JDBC_PERIOD_DEFAULT_PERIOD_USERNAME: ${mysql_user_name}
 -      LIFERAY_JDBC_PERIOD_DEFAULT_PERIOD_PASSWORD: test
 +      LIFERAY_JDBC_PERIOD_DEFAULT_PERIOD_PASSWORD: ${mysql_user_password}
      ports:
        - 8080:8080
      networks:
        - liferay-net
      volumes:
        - ./06_liferay:/mnt/liferay
    database:
      image: mysql:8.0
      environment:
        MYSQL_ROOT_PASSWORD: testroot
 -      MYSQL_DATABASE: lportal
 +      MYSQL_DATABASE: ${mysql_database_name}
 -      MYSQL_USER: mysqluser
 +      MYSQL_USER: ${mysql_user_name}
 -      MYSQL_PASSWORD: test
 +      MYSQL_PASSWORD: ${mysql_user_password}
      networks:
        liferay-net:
          aliases:
            - database
      volumes:
        - volume-mysql:/var/lib/mysql
  networks:
    liferay-net:
      driver: bridge
  volumes:
    volume-mysql:

Besides consistency, using variables avoids hardcoding values which may not need to be preset or even made public (like passwords). Please note that there are more advanced ways to `share secrets <https://docs.docker.com/compose/compose-file/#secrets>`_ between containers, but these lie out of the scope of this tutorial.

So, where are those variables taken from? ``docker-compose`` reads a `.env <./04_files/.env>`_ file which must be in the same folder where docker-compose is run. This mechanism is called `default environment variable declaration <https://docs.docker.com/compose/env-file/>`_ and is based on `variable substitution <https://docs.docker.com/compose/compose-file/#variable-substitution>`_ at the ``docker-compose`` file level. In other words, these variables are not passed to the services as part of the container environment. Please note this is a docker-compose unique feature.

So, in this case, the .env file would look like this:

.. code-block:: bash

 mysql_user_name=mysqluser
 mysql_user_password=test
 mysql_database_name=lportal

Finally, please remember to run this from the place where the .env file is, otherwise, docker-compose won't find it:

.. code-block:: bash

 /04_files [master]$ docker-compose -f 08_liferay_mysql_with_variables.yml up

Adding the search engine
========================
We have a running example of a multi-container application which combines the liferay and the database services. Next one is **search**. In the samples shown so far, liferay used the *embedded* elasticsearch. In this section, we'll configure our Liferay application to use ES in remote mode.

Selecting the ES image
----------------------
The search service must be based on some `elasicsearch image <https://hub.docker.com/_/elasticsearch>`_. Liferay 7.2 can work with ES6 and ES7.

A requirement in 7.2 is that JDK distribution and version used to run tomcat must be exactly `the same <https://help.liferay.com/hc/es/articles/360028711132-Installing-Elasticsearch>`_ as the one running the ES server. This requirement is due to the communication protocol between Liferay and ES.

When using containers, image owners make the decision of what to ship in the image. Liferay 7.2 containers use jdk 8, more specifically:

.. code-block:: bash

 $ docker exec  93d9970b8d07 /usr/lib/jvm/zulu-8/bin/java -version
 openjdk version "1.8.0_212"
 OpenJDK Runtime Environment (Zulu 8.38.0.13-CA-linux-musl-x64) (build 1.8.0_212-b04)
 OpenJDK 64-Bit Server VM (Zulu 8.38.0.13-CA-linux-musl-x64) (build 25.212-b04, mixed mode)

Looking at ES6 available tags, we find that

* ES `6.8.0 <https://hub.docker.com/layers/elasticsearch/library/elasticsearch/6.8.0/images/sha256-d0b291d7093b89017e2578932329eebe6f973a382231ff3bed716ea0951d8e9b?context=explore>`_ starts shipping jdk 12.0.1 and increases its version till jdk 14 (in ES `6.8.10 <https://hub.docker.com/layers/elasticsearch/library/elasticsearch/6.8.10/images/sha256-6c36fa585104d28d3a9e53c799a4e20058445476cadb3b3d3e789d3793eed10a?context=explore>`_
* ES `6.7.x <https://hub.docker.com/_/elasticsearch?tab=tags&page=1&name=6.7.>`_ uses jdk 12
* ES `6.6.x <https://hub.docker.com/_/elasticsearch?tab=tags&page=1&name=6.6.>`_ and `6.5.x <https://hub.docker.com/_/elasticsearch?tab=tags&page=1&name=6.5.>`_ use jdk 11
* ES `6.4.x <https://hub.docker.com/_/elasticsearch?tab=tags&page=1&name=6.4.>`_ uses jdk 10
* There are no older images in the ES 6 series

As a result, there is no way to match jdk versions between containers, not to mention the distribution. Although explicitly noting this fact, in this tutorial, no attempt to harmonize versions will be made. The chosen ES6 image is the `latest 6.5 series <https://hub.docker.com/layers/elasticsearch/library/elasticsearch/6.5.4/images/sha256-93109ce1d590482a06ba085943082b314ac188fcfdbffb68aebb00795c72bc8a?context=explore>`_ as it uses jdk 11 (LTS) but others could have been chosen too.

Configuring the ES6 container requires some extra tweaking which will allow to illustrate other directives in the docker-compose. This tutorial will show some of the practises described in the `Install ES with Docker <https://www.elastic.co/guide/en/elasticsearch/reference/6.5/docker.html>`_, the `Important System Configuration <https://www.elastic.co/guide/en/elasticsearch/reference/6.5/system-config.html>`_ and `Important Elastic Search Configuration <https://www.elastic.co/guide/en/elasticsearch/reference/6.5/important-settings.html>`_.

Configuring the ES6 container
------------------------------

Our first attempt to add a search service would look like `sample #9 <04_files/09_liferay_mysql_es6_bare.yml>`_:

.. code-block:: diff

  version: '3'
  services:
    liferay:
      ...
    database:
      ...
 +  search:
 +    image: elasticsearch:6.5.4
 +    networks:
 +      liferay-net:
 +        aliases:
 +          - elasticsearch
  networks:
    liferay-net:
      driver: bridge
  volumes:
    volume-mysql:

One could expect this to at least start the ES container, even if it just launched an isolated container. However, we get some errors even before search container can finish its own startup:

.. code-block:: bash

 $ docker-compose -f 09_liferay_mysql_es_bare.yml up
 ...
 Starting 04_files_database_1 ... done
 Starting 04_files_liferay_1  ... done
 Creating 04_files_search_1   ... done
 ...
 search_1    | [2020-07-07T14:03:36,275][INFO ][o.e.b.BootstrapChecks    ] [nkjR7YC] bound or publishing to a non-loopback address, enforcing bootstrap checks
 search_1    | ERROR: [1] bootstrap checks failed
 search_1    | [1]: max virtual memory areas vm.max_map_count [65530] is too low, increase to at least [262144]
 search_1    | [2020-07-07T14:03:36,346][INFO ][o.e.n.Node               ] [nkjR7YC] stopping ...
 search_1    | [2020-07-07T14:03:36,447][INFO ][o.e.n.Node               ] [nkjR7YC] stopped
 search_1    | [2020-07-07T14:03:36,447][INFO ][o.e.n.Node               ] [nkjR7YC] closing ...
 search_1    | [2020-07-07T14:03:36,477][INFO ][o.e.n.Node               ] [nkjR7YC] closed
 search_1    | [2020-07-07T14:03:36,479][INFO ][o.e.x.m.j.p.NativeController] [nkjR7YC] Native controller process has stopped - no new native processes can be started
 04_files_search_1 exited with code 78
 ...

ES6 requires some system-level changes to function properly. This tutorial reviews some of them to better understand the decisions made to run the container.

ES6 System configuration: ulimits and sysctls
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
There are `4 things <https://www.elastic.co/guide/en/elasticsearch/reference/6.5/system-config.html>`_ to consider here:

* `Disable swapping <https://www.elastic.co/guide/en/elasticsearch/reference/6.5/setup-configuration-memory.html>`_
* `File descriptors <https://www.elastic.co/guide/en/elasticsearch/reference/6.5/file-descriptors.html>`_
* `Number of threads <https://www.elastic.co/guide/en/elasticsearch/reference/6.5/max-number-of-threads.html>`_
* `Virtual memory <https://www.elastic.co/guide/en/elasticsearch/reference/6.5/vm-max-map-count.html>`_

Reason to consider these is that ES switches to *production mode* once a network setting is configured. ES containers try to bind to the container's IP address, so by default, they come in production mode. As aresult, a series of configuration checks are run. Failing those checks prodice ES server (and thus its container) to stop. That's why we got the previous errors.

Regarding **virtual memory**, as indicated `here <https://www.elastic.co/guide/en/elasticsearch/reference/6.5/vm-max-map-count.html>`_, ES utilizes ``mmapfs`` (memory-mapped filesystem) to store the indices. This feature requires the ``vm.max_map_count`` kernel parameter setting to be raised above the default limit.

Docker allows to set both container **kernel parameters** (*sysctls*) as well as **resource limits for processes** (*ulimits*). However, whereas the latter applies to processes, and thus can be set for the entry-point process and its descendants by docker, the former is a system-wide value. This means that not all sysctls can be set *only for a container* without affecting the **host** machine. More precisely, `a few of them <https://docs.docker.com/engine/reference/commandline/run/#configure-namespaced-kernel-parameters-sysctls-at-runtime>`_, which are namespaced, can be set. Docker does not support changing sysctls inside of a container that also modify the host system. As a result, the expected way of setting this **will have no effect**:

.. code-block:: diff

    search:
      image: elasticsearch:6.5.4
      networks:
        liferay-net:
          aliases:
            - elasticsearch
 # this will not be applied
 +    sysctls:
 +      vm.max_map_count: 262144

ES6 container will not start if this limit is too low. At this point, there are basically 2 choices:

1. Disable the use of mmapfs for ES via the setting ``node.store.allow_mmapfs``. This way, ES will use a `different store type <https://www.elastic.co/guide/en/elasticsearch/reference/6.5/index-modules-store.html>`_ for indices and there's no need to configure the kernel parameter. As ES container accepts config being set via environment variables, this approach would look like this:

   .. code-block:: diff

     search:
       image: elasticsearch:6.5.4
    +  environment:
    +    node.store.allow_mmapfs: "false"


2. Change the limit in the host operating system. For the case of Linux, this kernel parameter can be changed as follows:

   .. code-block:: bash

     host-machine$ sudo sysctl -w vm.max_map_count=262144

For the sake of simplicity, this tutorial uses the first method (changing the store type). For a production setting, that would not be the best fit.

To **disable swapping**, we'll add the ``bootstrap.memory_lock: true`` to the ES6 configuration file, which instructs the JVM to lock the heap in memory. ES may not be able to lock this amount of memory due to ``elasticsearch`` user not having that limit set, we must specify that limit to "unlimited". All this can be done from the docker-compose file s follows:

.. code-block:: diff

  search:
    image: elasticsearch:6.5.4
    networks:
      liferay-net:
        aliases:
          - elasticsearch
    environment:
      node.store.allow_mmapfs: "false"
 +    bootstrap.memory_lock: "true"
 +  ulimits:
 +    memlock: -1

The **file descriptors** setting is concerned with the maximum number of opened files for a given user, in this case, the user running the Elasticsearch process. ES sets its lower limit above 65535. This can be achieved via *ulimit* as follows:

.. code-block:: diff

  search:
    image: elasticsearch:6.5.4
    networks:
      liferay-net:
        aliases:
          - elasticsearch
    environment:
      node.store.allow_mmapfs: "false"
      bootstrap.memory_lock: "true"
    ulimits:
      memlock: -1
 +    nofile: 65536

Finally, the **number of threads** limits the number of threads that a user process can create. ES needs at least 4096 for this, so we have to enable this limit as follows:

.. code-block:: diff

  search:
    image: elasticsearch:6.5.4
    networks:
      liferay-net:
        aliases:
          - elasticsearch
    environment:
      node.store.allow_mmapfs: "false"
      bootstrap.memory_lock: "true"
    ulimits:
      memlock: -1
      nofile: 65536
 +    nproc: 4096

Whereas there are more potential system configurations to check, the above is enough to start the container and pass the bootstrap checks.

Configuring ES6 environment
^^^^^^^^^^^^^^^^^^^^^^^^^^^
In this section we will consider some ES settings. For a basic (i.e. non clustered) ES setting, most of them are not needed, so we'll focus just on the neccesary items:

* **Cluster settings**: the *cluster name* gives a recognizable name to the ES6 cluster, allowing Liferay to refer to the ES server in its configuration. Also, we'll instruct this service to not form a cluster by setting the appropriate node discovery type. We'll also give a name to the node in the cluster.
* **Memory settings**: tell ES JVM how much heap will be used, via the ``ES_JAVA_OPTS`` environment variable.

These elements will reflect in our docker-compose file as follows:

.. code-block:: diff

  search:
    image: elasticsearch:6.5.4
    networks:
      liferay-net:
        aliases:
          - elasticsearch
    environment:
      node.store.allow_mmapfs: "false"
      bootstrap.memory_lock: "true"
 +    discovery.type: "single-node"
 +    cluster.name: "LiferayElasticsearchCluster"
 +    node.name: "LiferayElasticsearchCluster_node1"
 +    ES_JAVA_OPTS: "-Xms2g -Xmx2g"
    ulimits:
      memlock: -1
      nofile: 65536
      nproc: 4096

Adding ES6 plugins
^^^^^^^^^^^^^^^^^^
`Liferay needs some extra plugins <https://help.liferay.com/hc/es/articles/360028711132-Installing-Elasticsearch#step-three-install-elasticsearch-plugins>`_ to be installed in the ES server. By default, ES6 images don't ship them so we must provide them. Our goal is to produce a container which includes the plugins.

Plugin installation in ES involves some invocations to the ES plugin installation tool, which downloads the plugin for the ES version and places it in the `plugins directory <https://www.elastic.co/guide/en/elasticsearch/plugins/6.5/_plugins_directory.html>`_. This kind of task is suited for *child images*: from the original ES6 image, we can create another one where the required plugins are installed. Being this a very reasonable option, we can achieve similar results for our purposes in a simpler way: make the plugins folder available to the container. However, please note the differences:

* If plugins are added to the child image, they will be part of the original image's filesystem so will be available in all containers, which makes it easier to cluster ES. Image would weigh more than the original one. Adding/removing plugins require rebuilding the image.
* If plugins are added to the container, they won't be part of the image's filesystem but will be in a mounted folder, which has to be made available to all containers if a ES cluster is set. Adding/removing plugins require manipulating the volume and restarting the containers.

This tutorial uses the second technique as the search service won't be clustered. In order to obtain the files that will be in the volume,

#. Plugins must be installed first in a ES6 container using the plugin installation tool
#. Then, use ``docker cp`` to copy the contents of ``/usr/share/elasticsearch/plugins`` folder (this is where `plugins are installed <https://www.elastic.co/guide/en/elasticsearch/reference/6.5/rpm.html#rpm-layout>`_) into a folder in the host machine
#. Use that folder as the bind-mount source against ``/usr/share/elasticsearch/plugins`` folder for new containers.

This is how the resulting `folder <04_files/10_liferay/elasticsearch>`_ looks like:

.. code-block:: bash

 10_liferay
 └── elasticsearch
     └── plugins-6.5.4
         ├── analysis-icu
         │   ├── analysis-icu-client-6.5.4.jar
         │   ├── icu4j-62.1.jar
         │   ├── LICENSE.txt
         │   ├── lucene-analyzers-icu-7.5.0.jar
         │   ├── NOTICE.txt
         │   └── plugin-descriptor.properties
         ├── analysis-kuromoji
         │   ├── analysis-kuromoji-6.5.4.jar
         │   ├── LICENSE.txt
         │   ├── lucene-analyzers-kuromoji-7.5.0.jar
         │   ├── NOTICE.txt
         │   └── plugin-descriptor.properties
         ├── analysis-smartcn
         │   ├── analysis-smartcn-6.5.4.jar
         │   ├── LICENSE.txt
         │   ├── lucene-analyzers-smartcn-7.5.0.jar
         │   ├── NOTICE.txt
         │   └── plugin-descriptor.properties
         └── analysis-stempel
             ├── analysis-stempel-6.5.4.jar
             ├── LICENSE.txt
             ├── lucene-analyzers-stempel-7.5.0.jar
             ├── NOTICE.txt
             └── plugin-descriptor.properties

The last step is to bind-mount it into the ES container:

.. code-block:: diff

  search:
    image: elasticsearch:6.5.4
    ...
 +  volumes:
 +    - ./10_liferay/elasticsearch/plugins-6.5.4:/usr/share/elasticsearch/plugins

Persisting the search indexes
-----------------------------
The last thing we need to have a minimal search service is to persist the search indices beyond container lifecycle. In this case, volume will do. In a clustered implementation of this service, the volume must be shared by all nodes (not covered here), however, here will use a local volume instead, mounted on the `standard image index storage path <https://www.elastic.co/guide/en/elasticsearch/reference/6.5/docker.html>`_, as finally shown in `sample #10 <./04_files/10_liferay_mysql_es6_configured_es.yml>`_:

.. code-block:: diff

  search:
    image: elasticsearch:6.5.4
    networks:
      liferay-net:
        aliases:
          - elasticsearch
    environment:
      node.store.allow_mmapfs: "false"
      bootstrap.memory_lock: "true"
      cluster.name: LiferayElasticsearchCluster
      discovery.type: "single-node"
      ES_JAVA_OPTS: "-Xms2g -Xmx2g"
    ulimits:
      memlock: -1
      nofile: 65536
      nproc: 4096
    volumes:
      - ./10_liferay/elasticsearch/plugins-6.5.4:/usr/share/elasticsearch/plugins
 +    - volume-elasticsearch:/usr/share/elasticsearch/data
  volumes:
    volume-mysql:
 +  volume-elasticsearch:

Configuring Liferay to use remote ES6
-------------------------------------
Now that we have a functional ``search`` service that fits our demonstration purposes, it's time to configure Liferay to use it. This requires 2 things:

#. Configure Liferay ES connector to use the ``search`` service.
#. Kindly ask ``liferay`` container to wait till ``search`` service is ready.

In order to make ``liferay`` wait till the ``search`` service is ready, just invoke the wait-for-it twice as indicated in `wait-for-mysql-and-elasticsearch.sh <./04_files/10_liferay/liferay/scripts/wait-for-mysql_and_elasticsearch.sh>`_:

.. code-block:: diff

  #!/usr/bin/env bash
  chmod a+x /opt/liferay/wait-for-it.sh
 +bash /opt/liferay/wait-for-it.sh -s -t 60 elasticsearch:9300
  bash /opt/liferay/wait-for-it.sh -s -t 60 database:3306

Note how hostnames in this file use the names given to the services in the docker-compose.yml.

It's possible to configure the ES connector from control panel, but that would require to start the liferay container unconfigured. So the 'docker' style of doing this is to provide the necessary configuration files to the container. In turn, fastest way to do this is to do such manual configuration, with minimal options, then export the ``.config`` file from system settings and providing it to new containers.

The resulting ``com.liferay.portal.search.elasticsearch6.configuration.ElasticsearchConfiguration.config`` file look like this:

.. code-block:: bash

 bootstrapMlockAll="true"
 operationMode="REMOTE"
 transportAddresses=[ \
   "elasticsearch:9300", \
   ]

Note that ES cluster name is not exported as we gave a name to the ES cluster which is the default expected by Liferay.

To `provide this configuration to Liferay container <https://grow.liferay.com/people/Configuring+Liferay+use+cases#providing-new-osgi-configuration-files>`_ it's required to allow a new bind-mount from `a new place <./04_files/10_liferay/liferay/>`_ in your host machine, where the scripts and ``.config`` file will be, according to the following layout:

.. code-block:: bash

 10_liferay/liferay/
 ├── files
 │   ├── osgi
 │   │   └── configs
 │   │       └── com.liferay.portal.search.elasticsearch6.configuration.ElasticsearchConfiguration.config
 │   └── wait-for-it.sh
 └── scripts
     └── wait-for-mysql_and_elasticsearch.sh

Therefore, the folder will be bind-mounted to a special location in the container, as illustrated by `sample #11 <./04_files/11_liferay_mysql_es6_connected.yml>`_:

.. code-block:: diff

  version: '3'
  services:
    liferay:
      image: liferay/portal:7.2.1-ga2
      volumes:
 -      - ./06_liferay:/mnt/liferay
 +      - ./10_liferay:/mnt/liferay

This is a good moment to try what we've learnt so far. Some things to remember:

* We used ``.env`` file to store some common names. Although a good practise, there are places where names are still hardcoded, particularly, the files we bind-moint onto the container.
* We syncrhonized service availability via app-level logic implemented in the dependent service (``liferay`` in this case) via the ``wait-for-it.sh``
* We tweaked some system limits in the ``search`` service to accommodate ES container requirements
* We persisted information from the 3 services in specific volumes
* All we've seen so far can be run in a **single host**, i.e. using just one docker engine. Multiple host settings require more advanced infrastructure such as shared volumes or network routing.

Bonus exercise: using ES7 container
-----------------------------------
Goal is to create a new composition similar to the one given in `sample #11 <./04_files/11_liferay_mysql_es6_connected.yml>`_, where the ``search`` service is implemented with an ES7 container.

Technically, this is really an `upgrade operation <https://help.liferay.com/hc/es/articles/360035444872-Upgrading-to-Elasticsearch-7>`_ which requires several extra steps. Here are the main challenges reader will face:

#. The ES7 connector has to be downloaded from the Marketplace and installed into the containerized Liferay.
#. As a result of installing the ES7 connector Mk app, Liferay will ask to **restart the server**. That's somehow not very docker-friendly as it implies stopping the container and ensuring that the same container is restarted later, braking container disposability. A workaround is to unpack the LPKG contents and make them available to ``$liferay_home/osgi/modules`` rather than deploying the LPGK as intended.
#. The ES6 connector OSGi bundles have to be blacklisted so that it does not clash with the new connector
#. The ``search`` service now requires ES7 plugins

Clustering Liferay
==================
At this point, reader should be familiar with the basics of ``docker-compose.yml`` syntax and how the different services are declared. A pertinent question would be: **how to create a liferay cluster?**

Intuitively, the answer to this question might look like this: *add more liferay service instances and cluster them*. Being this a reasonable answer, the devil is in the details. Perhaps reader is more familiar with the last part of the sentence ("... cluster them") as this requires things like configuring cluster link, sharing the DB or the documents & media storage across all nodes in the cluster. However, the first part of the sentence ("add more service instances...") may look a bit undefined.

There are two approaches to "add more liferay services", each having pros and cons:

* **Add independent services**: a different ``service`` directive exists for each cluster node. Container configuration is mostly replicated across each service.

  .. code-block:: yaml

   services:
     liferay-node1:
        # same network, DB, D&M storage, cluster-link configuration
        # different ports (see below)
     liferay-node2:
        # same network, DB, D&M storage, cluster-link configuration
        # different ports (see below)

* **Scale the same service**: a single ``service`` is declared for all liferay instances. Container orchestrator can create and manage *service replicas* seamlessly. Service definition might include scaling information to inform the orchestrator:

  .. code-block:: yaml

   services:
     liferay:
        # same network, DB, D&M storage, cluster-link configuration
        # no ports
        deploy:
          replicas: 2  # for a two-node cluster

To better understand the meaning, implications and differences between both approaches, it's good to keep in mind that, in a realistic scenario, container orchestrator will utilize several host machines (i.e. docker engines) to deploy the containers, indeed, information about which machine runs which containers changes over time and is transparant from the point of view of the system user. This has implications in the exposed service ports, as two services in the same host can not bind to the same port in the host. We'll deal with this later on.

With this in mind, here are the main implications of using "add independent services" approach:

* Fixed maximum cluster size
* Container configuration must be replicated across all service definitions, which makes it harder to make changes.
* Complex port management: each liferay cluster node must bind to different ports in the hosts, unless constraints are set to run each service in a different host machine
* Orchestrator can't be leveraged to manage service replicas as, to its eyes, there are no replicas to manage. All services are different.

In contrast, here are the "scale the same service" implications:

* Variable maximum cluster size
* Consistent service definition thanks to a single container configuration
* Simpler port management: each node does not need to bind ports to the host. Orchestrator can access the service via ingress networking.
* Leverages orchestrator scaling and management features

At the time of writing, googling "liferay cluster docker" does not bring much examples of compositions. Those available mostly use the "independent services approach" (see `amusarra <https://github.com/amusarra/docker-liferay-portal>`_ or `borxa <https://github.com/borxa/docker-liferay7-cluster>`_ github repos to find some). Let's use the "scaling service" approach in this tutorial.

Scaling services
----------------
In the *Scaling services* approach, service specification indicates a desired system state where some service requires **replication**. This may take a *declarative* form (in the docker-compose.yml file) or an *imperative* one (via command instructing orchestrator to scale a service).

At this point, some differences between orchestrators start to arise. This tutorial is primarily focused to ``docker-compose``, but ``docker swarm`` will be mentioned where applicable, as both use the **same file format** to specify services. Please be aware that there are differences about how they process the file in terms of `ignored sections <https://docs.docker.com/compose/compose-file/#not-supported-for-docker-stack-deploy>`_.

Anyways, defining a *scalable liferay service* is a bit more challenging as compared to the standalone counterpart. Basically, configuration must be reusable across all replicas, meaning that any per-replica difference must be configured or set up outside the service definition. To illustrate this, let's try to scale the ``liferay`` service we defined in `sample #11 <./04_files/11_liferay_mysql_es6_connected.yml>`_ using ``docker-compose`` command. First, let's start the services as stated by sample #11:

.. code-block:: bash

 $ docker-compose -f 11_liferay_mysql_es6_connected.yml up
 ...
 Starting 04_files_liferay_1  ... done
 Starting 04_files_database_1 ... done
 Starting 04_files_search_1   ... done
 ...

Once all services are up and running, in another shell, let's instruct docker-compose to scale the liferay service to 2 replicas:

.. code-block:: bash

 $ docker-compose -f 11_liferay_mysql_es6_connected.yml up -d --scale liferay=2
 ...
 WARNING: The "liferay" service specifies a port on the host. If multiple containers for this service are created on a single host, the port will clash.
 Starting 04_files_liferay_1 ...
 Starting 04_files_liferay_1 ... done
 04_files_database_1 is up-to-date
 Creating 04_files_liferay_2 ...
 Creating 04_files_liferay_2 ... error

 ERROR: for 04_files_liferay_2  Cannot start service liferay: driver failed programming external connectivity on endpoint 04_files_liferay_2 (e09aae41b55d9ea30dbf9f2930e20068e8e6b975e78928de9c12cf99d0e196a8): Bind for 0.0.0.0:8080 failed: port is already allocated

 ERROR: for liferay  Cannot start service liferay: driver failed programming external connectivity on endpoint 04_files_liferay_2 (e09aae41b55d9ea30dbf9f2930e20068e8e6b975e78928de9c12cf99d0e196a8): Bind for 0.0.0.0:8080 failed: port is already allocated
 ERROR: Encountered errors while bringing up the project.

As you can see, it's not possible to bind the second replica's port onto host port 8080 as it's already taken by the first service replica. This illustrates how carefully *scalable* services are to be defined. Some examples of this include:

* Get rid of host port bindings (8080:8080) for scalable services if using docker-compose. When scaling up the service, docker-compose won't start the second one as port is already bound to the host. Note that it's possible to bind ports for replicated services using Docker swarm, see `Using docker swarm`_ for more details.
* Get rid of setting ``container_name`` directive. Names can not be fixed as replicas could not be started
* Liferay cluster configuration must be the same across all containers: for example, specific IPs should not be required, or if they are, container must self-configure before starting Liferay. See `Configuring the liferay cluster`_ for details.
* Get rid of fixed configuration for load-balancing/sticky session: these mechanisms should be ready to work with different number of replicas (out of scope of this tutorial, see `More features`_)

This is how a scalable liferay service would look like (see `sample #12 <./04_files/12_liferay_scalable_mysql_es6.yml>`_):

.. code-block:: diff

  services:
    liferay:
      image: liferay/portal:7.2.1-ga2
      environment:
        LIFERAY_JDBC_PERIOD_DEFAULT_PERIOD_DRIVER_UPPERCASEC_LASS_UPPERCASEN_AME: com.mysql.cj.jdbc.Driver
        LIFERAY_JDBC_PERIOD_DEFAULT_PERIOD_URL: jdbc:mysql://database:3306/${mysql_database_name}?useUnicode=true&characterEncoding=UTF-8&useFastDateParsing=false
        LIFERAY_JDBC_PERIOD_DEFAULT_PERIOD_USERNAME: ${mysql_user_name}
        LIFERAY_JDBC_PERIOD_DEFAULT_PERIOD_PASSWORD: ${mysql_user_password}
 -    ports:
 -      - 8080:8080
 +    deploy:
 +      replicas: 2
      networks:
        - liferay-net
      volumes:
        - ./10_liferay/liferay:/mnt/liferay

The `deploy <https://docs.docker.com/compose/compose-file/#deploy>`_ directive informs about the deployment and running of services.

 **Note about docker-compose and deploy directive**: docker-compose `ignores <https://docs.docker.com/compose/compose-file/#deploy>`_ the ``deploy`` directive, which is meant to be processed by docker swarm. We provide it here for illustrative purposes, and to make the descriptor usable by docker swarm later.

Although this sample can scale the liferay service using ``docker-compose``, please note that **we're far from having a liferay cluster**. Rather, we have 2 independent containers running against the same database, search engine and D&M storage. Furthermore, both services have to be accessed separatedly via <containerIP>:8080 as ports are no longer bound to the host. Finally, please note that both service replicas are not guaranteed to be run in different machines. Constraints about service deployment can be specified, however, these are out of the scope of this tutorial.

Configuring the liferay cluster
-------------------------------
At this point, we have a composition which supports ``liferay`` service scaling. It's time to `configure a liferay cluster <https://learn.liferay.com/dxp/7.x/en/installation-and-upgrades/setting-up-liferay-dxp/clustering-for-high-availability/clustering-for-high-availability.html>`_. Note that part of this configuration is already done for us: all service replicas share the search indices, the database connection and the documents & media storage.

So, we're left with `configuring the Cluster Link <https://learn.liferay.com/dxp/7.x/en/installation-and-upgrades/setting-up-liferay-dxp/clustering-for-high-availability/configuring-cluster-link.html>`_ to enable distributed cache. This entails the definition of some portal properties, some of them deserve specific considerations when set in a containerized environment. In addition, default Cluster Link configuration defines *multicast communication over UDP*. Besides not supported natively by docker (a particular network plugin is required), multicast support offered by cloud providers is often limited. As a result, this tutorial will utilize **unicast traffic over TCP**. This requires to choose a node discovery protocol, which will be **JDBC_PING** as we already have a database service which can be leveraged for this purpose. Most of the configurations will therefore apply to JGroups, which is a dependency of Cluster Link.

Let's review the `necessary changes <https://learn.liferay.com/dxp/7.x/en/installation-and-upgrades/setting-up-liferay-dxp/clustering-for-high-availability/configuring-unicast-over-tcp.html>`_ one by one.

Enabling Cluster Link
^^^^^^^^^^^^^^^^^^^^^

First configuration change has to do with enabling cluster link. We can do that via environment variables:

.. code-block:: diff

  services:
    liferay:
      image: liferay/portal:7.2.1-ga2
      environment:
        ...
 +      LIFERAY_CLUSTER_PERIOD_LINK_PERIOD_ENABLED: "true"
 +      LIFERAY_CLUSTER_PERIOD_LINK_PERIOD_AUTODETECT_PERIOD_ADDRESS: database:3306

These env vars provide the necessary properties to activate cluster link. Note that auto-detect address is set based on a host that is visible for all ``liferay`` service replicas.

Configuring Cluster Link to read JGroups file
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Before moving on with the JGroups configuration content, let's make sure Liferay will read it. This translates into a couple of properties being added as environment variables:

.. code-block:: diff

  services:
    liferay:
      image: liferay/portal:7.2.1-ga2
      environment:
        ...
        LIFERAY_CLUSTER_PERIOD_LINK_PERIOD_ENABLED: "true"
        LIFERAY_CLUSTER_PERIOD_LINK_PERIOD_AUTODETECT_PERIOD_ADDRESS: database:3306
 +      LIFERAY_CLUSTER_PERIOD_LINK_PERIOD_CHANNEL_PERIOD_PROPERTIES_PERIOD_CONTROL: ${jgroups_config_file}
 +      LIFERAY_CLUSTER_PERIOD_LINK_PERIOD_CHANNEL_PERIOD_PROPERTIES_PERIOD_TRANSPORT_PERIOD__NUMBER0_: ${jgroups_config_file}

The new ``${jgroups_config_file}`` variable will tell us where the JGroups file resides, so let's add it to the ``.env`` file:

.. code-block:: diff

 + jgroups_config_file=/jgroups/jdbc_ping.xml
   mysql_user_name=mysqluser
   mysql_user_password=test
   mysql_database_name=lportal

Now, the jgroups descriptor, named ``jdbc_ping.xml``, will be placed at the right place in the container. This entails placing it at specific point in the bind-mounted folder for the liferay container:

.. code-block:: bash

 └── liferay
     └── files
         └── tomcat
             └── webapps
                 └── ROOT
                     └── WEB-INF
                         └── classes
                             └── jgroups
                                 └── jdbc_ping.xml

With all these, we can work on the ``jdbc_ping.xml`` descriptor contents to enable JDBC PING node discovery.

Configuring JDBC_PING node discovery
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

To configure unicast traffic, jgroups needs to be told about the network interface to bind to. This information can be provided via JVM option ``-Djgroups.bind_addr=<host name or IP>``. In a containerized scenario, one can `specify the container's IP address in a network <https://docs.docker.com/compose/compose-file/#ipv4_address-ipv6_address>`_, however, this solution makes scaling not possible: the second container is not able to attach to the network with the same address, and a similar thing happens with the host name. As a result, in the "scaling services" approach, the orchestrator must choose which IPs and hostnames to use.

So, how to inform JGroups, if we don't know the IP till the container is started? Well, this can't be informed in the docker-compose.yml file, as the value is not available there. Once container starts, the output of ``hostname`` command or ``SHOSTNAME`` env var value will give the piece of data we need.

A potential way would be via scripting: an user-provided script would add the container's IP/hostname to the right environment variable (like `LIFERAY_JVM_OPTS or CATALINA_OPTS <https://grow.liferay.com/people/Configuring+Liferay+use+cases#set-jvm-options-for-liferay-in-the-container>`_). Unfortunately, those env variables changes only affect to the shell executing it, not to the tomcat process. So the last option here would be to directly provide a new ``setenv.sh`` file for tomcat which sets the JVM option accordingy.

Fortunately, as we'll see, the JGroups config file descriptor substitutes the environment variable references for their value. Therefore, it's possible to pass the value of ``$HOSTNAME`` to JGroups bind_addr parameter, like this:

.. code-block:: xml

 <TCP bind_addr="${HOSTNAME}" bind_port="7800"/>

This is the first piece of configuration for our JGroups file, which states the address:port pair that JGroups will bind to. Now it's time to add the node discovery protocol configuration. To `add JDBC_PING protocol <https://learn.liferay.com/dxp/7.x/en/installation-and-upgrades/setting-up-liferay-dxp/clustering-for-high-availability/configuring-unicast-over-tcp.html#jdbc-ping>`_ to the stack, we can leverage the variable substitution again to avoid hardcoding values:

.. code-block:: xml

 <TCP bind_addr="${HOSTNAME}" bind_port="7800"/>
 <JDBC_PING
   connection_url="${LIFERAY_JDBC_PERIOD_DEFAULT_PERIOD_URL}"
   connection_username="${LIFERAY_JDBC_PERIOD_DEFAULT_PERIOD_USERNAME}"
   connection_password="${LIFERAY_JDBC_PERIOD_DEFAULT_PERIOD_PASSWORD}"
   connection_driver="${LIFERAY_JDBC_PERIOD_DEFAULT_PERIOD_DRIVER_UPPERCASEC_LASS_UPPERCASEN_AME}"/>

This way of specifying the JDBC_PING configuration allows changes to the database credentials, driver or even URL without modifying the JGroups descriptor.

The rest of the file contains other protocol elements which configuration does not pose any issue in terms of docker-related mechanism. We'll leave those unmodified from the defaults, i.e., the ``tcp.xml`` file sample in the ``jgroups.jar`` distribution.

There is an extra configuration step when trying to work JDBC_PING in a containerized environment. Making a container *scalable* entails avoiding explicit configuration related to IP address/container name, delegating its management to the orchestrator. Due to the dynamic nature of these elements, JGroups node identification mechanism will yield different member ids for each container.

A container can be *stopped* or *killed*. When killed (-9), node has no chances to self-clean from the ping table. As a result, it's advisable to do some cleanup in the jdbc ping table to avoid pollution with zombie members. Older version of JGroups had a JDBC_PING option called ``clear_table_on_view_change`` for this purpose, howewer, it was `removed <https://github.com/belaban/JGroups/commit/45a20a205106f74e1df6e23a512754948e683a28#diff-d3c2b9831c9c676f3152782cfc055d09L105>`_ in favor of using a similar feature in the parent class (FILE_PING), called ``remove_all_data_on_view_change``, which we'll use here:

.. code-block:: diff

  <JDBC_PING
     connection_url="${LIFERAY_JDBC_PERIOD_DEFAULT_PERIOD_URL}"
     connection_username="${LIFERAY_JDBC_PERIOD_DEFAULT_PERIOD_USERNAME}"
     connection_password="${LIFERAY_JDBC_PERIOD_DEFAULT_PERIOD_PASSWORD}"
 -   connection_driver="${LIFERAY_JDBC_PERIOD_DEFAULT_PERIOD_DRIVER_UPPERCASEC_LASS_UPPERCASEN_AME}"/>
 +   connection_driver="${LIFERAY_JDBC_PERIOD_DEFAULT_PERIOD_DRIVER_UPPERCASEC_LASS_UPPERCASEN_AME}"
 +   remove_all_data_on_view_change="true"/>

In addition, given that both ``liferay`` service and node discovery feature rely on ``database`` service , when this service starts, it makes no sense to keep old data. Therefore, as a safeguard, we can instruct mysql container to run a cleanup script upon service initialization, which would complement the JGroups native  ``remove_all_data_on_view_change`` feature. This is achieved by adding the ``--init-file``

.. code-block:: diff

  database:
    image: mysql:8.0
 +  command:
 +    - "--init-file=/docker-entrypoint-initdb.d/clean_jgroups.sql"
    environment: ...
    networks:    ...
    volumes:
      - volume-mysql:/var/lib/mysql
 +    - ./13_liferay/mysql:/docker-entrypoint-initdb.d

This file will be run upon database service startup. Its location, relative to `13_liferay <./04_files/13_liferay>`_ folder, is

.. code-block:: bash

 └── mysql
     └── clean_jgroups.sql


The finishing touch here is to let Liferay display the cluster node which is serving each request, by adding the following property as environment variable, leading to the `sample #13 <./04_files/13_liferay_cluster_mysql_es6.yml>`_:

.. code-block:: diff

  services:
    liferay:
      image: liferay/portal:7.2.1-ga2
      environment:
        ...
 +      LIFERAY_WEB_PERIOD_SERVER_PERIOD_DISPLAY_PERIOD_NODE: "true"

Please note that sample #13 declares bind-mounts from both the ``10_liferay/`` and ``13_liferay/`` folders onto the containers.

Wrapup: running the cluster
---------------------------

Let's review what we have so far and how to use it. Our multicontainer application runs a *scalable* liferay cluster, conecected to the corresponding database and search services. Liferay cluster is configured to use jdbc ping over TCP unicast traffic, backed by the database service.

The application does not include a reverse proxy acting as front for the ``liferay`` service, therefore, each cluster node has to be reached indivicually. The node serving a request is shown in the response page.

You can run this application using docker-compose as follows:

.. code-block:: bash

 docker-compose -f 13_liferay_cluster_mysql_es6.yml up

Remember that this application is not exposing ports for the ``liferay`` service, therefore, in order to access liferay, it's required to know the container's IP address:

.. code-block:: bash

 $ docker container ls
 CONTAINER ID        IMAGE                      COMMAND                  CREATED             STATUS                   PORTS                                     NAMES
 c5a314b03efc        mysql:8.0                  "docker-entrypoint.s…"   24 hours ago        Up 2 minutes             3306/tcp, 33060/tcp                       04_files_database_1
 66e9c19850c0        liferay/portal:7.2.1-ga2   "/bin/sh -c /usr/loc…"   24 hours ago        Up 2 minutes (healthy)   8000/tcp, 8009/tcp, 8080/tcp, 11311/tcp   04_files_liferay_1
 c7723749c8d2        elasticsearch:6.5.4        "/usr/local/bin/dock…"   7 days ago          Up 2 minutes             9200/tcp, 9300/tcp                        04_files_search_1

 $ docker exec 04_files_liferay_1 ifconfig
 eth0      Link encap:Ethernet  HWaddr 02:42:AC:1B:00:03
           inet addr:172.27.0.3  Bcast:172.27.255.255  Mask:255.255.0.0
 ...

With this information, liferay service is accessible via http://172.27.0.3:8080

Once the first instance of the `liferay` service starts, you can scale it:

.. code-block:: bash

 docker-compose -f 13_liferay_cluster_mysql_es6.yml up -d --scale liferay=2

Watch the logs so that you get the container name for the second instance, then repeat the steps above to access that instance via IP address. You can then test cache replication as usual:

* Log in as test in both nodes
* In the first node, add an asset publisher portlet to the welcome page
* In the second node, reload the page. Assert asset publisher portlet is shown. Delete the portlet from the page
* In the first node, reload the page. Portlet should dissappear.


More features
-------------
Routing mesh, load balancing, sticky session vs tomcat session replication


