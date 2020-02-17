#!/usr/bin/env bash

. ./.env

liferay_service_name="${iteration}_liferay"
number_of_liferay_instances=$(docker stack ps $iteration -q -f "name=${liferay_service_name}" -f "desired-state=running" | wc -l)

if (( number_of_liferay_instances > 1 ));
then
    number_of_liferay_instances=$(( number_of_liferay_instances - 1 ))
    echo "Scaling liferay service down to $number_of_liferay_instances instances, in detached mode"
    docker service scale -d ${liferay_service_name}=$number_of_liferay_instances
else
    echo "I'd rather prefer not to scale this below $number_of_liferay_instances instances. Thank you"
fi