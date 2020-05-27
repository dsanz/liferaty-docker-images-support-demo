Basic Container Operation
*************************

This tutorial will guide you through some basic operations that one can do with a docker container. We'll use Liferay images to illustrate, but keep in mind that this is valid for any docker image. This tutorial assumes that docker ce is installed in your system. Please refer to `Docker 101 - setup <https://grow.liferay.com/share/Docker+101+-+Setup>`_ for details.

You'll learn some concepts and how-tos. how to run a container, how to stop it, attached vs detached containers, port exposing and interactive containers.

.. contents::

How do I run the container?
===========================
In order to run a liferay container we need let docker engine know what is the image we want to use, along with some other parameters that govern the container runtime behavior.

Let's try the simplest command to run a Liferay container. Open a terminal window and run:

.. code-block:: bash

    docker run -it -p 8080:8080 liferay/dxp:7.2.10-sp2

Running this has some effects on your system. Usually, one is not aware of such machinery as is it all condensed into a single docker command. Under the hoods, this is what happens:

1. If the image is not available locally, it will be pulled from the repository so that docker engine can use it. This happens once for each image.
2. A new container is created. This entails adding a writable layer on top of the image filesystem, attaching network to it, giving the container a name, an internal id,and some other things.
3. Then, the container is started, which means that its entry point is run. Entry point is responsible of running tomcat bundle and other stuff.

Your terminal window will show some image-specific logs, then the more familiar liferay startup logs. While server boots up, please take a moment to read about the meaning of the command flags you just typed:

* The ``-it`` flags make the container *interactive*. For Liferay containers, this means that you can stop the container by hitting Ctrl+C. This is a convenient mechanism for development/learning purposes, but it's not necessary at all for our customers in general.
* The ``-p`` flag *publishes* the ports exposed by the container to the host machine. There are many options here, but in this form, port 8080 on your machine will be forwarded to the port 8080 on the container. This way, you don't need to know what is the container IP address to reach tomcat.

Time to access Liferay dxp. Open the browser of your choice and type
``http://localhost:8080``.

So far, we've instructed docker to take an image (which is nothing but an application shipped in a particular way), create a new container from it and start the container in a way that we can interact with it via port 8080.

Let's stop the container by hitting ``Ctrl+C`` in your terminal window.

How do I communicate with the container?
========================================
Although container is running in your machine, you don't have direct access to the container filesystem as it is managed by the docker engine. In addition, commands you run in your machine do not affect the container at all. As a result, the way one interacts with the liferay container changes a little bit as compared to a traditional setting.

We may use a variety of ways to communicate with the container:

* **Via networking**: this allows to reach services running inside the container via network ports. The immediate example is the Liferay portal itself, which can be reached via http port (8080) or AJP. But we might as well access the gogo shell (11311) or even set up a remote debugging session (any port above 1024)
* **Via docker commands**: docker engine provides some commands that can be run from the host machine to interact with a running container. Once you know the container name, it's possible to execute many commands directly on the container operating system.
* **Via bind mounts**: parts of the container filesystem can be associated to elements in the host machine filesystem. In the case of Liferay images, this allows to do things like patching the installation.

Following subsections explore some of the above options. You'll see how all the Liferay images use cases have to do with one or more of the above mechanisms.

How to refer to the container?
------------------------------
When a container is created, docker gives it an unique Id, also called the container name. This name can be provided by the user when running the container for the first time (``--name`` option in ``docker run``), as follows:

.. code-block:: bash

    docker run --name liferay-dxp -it -p 8080:8080 liferay/dxp:7.2.10-sp2

This creates and runs a container named ``liferay-dxp`` with the latest available release



How to know if container is running?
------------------------------------
Let's inquire the docker engine to know what is the list of running containers:


Can I run commands in the container?
------------------------------------

What if container ports are not exposed?
----------------------------------------

What if I don't want an interactive container?
----------------------------------------------
No problem!, docker provides commands to interact with running containers, no matter if they're started in an interactive way or not.

Naming containers
=================


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

* Liferay images come with `a few software <https://grow.liferay.com/people/Liferay+Official+image+contents>`_ besides the liferay bundle. More specifically, images contain some utility scripts and come with some default configurations.
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

If you go to the liferay/dxp repository, and `filter by tag <https://hub.docker.com/r/liferay/dxp/tags?page=1&name=7.2.10-dxp-4>`_, you'll see that there are a bunch of dxp-4 images. But only one has the `40d5b9` digest, corresponding to the `2020-03-23 timestamp <https://hub.docker.com/layers/liferay/dxp/7.2.10-dxp-4-202003230112/images/sha256-40d5b9869285d761872f1cc29bf47b442e57cdda12dec6b3777f6167594d9290?context=explore>`_. This means that you pulled the image between march, 23\ :sup:`rd`\  and march, 24\ :sup:`th`\ . In that time window, latest image (tagged with liferay/dxp:7.2.10-dxp-4) was pointing to that one. Right after march, 24\ :sup:`th`\ image was released, latest no longer pointed to the old one. Same liferay version, different logic in the build/utility scripts!

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

Finally, you can use ``-rm`` flag when creating a container so that it will be destroyed upon stop. This way

Let's review the takeaways so far:

* The concept of "latest" image changes with time. As tag name does not, docker will not pull the image if it's available locally, even if there's a newer one available in the repo.
* You may create a lot of containers for the same image. This situation is more common if you don't give a name to the containers, because docker will use a new name each time.
* It's a good practise to remove unused containers and images. An image can not be removed if it is used by a container, even if container is not running.