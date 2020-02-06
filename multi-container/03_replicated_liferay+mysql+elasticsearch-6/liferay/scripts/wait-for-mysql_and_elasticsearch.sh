#!/usr/bin/env bash
chmod a+x /opt/liferay/wait-for-it.sh
bash /opt/liferay/wait-for-it.sh -s -t 60 elasticsearch_03:9300
bash /opt/liferay/wait-for-it.sh -s -t 60 mysql_03:3306