
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


from pyparsing import *

class Parser:
    test_pattern = "{{{" + SkipTo("}}}",include=True)
    test_pattern.setParseAction(lambda x:{"test":x[1][0]})

    test_pattern2 = "1" + SkipTo(LineEnd(),include=True) + SkipTo(LineEnd(),include=True) + "2"
    test_pattern2.setParseAction(lambda x:{"test":x[1]})

    ansible = "TASK [" + SkipTo(']',include=True) + SkipTo(LineEnd(),include=True) + oneOf('changed ok failed error unreachable') + ': ' + SkipTo(LineEnd(),include=True)
    ansible.setParseAction(lambda x:{"task":x[1][0],"status":x[3],"subject": x[5][0],"ansible":1})

    ansible2 = "TASK [" + SkipTo(']',include=True) + SkipTo(LineEnd(),include=True) + SkipTo(LineEnd(),include=True) + oneOf('changed ok failed error unreachable') + ': ' + SkipTo(LineEnd(),include=True)
    ansible2.setParseAction(lambda x:{"task":x[1][0],"status":x[4],"subject": x[6][0],"ansible":1})

    ansible3 = "TASK [" + SkipTo(']',include=True) + SkipTo(LineEnd(),include=True) + SkipTo(LineEnd(),include=True) + SkipTo(LineEnd(),include=True) + oneOf('changed ok failed error unreachable') + ': ' + SkipTo(LineEnd(),include=True)
    ansible3.setParseAction(lambda x:{"task":x[1][0],"status":x[5],"subject": x[7][0],"ansible":1})

    # Vagrant
    vagrant_start = Literal("[") + SkipTo("]",include=True) + "Importing base box '" + SkipTo("'",include=True) + SkipTo(LineEnd(),include=True)
    vagrant_start.setParseAction(lambda x:{"vm":x[1][0],"image":x[3][0],"vagrant":1,"global":"Booting VM"})

    vagrant_start = Literal("[") + SkipTo("]",include=True) + "Machine booted and ready!" + SkipTo(LineEnd(), include=True)
    vagrant_start.setParseAction(lambda x:{"vm":x[1][0], "vagrant":1, "global":"VM Booted up"})

    gradle_start = "Downloading https://services.gradle.org" + SkipTo(LineEnd(), include=True)
    gradle_start.setParseAction(lambda x:{"gradle":1, "global":"Gradle started"})

    debian_preparing = "Preparing to unpack" + Word(printables) + SkipTo(LineEnd(), include=True)
    debian_preparing.setParseAction(lambda x:{"debian":1, "package":x[1]})

