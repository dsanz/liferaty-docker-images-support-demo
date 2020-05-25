Basic Container Operation
*************************

This tutorial will guide you through some basic operations that one can do with a docker container. We'll use Liferay images to illustrate, but keep in mind that this is valid for any docker image. This tutorial assumes that docker ce is installed in your system. Please refer to `Docker 101 - setup <https://grow.liferay.com/share/Docker+101+-+Setup>`_ for details.

You'll learn some concepts and how-tos. how to run a container, how to stop it, attached vs detached containers, port exposing and interactive containers.

.. contents::

Which image should I use?
-------------------------
Public docker images have a name and a tag which makes them unique. Please check `liferay image versions and traceability <https://grow.liferay.com/people/Liferay+Official+image+contents#liferay-images-versions-and-traceability>`_ for details. For the purposes of this tutorial, we'll focus on the dxp repository although most of the times, portal images would do fine too.

Generally speaking, you should use whatever version your customer is using. At the time of this writing, most recent dxp image is *liferay/dxp:7.2.10-sp2*

How do I run the container?
---------------------------
In order to run a liferay container we need let docker engine know what is the image we want to use, along with some other parameters that govern the container runtime behavior.

Let's try the simplest command to run a Liferay container:

.. code-block:: bash

	docker run -it -p 8080:8080 liferay/dxp:7.2.10-sp2

Running this has some effects on your system. Usually, one is not aware of such machinery as is it all condensed into a single docker command. Under the hoods, this is what happens:

1. If the image is not available locally, it will be pulled from the repository so that docker engine can use it.
2. If needed, a new container is created. This entails adding a writable layer on top of the image filesystem, attaching network to it, and some other things.
3. Then, the container is started, which means that its entry point is run. Entry point is responsible of running tomcat bundle and other stuff.

You'll see some image-specific logs, then the more familiar liferay startup logs. While server boots up, please take a moment to read what follows.

The ``-it`` flags make the container *interactive*. For Liferay containers, this means that you can stop the container by hitting Ctrl+C. This is a convenient mechanism for development/learning purposes, but it's not necessary at all for our customers in general.

The ``-p`` flag *publishes* the ports exposed by the container to the host machine. There are many options here, but in this form, port 8080 on your machine will be forwarded to the port 8080 on the container. This way, you don't need to know what is the container IP address to reach tomcat.

Time to access Liferay dxp. Open the browser of your choice and type
``http://localhost:8080``. 

So far, we've instructed docker to take an image (which is nothing but an application shipped in a particular way), create a new container from it and start the container in a way that we can interact with it via port 8080.

Let's stop the container by hitting ``Ctrl+C`` in your terminal window.

Which image should I use?
-------------------------
Public docker images have a name and a tag which makes them unique. Please check `liferay image versions and traceability <https://grow.liferay.com/people/Liferay+Official+image+contents#liferay-images-versions-and-traceability>`_ for details. For the purposes of this tutorial, we'll focus on the ``dxp`` repository although most of the times, images from the ``portal`` repo would do fine too.

Generally speaking, you should use whatever version your customer is using. At the time of this writing, most recent dxp image is *liferay/dxp:7.2.10-sp2*. However, it may be a bit tricky to know what's the right image to use.

About latest images for a given liferay version
-----------------------------------------------
Now that you know a way to run and stop containers, let's review what does "using liferay/dxp:7.2.10-sp2" image means. As detailed in  `liferay image versions and traceability <https://grow.liferay.com/people/Liferay+Official+image+contents#liferay-images-versions-and-traceability>`_, when you specify an image tag without a timestamp (such as ``liferay/dxp:7.2.10-sp2``) you're actually referring to the *latest* version of that image. As tagged images for liferay dxp 7.2 sp2 are pushed regularly to the repository, the *time* when you last pulled the image matters.

Bear in mind that images come with

Imagine that you were working on a customer issue 2 months ago. You made some tests with the liferay/dxp:7.2.10-sp2
Docker engine will not pull an image if it's already available locally!. Let's imagine you worked with 

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

