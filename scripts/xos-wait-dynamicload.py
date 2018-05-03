#!/usr/bin/env python

# Copyright 2017-present Open Networking Foundation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# xos-wait-dynamicload.py
# Wait for dynamic load to complete.
# Syntax: xos-wait-dynamicload.py <retries> <base_url> [service_names]
#
# Example: xos-wait-dynamicload.py 120 http://192.168.42.253:30006 vsg-hw volt fabric vrouter

import sys
import time
import requests

DELAY=1

def main():
    if len(sys.argv)<4:
        print "Syntax: xos-wait-dynamicload.py <retries> <base_url> [service_names]"
        sys.exit(-1)

    retries = int(sys.argv[1])
    base_url = sys.argv[2]
    service_names = sys.argv[3:]
    attempt = 0
    while True:
        attempt += 1
        if (attempt > retries):
            print "Exceeded maximum retries"
            sys.exit(-1)

        print "Attempt %d of %d" % (attempt, retries),

        try:
            r = requests.get(base_url + "/xosapi/v1/dynamicload/load_status")
        except requests.exceptions.ConnectionError:
            print "Connection error"
            time.sleep(DELAY)
            continue

        if r.status_code != 200:
            print "Received error response", r.status_code
            time.sleep(DELAY)
            continue

        services_by_name = {}
        for service in r.json()["services"]:
            services_by_name[service["name"]] = service
        missing = []
        for service_name in service_names:
            service = services_by_name.get(service_name, {"state": "missing"})
            if service["state"] != "present":
                missing.append(service_name)
        if not missing:
            print "All required services are present"
            sys.exit(0)

        print "Waiting on services: ", ", ".join(missing)
        time.sleep(DELAY)


if __name__ == "__main__":
    main()
