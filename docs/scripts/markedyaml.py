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

# markedyaml.py
# generates nodes with start/end line and column values
# start line seems off with single-line items, correct with multiline
#
# Original code from here: https://gist.github.com/dagss/5008118
# Request for licensing clarification made on 2017-09-19
# Contains improvements to support more types (bool/int/etc.)

import yaml
from yaml.composer import Composer
from yaml.reader import Reader
from yaml.scanner import Scanner
from yaml.composer import Composer
from yaml.resolver import Resolver
from yaml.parser import Parser
from yaml.constructor import Constructor, BaseConstructor, SafeConstructor

def create_node_class(cls):
    class node_class(cls):
        def __init__(self, x, start_mark, end_mark):
            cls.__init__(self, x)
            self.start_mark = start_mark
            self.end_mark = end_mark

        def __new__(self, x, start_mark, end_mark):
            return cls.__new__(self, x)
    node_class.__name__ = '%s_node' % cls.__name__
    return node_class

dict_node = create_node_class(dict)
list_node = create_node_class(list)
unicode_node = create_node_class(unicode)
int_node = create_node_class(int)
float_node = create_node_class(float)

class NodeConstructor(SafeConstructor):
    # To support lazy loading, the original constructors first yield
    # an empty object, then fill them in when iterated. Due to
    # laziness we omit this behaviour (and will only do "deep
    # construction") by first exhausting iterators, then yielding
    # copies.
    def construct_yaml_map(self, node):
        obj, = SafeConstructor.construct_yaml_map(self, node)
        return dict_node(obj, node.start_mark, node.end_mark)

    def construct_yaml_seq(self, node):
        obj, = SafeConstructor.construct_yaml_seq(self, node)
        return list_node(obj, node.start_mark, node.end_mark)

    def construct_yaml_str(self, node):
        obj = SafeConstructor.construct_scalar(self, node)
        assert isinstance(obj, unicode)
        return unicode_node(obj, node.start_mark, node.end_mark)

    def construct_yaml_bool(self, node):
        obj = SafeConstructor.construct_yaml_bool(self, node)
        return int_node(obj, node.start_mark, node.end_mark)

    def construct_yaml_int(self, node):
        obj = SafeConstructor.construct_scalar(self, node)
        return int_node(obj, node.start_mark, node.end_mark)

    def construct_yaml_float(self, node):
        obj = SafeConstructor.construct_scalar(self, node)
        return float_node(obj, node.start_mark, node.end_mark)


NodeConstructor.add_constructor(
        u'tag:yaml.org,2002:map',
        NodeConstructor.construct_yaml_map)

NodeConstructor.add_constructor(
        u'tag:yaml.org,2002:seq',
        NodeConstructor.construct_yaml_seq)

NodeConstructor.add_constructor(
        u'tag:yaml.org,2002:str',
        NodeConstructor.construct_yaml_str)

NodeConstructor.add_constructor(
        u'tag:yaml.org,2002:bool',
        NodeConstructor.construct_yaml_bool)

NodeConstructor.add_constructor(
        u'tag:yaml.org,2002:int',
        NodeConstructor.construct_yaml_int)

NodeConstructor.add_constructor(
        u'tag:yaml.org,2002:float',
        NodeConstructor.construct_yaml_float)


class MarkedLoader(Reader, Scanner, Parser, Composer, NodeConstructor, Resolver):
    def __init__(self, stream):
        Reader.__init__(self, stream)
        Scanner.__init__(self)
        Parser.__init__(self)
        Composer.__init__(self)
        NodeConstructor.__init__(self)
        Resolver.__init__(self)

def get_data(stream):
    return MarkedLoader(stream).get_data()

