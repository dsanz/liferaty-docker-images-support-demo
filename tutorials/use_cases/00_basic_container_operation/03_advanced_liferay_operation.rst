Running user-provided scripts in Docker Containers
==================================================

In this tutorial, we'll learn how to customize the liferay container without the need of creating images from the official ones.

Introducing the entry point's lifecycle
---------------------------------------

Before practising this topic, please make sure you read and understand the `The Liferay Container Lifecycle <https://grow.liferay.com/people/The+Liferay+Container+Lifecycle>`_. This piece of logic is unique to official Liferay images bundle, it's not present anywhere else.

As you can see, there are **4 extension points** where user can hook scripts. In all those 4 points, the entry point will examine specific directories and run whatever scripts are found there, in alphabetical order.

Hello world!
------------
Let's start by providing a PoC with the following script (hello-world.sh):

.. code-block:: bash

 echo "Hello from the container!"

Our goal is to run the above inside the container. For this purpose, we will leverage the hooking mechanisms provided by the Liferay images. Therefore, our goal can be reformulated as "to make the script available to the container in the specific folder where it expects user-scripts".

At this point, it's important to remember that there are `many ways <https://grow.liferay.com/people/The+Liferay+Container+Lifecycle#providing-files-to-the-container>`_ to make an external file available to the container. Furthermore, from the container's perspective, the choice of such mechanism is *irrelevant*: it's the availability of the file what matters.

The mechanism of our choice here is a `bind-mount <https://docs.docker.com/storage/bind-mounts/>`_. This makes a folder/file in the host available as a folder/file in the container, at a specific mount point.

To do this, please:

#. Download the file ``hello-world.sh`` in your laptop. You can clone this repository and use the provided one too.
#. ``cd`` into the folder where you downloaded it.
#. Run the container and specify the bind-mount for this file:

   .. code-block:: bash

    docker run --rm -it -v $(pwd)/hello-world.sh:/mnt/liferay/scripts/hello-world.sh --name liferay-test-script_0 liferay/dxp:7.2.10-dxp-4
    [LIFERAY] To SSH into this container, run: "docker exec -it 32ef2299ca83 /bin/bash".

    [LIFERAY] Using zulu8 JDK. You can use another JDK by setting the "JAVA_VERSION" environment varible.

    [LIFERAY] The directory /mnt/liferay/files does not exist. Create the directory $(pwd)/xyz123/files on the host operating system to create the directory /mnt/liferay/files on the container. Files in /mnt/liferay/files will be copied to /opt/liferay before Liferay DXP starts.

    [LIFERAY] Executing scripts in /mnt/liferay/scripts:

    [LIFERAY] Executing hello-world.sh.
    Hello from the container!

#. Stop the container by hitting ``Ctrl+C``, then delete it:

   .. code-block:: bash

    docker rm liferay-test-script_0

There are some things going on here. To begin, we're using the ``-v`` option, which tells the container we want to mount something into container's local filesystem. In this case, we used a direct file mount: rather than mounting the folder, we've just made a single file mapping between the host and the container.

To specify the full path of the file in the host machine, we've used ``$(pwd)/hello-world.sh``. The ``$(pwd)`` is a shell `command substitution <https://www.gnu.org/software/bash/manual/html_node/Command-Substitution.html>`_, which works by running the command (``pwd``, *print working directory* in this case) and substituting all the expression by the command output. As a result, if you downloaded the ``hello-world.sh`` file into ``/home/me/docker`` in your machine, then, what docker engine receives is:

.. code-block:: bash

   docker run --rm -it -v /home/me/docker/hello-world.sh:/mnt/liferay/scripts/hello-world.sh ...

This local file ``/home/me/docker/hello-world.sh`` in the host is mounted onto the container under the path ``/mnt/liferay/scripts/hello-world.sh``. The ``/mnt/liferay/scripts/`` is the place where container's entry point will look for scripts. Note that you may have chosen to provide a different name for the file in the container, like this:

.. code-block:: bash

  docker run --rm -it -v $(pwd)/hello-world.sh:/mnt/liferay/scripts/a.sh ...

In this case, for all purposes, the container will see a file called ``a.sh`` located in the ``/mnt/liferay/scripts/`` directory.

This example hooks ``hello-world.sh`` into a specific point in the container lifecycle. When the script gets run,

* The java version has already been set
* All other files provided to ``/mnt/liferay/files`` in the container have been copied into ``$LIFERAY_HOME``

However, at this point,

* Artifacts have not been deployed to liferay, meaning that there is not symlink created from the ``/mnt/liferay/deploy`` to ``$LIFERAY:HOME/deploy``
* No patch operations are performed yet

As you can see, this stage in the lifecycle takes place in the middle of the "cofigure" phase, so it can be used to verify/validate system configuration.

Hooking scripts in other phases
-------------------------------

Entry point defines 3 additional hooking points for user-provided scripts. At these points, the container directory is not ``/mnt/liferay`` but ``/usr/local/liferay/scripts/``. Reason for this is to allow separation of concerns: whereas ``/mnt/liferay`` is meant to be used via mount (bind or volume), the ``/usr/local/liferay/scripts/`` directory can be populated when building a child image as well. This does not preclude doing so via mount, indeed, we'll illustrate this feature using bind mounts.

The 3 additional points are ``pre-configure``, ``pre-startup`` and ``post-shutdown``:

* **Pre-configure** scripts are run before any configuration takes place. So it can be used for virtually any purpose. For instance, to download an specific version of the JVM/tomcat, set up encryption keys, check for external services availability, warm up resources, etc
* **Pre-startup** scripts are run after all configuration actions take place. At this point, the JVM, the tomcat and Liferay should be ready to run, meaning all configuration is in place, products are properly patched, plugins are ready to deploy at runtime, etc. Potential usages of this hook point would be to verify and log the overall configuration, cleanup unused files (e.g. zipped files, patching-tool separation, etc), verify external resource availability, or update database indexes (if patching-tool required that). Right after these scripts are run, tomcat is started.
* **Post-shutdown** scripts are run once tomcat is stopped, before finishing the entry point process. At this point, container is about to be stopped, so goal here is to clean up. For instance, free external resources that may have been used during portal operation or clean up unused files that will make the writeable layer lighter.

  To illustrate how this works, let's create and run a script to show the liferay configuration (please refer to log-liferay-config.sh, in this repo)

 .. code-block:: bash

   docker run -it -v $(pwd)/log-liferay-config.sh:/usr/local/liferay/scripts/pre-startup/log-config.sh --name liferay-dxp liferay/dxp:7.2.10-dxp-4



