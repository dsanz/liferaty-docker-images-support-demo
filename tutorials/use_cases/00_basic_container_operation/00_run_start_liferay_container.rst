Basic Container Operation
=========================



This tutorial will guide you through some basic operations that one can do with a docker container. We'll use Liferay images to illustrate, but keep in mind that this is valid for any docker image. This tutorial assumes that docker ce is installed in your system. Please refer to `Docker 101 - setup <https://grow.liferay.com/share/Docker+101+-+Setup>`_ for details.

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


