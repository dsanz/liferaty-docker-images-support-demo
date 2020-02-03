The simplest multi-container application starts 2 containers using basic docker compose features.

Goal
To connect Liferay to a predefined mysql database running in separate containers

Challenges:
* Do not create child images unless strictly needed: use env vars and mounts where possible
* Tell mysql to create the DB if it does not exist
    * Set MYSQL_DATABASE env var
* Make liferay aware of where database is
    * Use env vars to tell mysql the DB name and credentials
    * Provide portal-ext.properties via mount
* Ensure mysql is ready to work when Liferay connects to it
    * Provide custom script to the liferay container that waits for some seconds (less reliable)
     