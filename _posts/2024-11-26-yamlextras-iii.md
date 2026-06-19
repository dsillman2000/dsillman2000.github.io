---
layout: post
author: David Sillman
title: "Modular YAML III: importing globs with \"import-all\""
---

What happens when we want PyYAML to dynamically load an entire directory of YAML files into the contents of a single YAML document?
At the moment, this is painfully manual, where importing all the contents of a directory require separate `!import` nodes for each
document:

```yaml
items:
  - !import items/item1.yml
  - !import items/item2.yml
  - !import items/item3.yml
```
\\
In this article, I propose a new dedicated tag with its own constructor for handling this use case, called `!import-all`.

# Handling globs with `!import-all`

Let's begin by looking at the dataclass we'll use to represent an instance of a tagged node, `ImportAllSpec`. Typical Python `Path`
objects won't gel nicely with including Unix-style wildcards in the path, so we'll start by creating a custom class for handling
path globs.

```python
@dataclass
class PathPattern:
    pattern: str
```

We'll want a function on this type for yielding the list of `Path`s captured by the glob pattern, which `pathlib` conveniently includes.
For the sake of efficiency, we'll memoize this function so that we never need to search the filesystem for a particular glob
pattern more than once. To hash `self` in the memoized lookup dictionary, we'll need to make `PathPattern` hashable. We can do this
by just inheriting the hash of the glob pattern itself, which we also include with our implementation.

```python
from functools import lru_cache
...
@dataclass
class PathPattern:
    pattern: str

    def __hash__(self) -> int:
        return hash(self.pattern)

    @lru_cache
    def glob_results(self) -> list[Path]:
        return list(Path.cwd().glob(self.pattern))
```
\\
Great, now we have a utility type for handling the glob pattern in our `ImportAllSpec`. Let's implement that now:

```python
@dataclass
class ImportAllSpec:
    path_pattern: PathPattern

    @classmethod
    def from_str(cls, pattern_str: str) -> "ImportAllSpec":
        return cls(PathPattern(pattern_str))
```
\\
This will be the container class we use when we encounter a node tagged with `!import-all`. Now, let's implement the constructor
for this tag:

```python
@dataclass
class ImportAllConstructor:

    def __call__(self, loader: yaml.Loader, node: yaml.Node) -> list[dict]:
        # Handle a node tagged with !import-all
        import_all_spec: ImportAllSpec
        if isinstance(node, yaml.ScalarNode):
            val = loader.construct_scalar(node)
            if isinstance(val, str):
                import_all_spec = ImportAllSpec.from_str(val)
            else:
                raise TypeError(f"!import-all Expected a string, got {type(val)}")
        else:
            raise TypeError(f"!import-all Expected a string scalar, got {type(node)}")
        return self.load(type(loader), import_all_spec)

    def load(self, loader_type: Type[yaml.Loader], import_all_spec: ImportAllSpec) -> list[dict]:
        # Load the contents of all the files in the glob pattern
        return [
            yaml.load(path.open("r"), loader_type)
            for path in import_all_spec.path_pattern.glob_results()
        ]
```
\\
Finally, we need to make sure we include the entry for the constructor in our custom `ImportLoader`:

```python
...
class ImportLoader(yaml.SafeLoader):
    def __init__(self, stream):
        super().__init__(stream)
        self.add_constructor("!import", ImportConstructor())
        self.add_constructor("!import-all", ImportAllConstructor())
...
```
\\
That turned out to be pretty easy! Now we can load a directory like that in the example at the start of this article with a single
`!import-all` tag:

```yaml
items: !import-all items/*.yml
```
\\
When we load a file like this with our custom loader, the contents of all the files in the `items` directory will be loaded into
the Python object, e.g. it might look like this:

```python
items = {
  "items": [
    {
      "name": "item1",
      "value": 1
    },
    {
      "name": "item2",
      "value": 2
    },
    {
      "name": "item3",
      "value": 3
    }
  ]
}
```
\\
Adding a new `item4.yml` file to the `items` directory can now be loaded into the Python object without any changes to the YAML or
the underlying Python code performing the load. This is a powerful feature for managing modular YAML files in a project.

## What about merging an `!import-all` node?

But there's one missing piece, as there was before in article I. We can't use this feature with a merge key! I.e., we can't do this:

```yaml
merged-all:
  <<: !import-all items_to_merge/*.yml
```
\\
If we had a directory of files like `A.yml` with `A: 1`, and `B.yml` with `B: 2`, etc, we'd want to be able to load them all into a
single mapping, like

```python
merged = {
  "merged-all": {
    "A": 1,
    "B": 2,
    ...
  }
}
```

If we had a directory full of YAML files which we wanted to merge into a single object (not a sequence of mappings), then we'd want
the `!import-all` to resolve to a sequence of mappings, which are subsequently merged. Luckily, we can just update our existing override
of `flatten_mapping` to account for this case. In the event that the `<<` merge key flattening method encounters a `!import-all` _scalar_
node, we'll just have it load each of the contents of the files in the glob pattern into a list of their respective Python objects, then
re-represent the list as a YAML `SequenceNode`. The good news is that all of this actually fits into the existing `ScalarNode` branch of our
`if` statement in the `flatten_mapping` method. Here's the only change we need to make to the method:

```python
# Before
if isinstance(value_node, yaml.ScalarNode) and value_node.tag == "!import":
    imported_value = self.construct_object(value_node)
    data_buffer = StringIO()
    imported_repr = yaml.SafeDumper(data_buffer).represent_data(imported_value)
    node.value[i] = (key_node, imported_repr)

# After
if isinstance(value_node, yaml.ScalarNode) and value_node.tag in (
    "!import",
    "!import-all",
):
    imported_value = self.construct_object(value_node)
    data_buffer = StringIO()
    imported_repr = yaml.SafeDumper(data_buffer).represent_data(imported_value)
    node.value[i] = (key_node, imported_repr)
```

Perfect - now we can use the `!import-all` tag with the merge key `<<` to merge the contents of a directory of YAML files into a single
mapping, like the example above. That example can now be successfully loaded as:

```python
merged = {
  "merged-all": {
    "D": 4,
    "A": 1,
    "C": 3,
    "B": 2
  }
}
```

And that's it! We've now got a powerful tool for managing modular YAML files in a project, utilizing the directory structure to maintain
hierarchical relationships between YAML modules. In the next article, I'll talk about a way that we can improve this importing system by
allowing targeted imports of specific parts of other YAML files.

## Safety note

One other thing to mention is that nothing in this article prevents a user from creating a cyclical import, e.g., a pair of files

```yaml
# A.yml
contents-of-B: !import B.yml
```

```yaml
# B.yml
contents-of-A: !import A.yml
```

This will cause an infinite loop when loading the files which bubbles up to a "max recursion depth exceeded" error. This is a limitation
of the current implementation which I may consider addressing in a future article. For now, just be aware of this limitation when using
the `!import` and `!import-all` tags in your projects.
