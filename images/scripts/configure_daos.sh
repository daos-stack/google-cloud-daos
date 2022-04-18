#!/bin/bash
# Copyright 2021 Google LLC
# Copyright (C) 2021 Intel Corporation. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#set -x

if [[ $# != 2 ]]; then
    echo This command expects 2 arguments
    echo "configure_daos.sh  <number_of_server_instances> \"daos-server-0001[-XXXX]\""
    exit
fi

instances=$1
servers=$2

if [ `hostname` != "daos-server-0001" ]; then
    echo Not runing on daos-server-0001 exiting now
    exit
fi

echo Runing on daos-server-0001 starting the DAOS Client

systemctl start daos_agent
systemctl enable daos_agent
## Format DAOS
sleep 20
FIRST=`dmg network scan | grep daos | cut -d '-' -f 3 | sed 's/[^0-9]*//g'`
LAST=`dmg network scan | grep daos | cut -d '-' -f 4 | sed 's/[^0-9]*//g'`


FINAL=`printf %04d ${instances}`

if [ ${instances} -gt 1 ]; then

	printf "%s" "Waiting for DAOS Servers to start on ${instances} servers"
	
	while true 
	do 
		LAST=`dmg network scan | grep daos | cut -d '-' -f 4 | sed 's/[^0-9]*//g'`
		if [[ "${LAST}" == "${FINAL}" ]]; then  
    			echo All DAOS Servers started
			break
		fi
  		printf "%s" "."
  		sleep 5
	done
fi

echo Ready to run \"dmg format\" on ${servers}

dmg -l ${servers} storage format

printf "%s" "Waiting for DAOS storage format to finish on ${instances} servers"

while true
do
  if [[ $(dmg system query -v | grep Joined | wc -l) -eq ${instances} ]]; then
    printf "\n%s\n" "DAOS storage format finished"
    dmg system query -v
    break
  fi
  printf "%s" "."
  sleep 5
done

echo All done with format

exit 

