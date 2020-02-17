#!/usr/bin/env bash

. ./.env

docker stack rm $iteration

# note that docker stack rm does not delete volumes. To do so, uncomment the following:

# docker volume rm ${iteration}_volume_04-doclib
# docker volume rm ${iteration}_volume_04-elasticsearch_7.3.0
# docker volume rm ${iteration}_volume_04-mysql_8.0
