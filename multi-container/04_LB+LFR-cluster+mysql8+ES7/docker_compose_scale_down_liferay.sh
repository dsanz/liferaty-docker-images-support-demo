#!/usr/bin/env bash

number_of_liferay_instances=$(docker-compose ps -q liferay | wc -l)

if (( number_of_liferay_instances > 1 ));
then
    number_of_liferay_instances=$(( number_of_liferay_instances - 1 ))
    echo "Scaling liferay service down to $number_of_liferay_instances instances, in detached mode"
    docker-compose up -d --scale liferay=$number_of_liferay_instances
else
    echo "I'd rather prefer not to scale this below $number_of_liferay_instances instance. Thank you"
fi