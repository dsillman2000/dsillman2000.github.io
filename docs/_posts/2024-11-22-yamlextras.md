---
layout: post
author: David Sillman
title: Modular YAML
---

Since I've started working at Intuitive full-time, I've been interacting with YAML files in some capacity pretty much 
every day. Some of that is because I do a lot of [dbt](https://www.getdbt.com/) development as a data engineer, and dbt 
uses YAML files to define models, tests and other properties about the data model. And there's pre-commit, Gitlab CI, as
well as other custom Intuitive tools that use YAML files to define configurations.

This frequent interaction with YAML has led me to also write some of my own tools and scripts which depend upon source
data which is laid out in YAML files. One such project I've written with these tools is a Python CLI which reads a 
directory of YAML files and Jinja templates and outputs a directory of rendered files. The original purpose of the 
kernel of this project was for mass-producing Jira content and standardizing other documentation. I've also used it to
mass-generate unit tests which are so similar to one another that they can be effectively templated.

Something that most of my Python code would be preoccupied with was crawling the local directories for YAML files and
associating them with the right Jinja templates in a way that scaled well, was flexible and DRY. I'm still working on 
this broader project of general DRY templated document generation to this day.

## What are YAML tags?

YAML tags are a way to extend the YAML specification to include custom data types. The YAML specification includes a
number of built-in tags, such as `!!str` for strings, `!!int` for integers, `!!float` for floats, and `!!bool` for booleans.
Syntactically, they only need one leading exclamation mark, but most of the built-in tags have two.

```yaml
# Example of YAML tags
string: !!str "Hello, world!"
```

As you can see, they're sort of like anchors in how they just immediately precede a YAML node. Except that they're more 
like type hints, or general-purpose annotations. They're not mutually exclusive - the syntax to tag and anchor a YAML 
node is as follows:

```yaml
# Tagging and anchoring a YAML node
tagged-and-anchored: !my-tag &my-anchor "my value"
```

Unlike anchors, tags can be used as many times as you want (anchors need to be unique for the YAML resolver to properly
resolve them). Tags can also be used to define custom data types, which is why sometimes you'll see them if you dump
a YAML representation of a custom class from Python.

```yaml
# Example of a custom data type
!MyCustomType
custom_instance:
  - my_key: !!str "my value"
```

So if I wanted to "import" a YAML file from another YAML file, it would be syntactically sound to define a custom tag
for this purpose.

## Envisioning "!import"

One part of the puzzle which might get me closer to being able to flexibly managing YAML files in a DRY way that scales
well is to use a modular approach. If I'm able to organize documents in a directory tree to represent hierarchical
relationships between documents, I can effectively split responsibilities between documents. The core mechanism that
would allow this functionality is some way to reference the contents of YAML file $$X$$ from within a YAML file $$Y$$.
\\
\\
I'd imagine that this operation looks something like this:
\\
```yaml
# X.yml
x: !import Y.yml
```
\\
If we were to suppose that `Y.yml` contained the following:

```yaml
# Y.yml
y: "Hello, world!"
```
\\
Then we'd want to be able to read `X.yml` into memory as the following Python dictionary:

```python
X = {
  "x": {
    "y": "Hello, world!"
  }
}
```

## Let's talk about PyYAML

[PyYAML](https://pyyaml.org/) is by far the most popular and most widely-used YAML parser for Python. It's a wrapper 
around the C library [`libyaml`](https://pyyaml.org/wiki/LibYAML), and it's the parser that's used by dbt to parse YAML
configurations.

When Googling to see if anyone's solved my "YAML importing" problem yet, I was not disappointed by the excellent design 
of [`pyyaml-include`](https://github.com/tanbro/pyyaml-include). Its design of the `!include` tag was a great 
inspiration for me to figure out how to implement my own tagging system which followed different conventions to serve 
different purposes.

Reading the source code for `pyyaml-include` introduced me to the pattern of using a custom _constructor_ to parse a
specialized tag. This is the pattern I would use to implement my own `!import` tag.

PyYAML loads data from a YAML file into a Python object using a `Loader` object. The process of loading a YAML file starts
with the `Scanner`, which reads the file character by character and tokenizes it into a stream of tokens. The `Parser`
then takes these tokens to build a sequence of parsed events. The `Composer` then takes these events and builds an
abstract syntax tree (AST) of nodes. Finally, specialized `Constructor`s take each node of the AST to build a complete 
Python object. All the way through this process, tags are propagated as fields of the events and nodes. However, when 
the `Constructor` is being chosen for a node, the tag on the node will determine which constructor is used.

## Extending PyYAML

If we want to be able to parse our custom `!import` tag, we'll need to create our own `Constructor` class which gets
called to handle nodes which are encountered with an `!import` tag. For good measure, we'll also create a custom `Loader`
class to ensure that our custom constructor is used with this specific tag.

```python
from dataclasses import dataclass
from pathlib import Path
import yaml

@dataclass
class ImportSpec:
    path: Path

    @classmethod
    def from_str(cls, path_str: str) -> "ImportSpec":
        return cls(Path(path_str))

@dataclass
class ImportConstructor:

    def __call__(self, loader: yaml.Loader, node: yaml.Node) -> dict:
        # Handle a node tagged with !import
        import_spec: ImportSpec
        if isinstance(node, yaml.ScalarNode):
            val = loader.construct_scalar(node)
            if isinstance(val, str):
                import_spec = ImportSpec.from_str(val)
            else:
                raise TypeError(f"!import Expected a string, got {type(val)}")
        else:
            raise TypeError(f"!import Expected a string scalar, got {type(node)}")
        return self.load(type(loader), import_spec)

    def load(self, loader_type: Type[yaml.Loader], import_spec: ImportSpec) -> Any:
        # Just load the contents of the file
        return yaml.load(import_spec.path.open("r"), loader_type)

class ImportLoader(yaml.SafeLoader):
    def __init__(self, stream):
        super().__init__(stream)
        self.add_constructor("!import", ImportConstructor())
     
```

That may seem like a lot of code, but it's actually pretty simple. The `ImportSpec` class is a simple dataclass which
wraps a `pathlib.Path` object and provides a method to construct an `ImportSpec` from a string. The `ImportConstructor`
class is a callable class which takes a `yaml.Loader` object and a `yaml.Node` object and returns the contents of the
YAML file specified by the scalar string in the node. The `ImportLoader` class is a subclass of `yaml.SafeLoader` which
adds the `!import` tag to the constructor map with an `ImportConstructor` object.

## Using our custom tag

Now we can load a YAML file with the `!import` tag and have the contents of the file loaded into the Python object. Here's
an example of how we might use this in practice:

```python
import yaml
from yaml_import import ImportLoader

X_yml = Path(__file__).parent / "X.yml"
X_data = yaml.load(X_yml.open("r"), ImportLoader)
X = json.dumps(X_data, indent=2)
print(f"{X = }")
```

Which yields,

```python
X = {
  "x": {
    "y": "Hello, world!"
  }
}
```

Nice! Now we can import YAML files from other YAML files. There's more to be done, though. In the next post, I'll talk
about making this `!import` tag work with the YAML merge key "&lt;&lt;". Stay tuned!
