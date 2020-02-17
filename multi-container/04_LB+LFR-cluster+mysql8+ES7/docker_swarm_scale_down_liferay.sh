#!/usr/bin/env bash

number_of_liferay_instances=$(docker stack ps 03_liferay-cluster -q -f "name=03_liferay-cluster_liferay" -f "desired-state=running" | wc -l)

if (( number_of_liferay_instances > 1 ));
then
    number_of_liferay_instances=$(( number_of_liferay_instances - 1 ))
    echo "Scaling liferay service down to $number_of_liferay_instances instances, in detached mode"
    docker service scale -d 03_liferay-cluster_liferay=$number_of_liferay_instances
else
    echo "I'd rather prefer not to scale this below $number_of_liferay_instances instances. Thank you"
fi