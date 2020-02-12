#!/usr/bin/env bash

docker stack rm 03_liferay-cluster

# note that docker stack rm does not delete volumes. To do so, uncomment the following:

# docker volume rm 03_liferay-cluster_volume_03-doclib
# docker volume rm  03_liferay-cluster_volume_03-elasticsearch_6.5.4
# docker volume rm  03_liferay-cluster_volume_03-mysql_8.0
