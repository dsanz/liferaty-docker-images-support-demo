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

The first attempt to have multi-container service composition would roughly be about choosing a compatible database image (say, mysql) and add it as a new service, like `this <./04_files/02_liferay_mysql_bare.yml>`_:

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

All this information can be provided to the container via *environment variables*, which have their own place in the `docker-compose.yml <04_files/03_liferay_mysql_configured_DB.yml>`_:

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
By default, docker-compose creates a dedicated `bridge <https://docs.docker.com/network/bridge/>`_ network and makes it available to all containers, meaning that containers **in the same host** can see each other and access to the services in them without the need of exposing ports. That's the reason why mysql port (3309) is not exposed in the container, as it's not required to access mysql from outside the composition.

We are going to create a new network for our composition to showcase the syntax. One can create several networks in a given composition, and make them available to the containers at discretion. This will affect the number of network interfaces and routing rules configured for each container.

Network driver will use the **bridge** driver as all the examples are meant to run in a single docker host. This tutorial is not covering the cases where many docker hosts run a composed application, in which case, the *overlay* driver should be used.

To create a network, add its name into the ``networks`` section. Optionally, set the ``driver`` to use. Then, reference it from the containers which should use that network. That's an excellent chance to give a host name to the container *in that network* via the ``aliases`` directive. The result would look like this:

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

Communicating both containers: liferay configuration
----------------------------------------------------
Now that containers *are* in a network with specified host names, it's time to configure liferay to use the database service. Note that this is not a **service-level** configuration (such as the name of the available networks, the ports, the alias, or the service name), but an **application-level** configuration, which is specific to the apps shipped with the container.

In the case of Liferay, this configuration is traditionally provided via ``portal-ext.properties`` file. That's a perfectly valid solution, however, it forces us to add an extra file to the container via bind mount, and ensure those properties get updated if the docker-compose file changes. Fortunately, Liferay also provides a mechanism based on *environment variables* with specific names, which overrides portal properties.

This is very suitable for container settings, because it allows to pass portal properties from the docker host environment as follows (`source <04_files/05_liferay_mysql_connected.yml>`_):

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
* Database *port* (3306) is *reachable* from the liferay container even if it's not exposed by the service, because the database service is in the same network as the liferay service

The last element we need is to configure the bind-mount into the liferay container. Time use the ``volumes`` directive to bind-mount our file structure onto the liferay container:

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

Subsequent runs of the above composition will be faster because ``docker-compose`` tries to reuse the containers if the configuration does not change. This means that they will be *started* rather than new ones being created. docker-compose informs what specific operation is doing to the containers:

* **Creating** means that the container did not exist in the docker host previously, so it will be created and run for the first time.
* **Recreating** means that container already exists in the docker host and it's stopped. Its configuration in the docker-compose.yml has changed so the container can not be started again. Therefore, it is removed, then re-created with the same name and new options.
* **Starting** means that the container already exists in the docker host, it's stooped, and its configuration did not change from the previous run, so it can be started with the same options. In this case, writeable layer is kept.

By default, database container will store database files on the container writeable layer. This is not particular for the database service. Any container which modifies files originally present in the image will create a copy of them in the writeable layer. This has 2 implications:

* **Performance**: container filesystems are *layered* meaning that they store the files in separate areas (layers) and use a `Copy On Write <https://docs.docker.com/storage/storagedriver/#the-copy-on-write-cow-strategy>`_ strategy, good to save space, not as performant as the native filesystem.
* **Lifetime**: writeable layer is disposed when container is removed. Although it's kept when container is stopped (allowing restarting it), container management tools may delete containers along with their data.

As you may have guessed from the above statements, relying on the writable layer of the container to store the database tables seems not the best idea: database files shall be stored outside of the container filesystem for optimum performance and to enable container disposability. This can be done by delegating the storage of a specific directory in the container to an external storage device (see `Providing files to the container <https://grow.liferay.com/people/The+Liferay+Container+Lifecycle#providing-files-to-the-container>`_ for details).

We'll leverage docker-compose to create and manage a **volume**, which will be mounted on the ``/var/lib/mysql`` directory in the container. That directory is the place where mysql stores all database files. This time, we'll not use a bind mount but a real volume, which requires some extra directives:

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
The last step in this section addresses the problem of ensuring consistency across the docker-compose file via variables. Some of the named elements we've used across the previous sections can be specified using variables. More specifically, the values we give to the yaml keys.

.. code-block:: diff

  version: '3'
  services:
    liferay:
      image: liferay/portal:7.2.1-ga2
      environment:
        LIFERAY_JDBC_PERIOD_DEFAULT_PERIOD_DRIVER_UPPERCASEC_LASS_UPPERCASEN_AME: com.mysql.cj.jdbc.Driver
 +      LIFERAY_JDBC_PERIOD_DEFAULT_PERIOD_URL: jdbc:mysql://database:3306/${mysql_database_name}?useUnicode=true&characterEncoding=UTF-8&useFastDateParsing=false
 -       LIFERAY_JDBC_PERIOD_DEFAULT_PERIOD_URL: jdbc:mysql://database:3306/lportal?useUnicode=true&characterEncoding=UTF-8&useFastDateParsing=false
 +      LIFERAY_JDBC_PERIOD_DEFAULT_PERIOD_USERNAME: ${mysql_user_name}
 -      LIFERAY_JDBC_PERIOD_DEFAULT_PERIOD_USERNAME: mysqluser
 +      LIFERAY_JDBC_PERIOD_DEFAULT_PERIOD_PASSWORD: ${mysql_user_password}
 -      LIFERAY_JDBC_PERIOD_DEFAULT_PERIOD_PASSWORD: test
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
 +      MYSQL_DATABASE: ${mysql_database_name}
 -      MYSQL_DATABASE: lportal
 +      MYSQL_USER: ${mysql_user_name}
 -      MYSQL_USER: mysqluser
 +      MYSQL_PASSWORD: ${mysql_user_password}
 -      MYSQL_PASSWORD: test
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

Besides consistency, using variables avoids hardcoding valiues which may not need to be preset or even made public (like passwords). Please note that there are more advanced ways to share secrets between containers, which are out of the scope of this tutorial.

So, where are those variables taken from? ``docker-compose`` reads a `.env <./04_files/.env>`_ file which must be in the same folder where docker-compose is run. This mechanism is called `default environment variable declaration <https://docs.docker.com/compose/env-file/>`_ and is based on `variable substitution <https://docs.docker.com/compose/compose-file/#variable-substitution>`_ at the ``docker-compose`` file level. In other words, these variables are not passed to the services as part of the container environment. Please note this is a docker-compose unique feature.

So, in this case, the .env file would look like this:

.. code-block:: bash

mysql_user_name=mysqluser
mysql_user_password=test
mysql_database_name=lportal

Finally, please remember to run this from the place where the .env file is, otherwise, docker-compose won't find it:

.. code-block:: bash

 $ /04_files [master]$ docker-compose -f 08_liferay_mysql_with_variables.yml up


