Liferay in a multi container setting
====================================

This tutorial will enable reader to understand and run simple examples of multicontainer applications where Liferay plays a central role.

Bye Liferay container, hello Liferay service
--------------------------------------------
If reader followed the previous tutorials, or the skillmap use cases (except for the ones dealing with multicontainer settings), the mechanism to illustrate how to run a container was

.. code-block:: bash

 docker run <options> <image>

Running a (docker) command in the host is nothing but exercising the `Docker Client CLI API <https://docs.docker.com/engine/reference/commandline/cli/>`_. This is just one of many ways to run containers.

When your application needs *different* containers (say, the Liferay and some mysql as a DB server), then working with the CLI starts to be a hard task: both containers need to be provided with same network settings so that they can talk to each other, they should start at the same time, status needs to be monitored for each container, etc.

These, amongst others, were the reasons to develop container orchestrators. What if, rather than direct commands, we could describe the **desired system state** in a *declarative way*, by providing some sort of descriptor?.

Imagine such file descriptor for the ``docker run`` command above:

.. code-block:: bash

 <image 1>:
     <options for image 1>
 <image 2>:
     <options for image 2>

And now imagine we can run the orchestrator using that descriptor file, and the orchestrator takes care of managing such services by creating the required containers with the right options, monitoring them, stopping them, etc.

That's the essence of what we're about to discover in this tutorial. You would no longer work with containers, but with **services** you declare, with given properties, resources and desired state. Let the orchestrator do the rest.