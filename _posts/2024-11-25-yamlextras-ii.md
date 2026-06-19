---
layout: post
author: David Sillman
title: "Modular YAML II: merging imports"
---

Where we last left off, I was just able to import a whole YAML file's contents into another YAML file using a custom
Loader and Constructor in PyYAML for the `!import` tag. But there's a missing piece. What happens if I want to merge
multiple YAML files during import? First, let's talk about the YAML merge key, "&lt;&lt;", and how it works.

## The YAML merge key

The YAML merge key is a special key which allows you to merge the contents of one mapping into another. It's denoted by
the `<<` symbol. Here's an example:

```yaml
mapping-a: &A
  key-a: value-a
  key-b: value-b

mapping-b: &B
  key-b: value-Bee
  key-c: value-Cee

merged-mapping:
  <<: [*A, *B]
```
\\
If we were to look into the `merged-mapping` key after loading with PyYAML, we would see:

```python
{
    "key-a": "value-a",
    "key-b": "value-Bee",
    "key-c": "value-Cee"
}
```
\\
An alternative syntax for using the merge key is to define `<<` as a repeated key in the mapping, e.g.,

```yaml
merged-mapping:
  <<: *A
  <<: *B
```
\\
So let's try to use our custom `ImportLoader` to load a YAML file which merges the contents of multiple YAML files. Suppose
we have an `A.yml` and `B.yml` with the `key-*` mappings above defined in them. Then we can test our loader with the
below example file:

```yaml
# merged.yml
<<: !import A.yml
<<: !import B.yml
```
\\
When attempting to load the `merged.yml` file, we get this runtime error:

```
...
yaml.constructor.ConstructorError: while constructing a mapping
...
expected a mapping or list of mappings for merging, but found scalar
```

## How does YAML merging work?

Digging deeper into the stack trace, it becomes clear that the error is cropping up during the merge key handling,
which is initiated in the `Loader` class using the `Constructor.construct_mapping` method. This method is responsible
for constructing any and all `MappingNode`s which are encountered during the composition of the YAML document. The
`construct_mapping` method, in turn, calls the `Constructor.flatten_mapping` method. As compared to the `construct_mapping`
method, the `flatten_mapping` method actually handles the merge key logic. Check out its implementation in the
`SafeConstructor` class in the PyYAML source code:

```python
def flatten_mapping(self, node):
    merge = []
    index = 0
    while index < len(node.value):
        key_node, value_node = node.value[index]
        if key_node.tag == 'tag:yaml.org,2002:merge':
            del node.value[index]
            if isinstance(value_node, MappingNode):
                self.flatten_mapping(value_node)
                merge.extend(value_node.value)
            elif isinstance(value_node, SequenceNode):
                submerge = []
                for subnode in value_node.value:
                    if not isinstance(subnode, MappingNode):
                        raise ConstructorError("while constructing a mapping",
                                node.start_mark,
                                "expected a mapping for merging, but found %s"
                                % subnode.id, subnode.start_mark)
                    self.flatten_mapping(subnode)
                    submerge.append(subnode.value)
                submerge.reverse()
                for value in submerge:
                    merge.extend(value)
            else:
                raise ConstructorError("while constructing a mapping", node.start_mark,
                        "expected a mapping or list of mappings for merging, but found %s"
                        % value_node.id, value_node.start_mark)
        elif key_node.tag == 'tag:yaml.org,2002:value':
            key_node.tag = 'tag:yaml.org,2002:str'
            index += 1
        else:
            index += 1
    if merge:
        node.value = merge + node.value
```

The operative condition in the `flatten_mapping` method is the `if key_node.tag == 'tag:yaml.org,2002:merge':` check.
When a `<<` key is encountered, its value `Node` is expected to be either a `MappingNode` or a `SequenceNode` of `MappingNode`s.
If this method encounters a scalar value, like `!import A.yml`, we land in the `else` block, which raises the error we saw
above. The crux of the issue is that we want our `!import` tag to handle the loading of the file before the result is passed
to the `flatten_mapping` method.

## Handling the merge key in our custom Loader

The problem is that we can't implement this behavior in the `ImportConstructor` class. The `ImportConstructor` class is
only invoked when a node is encountered with the `!import` tag during _construction._ This error is cropping up just before we
can get around to constructing the `!import` node. So a work-around I thought of is to override the `flatten_mapping` method in
our custom `ImportLoader` class such that we can intercept the `!import` tag before it gets passed to the `flatten_mapping` method,
load the file, and then pass the loaded data to the `flatten_mapping` method. Here's the implementation:

```python
from io import StringIO
...
class ImportLoader(yaml.SafeLoader):
  ...
  def flatten_mapping(self, node: yaml.MappingNode):
      for i in range(len(node.value)):
          key_node, value_node = node.value[i]
          if key_node.tag == "tag:yaml.org,2002:merge":
              if isinstance(value_node, yaml.ScalarNode) and value_node.tag == "!import":
                  imported_value = self.construct_object(value_node)
                  data_buffer = StringIO()
                  imported_repr = yaml.SafeDumper(data_buffer).represent_data(imported_value)
                  node.value[i] = (key_node, imported_repr)
      super().flatten_mapping(node)
```

Note that I've pretty much copied the internal logic of the `flatten_mapping` method from the PyYAML source code, except only
including a case for handling the scalar `!import`-tagged node. We call `construct_object` on this node, which will identify the
`!import` tag and call our `ImportConstructor` to load the file.

The problem is that, at this point, `imported_value` is a Python object representing the contents of the file, but the `flatten_mapping`
method expects a `Node` object. So that means we need to move back up the representation chain and convert the Python object back into a
`Node` object. Just like PyYAML has a chain of abstractions (`Path` -> `(FileStream, Scanner)` -> `(Tokens, Parser)` -> `(Events, Composer)` 
-> `(Nodes, Constructor)` -> `Python Object`) which converts a YAML file into a Python object, there is a reverse chain of abstractions
which converts a Python object back into a YAML file. For the purposes of this post, let's just focus on the first step, which converts a Python
object back into an AST of YAML `Node` objects. This is performed by the `Representer`, which can be accessed directly on a `Dumper`
object using the `Dumper.represent_data` method. Because instantiating a `Dumper` requires some target to which the YAML output will be dumped,
I just instantiate an `StringIO` receptacle for this purpose. Finally, this allows me to get the `imported_repr` object, which is an AST
of the contents of the imported YAML file. Now I can pass the result to the `SafeConstructor.flatten_mapping` method, which will merge the
result into the document as-expected.
\\
\\
When we try our code now, we get the expected output:

```python
merged = {
  "merged-mapping": {
    "key-a": "value-a",
    "key-b": "value-Bee",
    "key-c": "value-Cee"
  }
}
```

This is a pretty good solution, but it's not completely done. As we saw in the core `SafeConstructor.flatten_mapping` method, there's another way
you can use the merge key, which is to have a sequence of mappings to merge, like we saw in the above example of merge key usage:

```yaml
merged-mapping:
  <<: [*A, *B]
```

## Handling sequences of `!import` nodes
\\
Can we modify our `ImportLoader.flatten_mapping` method to handle this case as well for `!import` nodes? E.g.,

```yaml
merged-mapping:
  <<: [!import A.yml, !import B.yml]
```


Of course we can! It's just a matter of adding an additional `if` block to our `flatten_mapping` override to handle the case where the value is
a `SequenceNode` of `ScalarNode`s tagged with `!import`. Here's the implementation:

```python
class ImportLoader(yaml.SafeLoader):
    ...
    def flatten_mapping(self, node: yaml.MappingNode):
      ...
        if key_node.tag == "tag:yaml.org,2002:merge":
              if isinstance(value_node, yaml.ScalarNode) and value_node.tag == "!import":
                  ...
              if isinstance(value_node, yaml.SequenceNode):
                  for j in range(len(value_node.value)):
                      subnode = value_node.value[j]
                      if isinstance(subnode, yaml.ScalarNode) and subnode.tag == "!import":
                          imported_value = self.construct_object(subnode)
                          data_buffer = StringIO()
                          imported_repr = yaml.SafeDumper(data_buffer).represent_data(
                              imported_value
                          )
                          value_node.value[j] = imported_repr
                  value_node.value.reverse()
                  node.value[i] = (key_node, value_node)
        return super().flatten_mapping(node)
```

Note that I'm following the exact same order-of-operations as the original `SafeConstructor.flatten_mapping` implementation
for sequences of `MappingNode`s. When I recognize that the value of the `<<` key is a sequence, I iterate over the sequence
values. When I encounter an `!import` node, I perform the same steps as before to load the file and convert the Python object
back into a `Node` object. Finally, to match the implementation of the merge key for sequences of `MappingNode`s, I reverse the
sequence of `Node` objects and replace the original `SequenceNode` with the new sequence of `Node` objects. This reversal ensures
that the precedence of merged mappings is maintained, i.e. the last mapping in the sequence takes precedence over the first mapping.

And that's it! We now have a fully-functional `!import` tag which can be used to import YAML files into other YAML files, _plus_ it
can handle merging multiple imports into a single mapping using the `<<` YAML merge key. It can even handle a mix of `!import` and
non-`!import` mappings in the same merge:

```yaml
override-config: &override
  host: "localhost"
  port: 8080
  threads: 16
  connection_profile: lab

config:
  <<: !import default-config.yml
  <<: *override
```

The functionality we've implemented here allows us to create modular YAML files which can be imported and merged into other YAML files.
But there's more to be done to make this sufficiently general and robust. In the next post, I'll talk about a variant we can implement
to handle the case where we want to import an entire glob pattern of YAML files as a sequence of Python objects.
