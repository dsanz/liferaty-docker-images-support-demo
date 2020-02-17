#!/usr/bin/env bash

. ./.env

# Prerequisites:
#   * please make sure your docker engine is running in swarm mode. See https://docs.docker.com/engine/swarm/swarm-tutorial/ for details.
#   * note that a one-node swarm is enough to start
#   * Ensure no containers, volumes or networks created by docker-compose from this compose file are in place


# docker stack does not read the .env file as docker-compose does.
# This forces us to provide the environment variables in a more creative ways

# Method 1: provide a docker-compose file with substituted values. Requires docker-compose to be installed in the host machine, which may not be the case
#docker-compose config | docker stack deploy --compose-file - $namespace

# Method 2: put the .env file contents in the environment, then run. Does not require docker-compose
env $(cat .env | tr "\\n" " ") docker stack deploy --compose-file docker-compose.yml $iteration