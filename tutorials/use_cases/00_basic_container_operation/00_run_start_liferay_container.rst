Basic Container Operation
*************************

This tutorial will guide you through some basic operations that one can do with a docker container. We'll use Liferay images to illustrate, but keep in mind that this is valid for any docker image. This tutorial assumes that docker ce is installed in your system. Please refer to `Docker 101 - setup <https://grow.liferay.com/share/Docker+101+-+Setup>`_ for details.

You'll learn some concepts and how-tos. Particularly, how to run a container, how to stop it, the difference between attached and detached containers, what is "expose a port" and how to select the right 'latest' image to use, among other things.

.. contents::

How do I run the container?
===========================
To run a liferay container, we need to let docker know what is the image we want to use, along with some other parameters that govern the container runtime behavior.

Let's try the simplest command to run a Liferay container. Open a terminal window and run:

.. code-block:: bash

    docker run -it -p 8080:8080 liferay/dxp:7.2.10-sp2

Running this has some effects on your system. Usually, one is not aware of such machinery as is it all condensed into a single docker command. Under the hoods, this is what happens:

1. If the image is not available locally, it will be **pulled** from the repository so that docker engine can use it. This happens once for each image.
2. A **new container** is created. This entails adding a writable layer on top of the image filesystem, attaching network to it, giving the container a name, an internal id, and some other things.
3. Then, the container is started, which means that actual resources (such as memory and CPU) are allocated for the new process, and then its **entry point** logic is run. Entry point is provided by the image and is responsible of running tomcat bundle and other stuff.

Your terminal window will show some image-specific logs, then the more familiar liferay startup logs. While server boots up, please take a moment to read about the meaning of the command flags you just typed:

* The ``-it`` flags make the container *interactive*. For Liferay containers, this means that you can stop the container by hitting Ctrl+C. This is a convenient mechanism for development/learning purposes, but it's not necessary at all for our customers in general.
* The ``-p`` flag *publishes* the ports exposed by the container to the host machine. There are many options here, but in this form, port 8080 on your machine will be forwarded to the port 8080 on the container. This way, you don't need to know what is the container IP address to reach tomcat.

Time to access Liferay dxp. Open the browser of your choice and type
``http://localhost:8080``.

So far, we've instructed docker to take an image (which is nothing but an application shipped in a particular way), create a new container from it and start the container in a way that we can interact with it via port 8080.

Let's stop the container by hitting ``Ctrl+C`` in your terminal window.

How do I communicate with the container?
========================================
Although container is running in your machine, you don't have direct access to the container filesystem as it is managed by the docker engine. In addition, regular commands you run in your machine do not affect the container at all. As a result, the way one interacts with the liferay container changes a little bit as compared to a traditional setting.

We may use a variety of ways to communicate with the container:

* **Via networking**: this allows to reach services running inside the container via network ports. The immediate example is the Liferay portal itself, which can be reached via http port (8080) or AJP. But we might as well access the gogo shell (11311) or even set up a remote debugging session (any port above 1024)
* **Via docker commands**: docker engine provides some commands that can be run from the host machine to interact with a running container. Once you know the container name, it's possible to execute many commands directly on the container operating system.
* **Via bind mounts**: parts of the container filesystem can be associated to elements in the host machine filesystem. In the case of Liferay images, this allows to do things like patching the installation.
* **Via attaching standard IO**: container IO files (stdin/stdout/stderr) can be attached to a terminal which we can interact with from the host machine. This technique is commonly used together with the ability to run commands in the container, which provides (almost) full control of the container.

Following subsections explore some of the above options. Others will be described in subsequent tutorials. You'll see how all the Liferay images use cases have to do with one or more of the above mechanisms.

How to refer to the container?
------------------------------
When a container is created, docker gives it an unique Id. It also assigns a name to it, which is (somehow) random if you don't specify one. Although it's perfectly fine to use the id, it's hard to memorize, so you may want to use its name. Moreover, it's possible to give a name when running the container for the first time, as follows:

.. code-block:: bash

    docker run --name liferay-dxp -it -p 8080:8080 liferay/dxp:7.2.10-dxp-4

This creates and runs a container named ``liferay-dxp`` with the latest available release. We'll talk about what ``latest`` mean later on.

Let's inquire the docker engine the list of running containers. You should know that there are 2 equivalent commands for this purpose: ``docker ps`` and ``docker container ls``.

By default, these commands show running containers. If you're fast enough, you'll witness the startup phase of the container:

.. code-block:: bash

    $ docker ps
    CONTAINER ID        IMAGE                      COMMAND                  CREATED             STATUS                             PORTS                                                   NAMES
    a7735acbee48        liferay/dxp:7.2.10-dxp-4   "/bin/sh -c /usr/loc…"   27 seconds ago      Up 26 seconds (health: starting)   8000/tcp, 8009/tcp, 11311/tcp, 0.0.0.0:8080->8080/tcp   liferay-dxp

In this example, you may refer to this container either by giving its id (``a7735acbee48``) or its name (``liferay-dxp``). An use case where the container id/name needs to be specified is when running docker commands affecting your container.

How to know if container is running?
------------------------------------
Output of previous command shown that container status is "up" and the health indicator says ``starting``. We'll not cover that in this tutorial, so for now just keep in mind that the automatic checks that docker executes to determine what's the status of the container have not started yet. By default, these checks wait for 1 minute to give time to the tomcat to start up Liferay DXP.

We're primarily interested in knowing the status of the running container, and perhaps some additional information such as the published ports or even the image container is using.

.. code-block:: bash

    $ docker ps
    CONTAINER ID        IMAGE                      COMMAND                  CREATED             STATUS                   PORTS                                                   NAMES
    a7735acbee48        liferay/dxp:7.2.10-dxp-4   "/bin/sh -c /usr/loc…"   7 minutes ago       Up 7 minutes (healthy)   8000/tcp, 8009/tcp, 11311/tcp, 0.0.0.0:8080->8080/tcp   liferay-dxp

After some time, container should become healthy. Please note that liferay may be able to serve requests a bit earlier than the first health check takes place.

If you have more than one container running, you'll have to pay attention to which one you're interested in. You can also filter the listing a little bit with the ``-f`` flag as it will be shown in `Keeping your house clean: removing images and containers`_.

What if container ports are not exposed? Getting the container's IP
-------------------------------------------------------------------
All examples so far deal with containers which expose ports to the host machine. This is a convenience mechanism to *borrow* host machine ports and dedicate them to forward traffic to the container. That's great for dev environments as it allows to use localhost as if it were the container IP address.

In other cases, containers may not expose their ports. This does not mean that liferay server can't be accessed, it just means that one has to use the container hostname or IP address to connect to it, rather than "localhost" or any local IP address assigned to the host machine networking system.

Effectively, docker manipulates host networking system to create the necessary rules (such as name resolution) in a way that container can be accessed as if it were a completely separate machine.

Let's find out what's the container's IP address. There are several ways to do this, we'll use the command ``docker inspect``, which shows detailed information about a container. As we're interested in the IP address only, we'll filter out the output a little bit:

.. code-block:: bash

    $ docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' liferay-dxp
    172.17.0.3

Now, run this command in your machine and type http://<IP address>:8080 in your browser.

A last note: a container may have more than one network attached. In this case, it is not guaranteed that all of the available IPs will accept connections.

What if I don't want an interactive container?
----------------------------------------------
No problem!, docker provides commands to interact with running containers, no matter if they're started in an interactive way or not.


How to run commands in the container?
=====================================
It's possible to execute commands in the container, meaning run any available command in the container's operating system. This is achieved by running the ``docker exec`` command in the host machine. As you may guess, this has a big potential, which we'll illustrate here.

Let's start by running a very simple, yet illustrative command to get the current working directory in the container:

.. code-block:: bash

    $ docker exec liferay-dxp pwd
    /opt/liferay

As you can see, the returned value is the container's working directory, and not the host's one.

The above command just returns control to the host machine, in other words, it's not interactive. We can have more advanced scenarios which may be quite useful to troubleshoot issues. Following subsections describe the most common ones.

Passing parameters to the command: how to get the container process list
------------------------------------------------------------------------
If your command needs parameters, just append them to the docker exec invocation. Let's ask the process list of the container with some specific fields:

.. code-block:: bash

    $ docker exec liferay-dxp ps -o pid,ppid,user,args
    PID   PPID  USER     COMMAND
        1     0 liferay  {liferay_entrypo} /bin/bash /usr/local/bin/liferay_entrypoint.sh
        7     1 liferay  {start_liferay.s} /bin/bash /usr/local/bin/start_liferay.sh
        8     7 liferay  /usr/lib/jvm/zulu8/bin/java -Djava.util.logging.config.file=/opt/liferay/tomcat/conf/logging.properties -Djava.util.logging.manager=org.apache.juli.ClassLoaderLogManager -Djdk.tls.ephemeralDHKeySize=2048 -Djava.protocol.handler.pkgs=org.apache.catalina.webresources -Dorg.apache.catalina.security.SecurityListener.UMASK=0027 -Dfile.encoding=UTF-8 -Djava.locale.providers=JRE,COMPAT,CLDR -Djava.net.preferIPv4Stack=true -Duser.timezone=GMT -Xms2560m -Xmx2560m -XX:MaxNewSize=1536m -XX:MaxMetaspaceSize=768m -XX:MetaspaceSize=768m -XX:NewSize=1536m -XX:SurvivorRatio=7 -Dignore.endorsed.dirs= -classpath /opt/liferay/tomcat/bin/bootstrap.jar:/opt/liferay/tomcat/bin/tomcat-juli.jar -Dcatalina.base=/opt/liferay/tomcat -Dcatalina.home=/opt/liferay/tomcat -Djava.io.tmpdir=/opt/liferay/tomcat/temp org.apache.catalina.startup.Bootstrap start
    13992     0 liferay  ps -o pid,ppid,user,args

There are some interesting information here:

* First process (pid 1) is in charge of running the entry point. It's the first process run by the container.
* Second process (pid 7) is a script aimed at starting the tomcat. We know this is a child process of the entry point (ppid is 1)
* Third process (pid 8) is the JVM running tomcat, which was in turn launched from the process with pid 7
* Fourth process is the ps command we just ran from the host via ``docker exec``. As you can see, it contains all the arguments you passed to it
* All processes are owned by ``liferay`` user

Piping into container's command: how to take a thread dump
----------------------------------------------------------
You just saw how parameters can be passed to the command, however, the standard piping mechanisms are still governed by the host's operating system. Let us illustrate this with the command we'd use to take a thread dump:

.. code-block:: bash

    $ docker exec liferay-dxp pgrep -of tomcat | xargs kill -3
    kill: (8): Operation not permitted

The above command is trying to send the -3 signal to the process running the JVM in the container, in order to have it send a thread dump to the JVM standard output. The logic is:

* ``pgrep -f tomcat`` outputs the pid of the system process(es) which command contains the string "tomcat". That's a bit tricky, because at the moment we invoke it in the liferay container, there are 2 matching processes:

  * The process running tomcat. As we saw earlier, that is the process with pid 8.
  * The process running the ``pgrep``, which includes "tomcat" in its args

* We add the ``-o`` option to pgrep to only show the older pid, which for sure is the tomcat one.
* Then we pipe that pid number to the xargs, which transforms it into a regular parameter to what comes next: ``kill -3`` will therefore become ``kill -3 8``

However, we got an error and the thread dump is not being shown. What went wrong here?

The answer relies on *who* is running the kill command. One may think that it's being run by the container. However, above invocation makes the **host** to run the kill command. So you're basically trying to kill the process with pid 8 in the host, not in the container, hence the ``Operation not permitted`` error.

So how do we ensure that piping is happening in the container? We need to send the entire command with the piping to the next command, to the container. We can do that if we ask the container to run an shell interpreter and pass everything to the interpreter, as follows:

.. code-block:: bash

    $ docker exec liferay-dxp bash -c 'pgrep -of tomcat | xargs kill -3'

This is running the bash interpreter and instructing it to run a command. All of that command (including the pipe) happens now in the container.

A similar thing happens in the case of using other shell features like **environment variables** and **command substitution**. We must ensure we're using the variable value in the container and the command substitution takes place in the container too. Let's illustrate this in the following bonus exercises.

**Bonus exercise 1**. Explain why these two commands return different things

.. code-block:: bash

    $ docker exec liferay-dxp bash -c 'echo $JAVA_HOME'

and

.. code-block:: bash

    $ docker exec liferay-dxp echo $JAVA_HOME

**Bonus exercise 2**. Perhaps you noticed we used xargs to provide the pid to the kill command above, and wondered why do not send it directly, with a command substitution like ``kill -3 $(pgrep -of tomcat)``.
Explain why, even if we are delimiting the full command to execute in the container, results of the first pair of commands are different, whereas results of the second pair of commands is the same:

.. code-block:: bash

    $ docker exec liferay-dxp bash -c 'kill -3 $(pgrep -of tomcat)'
    $ docker exec liferay-dxp bash -c "kill -3 $(pgrep -of tomcat)"


.. code-block:: bash

    $ docker exec liferay-dxp bash -c 'pgrep -of tomcat | xargs kill -3'
    $ docker exec liferay-dxp bash -c "pgrep -of tomcat | xargs kill -3"


Running an interactive shell into the container
-----------------------------------------------

The above is still non interactive


Stopping the containers
=======================

Which image should I use?
=========================
Public docker images have a name and a tag which makes them unique. Please check `liferay image versions and traceability <https://grow.liferay.com/people/Liferay+Official+image+contents#liferay-images-versions-and-traceability>`_ for details. For the purposes of this tutorial, we'll focus on the ``dxp`` repository although most of the times, images from the ``portal`` repo would do fine too.

Generally speaking, you should use whatever version your customer is using. At the time of this writing, most recent dxp image is *liferay/dxp:7.2.10-sp2*. However, it may be a bit tricky to know what's the right image to use.

About latest images
-------------------
As detailed in  `liferay image versions and traceability <https://grow.liferay.com/people/Liferay+Official+image+contents#liferay-images-versions-and-traceability>`_, when you specify an image tag without a timestamp (such as ``liferay/dxp:7.2.10-sp1`` as opposed to ``liferay/dxp:7.2.10-sp1-202003230055``) you're actually referring to the *latest* version of that image. Let's review what does this mean.

To better understand what follows, please bear in mind that:

* Liferay images come with `a few software <https://grow.liferay.com/people/Liferay+Official+image+contents>`_ besides the liferay bundle. More specifically, images contain some utility scripts (most notably, the image's *entry point*) and come with some default configurations.
* For a given liferay version, several images are pushed to the repository. In this process:

  * Each new image is pushed with a new timestamp.
  * Even if the liferay bundled in it is the same, the utility scripts and/or default configs may differ.
  * A new image without a timestamp is pushed, pointing to the one with the latest timestamp.

* When running a container, docker engine will not pull an image if it's already available locally

It follows that the *time* when you last pulled the image matters. Let's see this with an example.

Imagine that you were working on a customer around mid march 2020. You made some tests with the latest `liferay/dxp:7.2.10-dxp-4 <https://hub.docker.com/r/liferay/dxp/tags?page=1&name=7.2.10-dxp-4>`_ image, which is the one your customer claims to use. Two months later, a customer reports an issue while utilizing the latest 7.2.10-dxp-4 image again. You go back to your docker engine and in this case, you're unable to reproduce the issue. How this can be possible?

Let's take a look to which images do you have in your docker engine. Let's kindly ask docker to print the image digest as well:

.. code-block:: bash

    $ docker image ls --digests liferay/dxp
    REPOSITORY          TAG                 DIGEST                                                                    IMAGE ID            CREATED             SIZE
    liferay/dxp         7.2.10-dxp-4        sha256:40d5b9869285d761872f1cc29bf47b442e57cdda12dec6b3777f6167594d9290   941328315cb7        2 months ago        1.19GB

If you go to the liferay/dxp repository, and `filter by tag <https://hub.docker.com/r/liferay/dxp/tags?page=1&name=7.2.10-dxp-4>`_, you'll see that there are a bunch of dxp-4 images. But only one has the `40d5b9` digest, corresponding to the `2020-03-23 timestamp <https://hub.docker.com/layers/liferay/dxp/7.2.10-dxp-4-202003230112/images/sha256-40d5b9869285d761872f1cc29bf47b442e57cdda12dec6b3777f6167594d9290?context=explore>`_. This means that you pulled the image between march, 23\ :sup:`rd`\  and march, 24\ :sup:`th`\ . In that time window, latest image (tagged with liferay/dxp:7.2.10-dxp-4) was pointing to that one. Right after march, 24\ :sup:`th`\  image was released, latest no longer pointed to the old one. Same liferay version, different logic in the build/utility scripts!

We're eager to help our customer, so first of all, let's pull the same image again:

.. code-block:: bash

    $ docker pull liferay/dxp:7.2.10-dxp-4
    7.2.10-dxp-4: Pulling from liferay/dxp
    89d9c30c1d48: Already exists
    9770148b41fb: Already exists
    ddfd35e29cd0: Pull complete
    a744eb453a3e: Pull complete
    dd545718e994: Pull complete
    87b8b05414eb: Pull complete
    a3d31bf0cc95: Pull complete
    Digest: sha256:1b22f4c852f464dd4a9ae33d30fe156f6b255bbee106f1b84389ae2d5b532eaa
    Status: Downloaded newer image for liferay/dxp:7.2.10-dxp-4
    docker.io/liferay/dxp:7.2.10-dxp-4

As you can see, there's a bunch of downloaded layers in this pull operation. Now, we can use the brand new image in our container:

.. code-block:: bash

    docker run -it -p 8080:8080 liferay/dxp:7.2.10-dxp-4

Note how this is the very same command we ran before. The difference is that now we're running a different container, with a different image.

Keeping your house clean: removing images and containers
--------------------------------------------------------

Now that we realized our *latest* image is outdated, we know that the containers we have created from this image are also outated. So we're interested in getting rid of these images and containers to save some disk space. We need, therefore, to be more explicit about what do we want to use and keep.

Let's see what do we have now:

.. code-block:: bash

    $ docker image ls --digests liferay/dxp
    REPOSITORY          TAG                 DIGEST                                                                    IMAGE ID            CREATED             SIZE
    liferay/dxp         7.2.10-dxp-4        sha256:1b22f4c852f464dd4a9ae33d30fe156f6b255bbee106f1b84389ae2d5b532eaa   27a9f5513491        8 weeks ago         1.19GB
    liferay/dxp         <none>              sha256:40d5b9869285d761872f1cc29bf47b442e57cdda12dec6b3777f6167594d9290   941328315cb7        2 months ago        1.19GB

As we have 2 instances of the *same* image, docker can't use the same tag for both.



You may choose to delete the older one by providing the image id, which is an internal id assigned by docker:

.. code-block:: bash

    $ docker image rm 941328315cb7
    Error response from daemon: conflict: unable to delete 941328315cb7 (must be forced) - image is being used by stopped container 4946d54260d3

Here, you can see how Docker warns about an existing container. Indeed, **image cannot be deleted it is being used by a container**. Reason is that docker re-uses all the image filesystem when creating a container by just adding the writeable layer on top of it, meaning that the image contents are an integral part of the filesystem made available to the container. As containers are meant to be transient, it's safe to delete it.

So, we need to know how many containers we've created for a given image. The ``docker ps`` command lists containers, but we'll need to pass some parameters to get what we want. To begin, we have to tell docker ps that we want all containers (not only the running ones), we'll do that with the ``-a`` option. Also, we have to filter them by image with the ``-f`` option, which accepts different filters. Keep in mind that the image we're interested in does not have a tag so we must use the image id directly. The ``ancestor`` filter will do the trick:

.. code-block:: bash

    $ docker ps -a -f "ancestor=941328315cb7"
    CONTAINER ID        IMAGE               COMMAND                  CREATED             STATUS                      PORTS               NAMES
    f400f0dd7347        941328315cb7        "/bin/sh -c /usr/loc…"   7 weeks ago         Exited (0) 7 weeks ago                          happy_pascal
    0f91f6bda64d        941328315cb7        "/bin/sh -c /usr/loc…"   8 weeks ago         Exited (0) 8 weeks ago                          vigilant_meitner
    f4114542b6e9        941328315cb7        "/bin/sh -c /usr/loc…"   2 months ago        Exited (137) 8 weeks ago                        naughty_galois
    6b051414c8f2        941328315cb7        "/bin/sh -c /usr/loc…"   2 months ago        Exited (0) 2 months ago                         pedantic_cori
    2764d935b358        941328315cb7        "/bin/sh -c /usr/loc…"   2 months ago        Exited (0) 2 months ago                         romantic_mestorf
    e7e82ae15a67        941328315cb7        "/bin/sh -c /usr/loc…"   2 months ago        Exited (0) 2 months ago                         flamboyant_pascal
    18d21c1cfd45        941328315cb7        "/bin/sh -c /usr/loc…"   2 months ago        Exited (0) 2 months ago                         magical_goldstine
    47f9ed998bbb        941328315cb7        "/bin/sh -c /usr/loc…"   2 months ago        Exited (0) 2 months ago                         jovial_maxwell
    f8e6a3416f22        941328315cb7        "/bin/sh -c /usr/loc…"   2 months ago        Exited (0) 2 months ago                         cranky_mcnulty
    294397041f98        941328315cb7        "/bin/sh -c /usr/loc…"   2 months ago        Exited (137) 2 months ago                       cool_taussig


Those look too many to do manual removal, let's instruct docker to remove all of them in a single line:

.. code-block:: bash

    $ docker container rm $(docker ps -a -q -f "ancestor=941328315cb7")
    f400f0dd7347
    0f91f6bda64d
    f4114542b6e9
    6b051414c8f2
    2764d935b358
    e7e82ae15a67
    18d21c1cfd45
    47f9ed998bbb
    f8e6a3416f22
    294397041f98


The ``-q`` flag just outputs the container ids, which is just what docker container rm expects.

Finally, we can delete the image:

.. code-block:: bash

    $ docker image rm 941328315cb7
    Untagged: liferay/dxp@sha256:40d5b9869285d761872f1cc29bf47b442e57cdda12dec6b3777f6167594d9290
    Deleted: sha256:941328315cb77e280e89330b57055c7606182d694f51ff6d91bd6f5a3363cc81
    Deleted: sha256:a9d8cd3244737cd3f8f27b6a806e8bb5714eedbed31607dbddc15c34634b19aa
    Deleted: sha256:8c2f7f363c361d7743118430424d55071e56e56d5b8e89ee1b4c6050a4fa57c8
    Deleted: sha256:afaaf32bdfdd903569a06de98fca1f87e51f235359db280b4b3d9522ec5d906c
    Deleted: sha256:974cc03ce63766d0593065ef2818d0a56e532ee665f5d6a4861f61327f8a37fc
    Deleted: sha256:434b2628b2545faa9ae68c8ff0c61bbe38fccc069fe1a76f067889b5e09d4862
    $ docker image ls --digests liferay/dxp
    REPOSITORY          TAG                 DIGEST                                                                    IMAGE ID            CREATED             SIZE
    liferay/dxp         7.2.10-dxp-4        sha256:1b22f4c852f464dd4a9ae33d30fe156f6b255bbee106f1b84389ae2d5b532eaa   27a9f5513491        8 weeks ago         1.19GB

You can always pull it again by providing the full timestamp or the digest.

Finally, you can use ``-rm`` flag when creating a container so that it will be destroyed upon stop.

Let's review the takeaways so far:

* The concept of "latest" image changes with time. As tag name does not, docker will not pull the image if it's available locally, even if there's a newer one available in the repo.
* You may create a lot of containers for the same image. This situation is more common if you don't give a name to the containers, because docker will use a new name each time.
* It's a good practise to remove unused containers and images. An image can not be removed if it is used by a container, even if container is not running.