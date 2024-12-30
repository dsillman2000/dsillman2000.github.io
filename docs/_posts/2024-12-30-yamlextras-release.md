---
layout: post
author: David Sillman
title: "Modular YAML released: <code>yaml-extras</code> on PyPI"
---

I'm proud to announce that I've made my first official contribution to the Python Package Index
(PyPI) with the release of a package called `yaml-extras`. This package is the culmination of what
I've discussed in the previous three blog posts dedicated to loading the contents of YAML files
into one another in a modular way. See the other three articles linked below:

- [Modular YAML I: a custom "import" tag](/2024/11/22/yamlextras.html)
- [Modular YAML II: importing YAML files with "import"](/2024/11/25/yamlextras-ii.html)
- [Modular YAML III: importing globs with "import-all"](/2024/11/26/yamlextras-iii.html)

\\
The package is available on PyPI [here](https://pypi.org/project/yaml-extras/). The source code is
available and open source on Github, plus an extended documentation website:

- [Github: yaml-extras](https://github.com/dsillman2000/yaml-extras)
- [Documentation: yaml-extras](https://yaml-extras.pages.dev)

\\
Because the package is available on PyPI, you can install it with your package manager of choice:

```bash
# Install with pip
pip install yaml-extras

# Install with poetry
poetry add yaml-extras
```

If you read this article and are inspired to make something with `yaml-extras`, I'd love to hear
about it! (Shoot me an email at <dsillman2000@gmail.com>)

\\
Since the final article in the series, I've made significant refactors to some of the content I
shared which I will briefly summarize here.

## `!import.anchor` and `!import-all.anchor`

In the final article, I alluded to the possibility of a follow-up article that discussed "targeted"
imports, where you could specify a particular anchor in an external YAML file which you wanted to
import. I've since implemented this feature in the package, and it's available for use, but the
implementation was somewhat nuanced.

The challenge of implementing an "anchor-fetching" feature as just another `Constructor` alongside
my other custom constructors was that, by the time a `yaml.Node` reaches the construction phase of
loading, all anchors and aliases have been resolved, so anchors are nowhere to be seen. To identify
subtrees of the AST which are marked with a particular anchor, I needed to intercept the AST before
it reached construction, meaning I needed to use the PyYAML Parser directly.

As a refresher, the YAML Parser is responsible for taking the raw YAML Tokens which are _scanned_ 
from a file and producing YAML _Events._ The events are subsequently _parsed_ into an AST of YAML 
_Nodes_ which finally get _constructed_ into Python objects. The last medium in this process which
has any notion of anchors are the YAML Events. So, in abbreviated pseudo-python code, here's how I 
implemented a helper function called `load_yaml_anchor(file_stream, anchor, loader_type)`:

```python
def load_yaml_anchor(
    file_stream: IO,
    anchor: str,
    loader_type: Type[yaml.Loader],
) -> Any:
    # "indent" level tracker as we're traversing events to fully consume the anchored subtree
    level = 0
    # Receptacle for the Events which compose the anchored subtree
    events = []
    # Commence parsing
    for event in yaml.parse(file_stream, loader_type):
        # Case 1: we're on the anchored Scalar
        if "event is a Scalar" and "event has anchor == `anchor`":
            events = [event]
            break
        # Case 2: we're entering the anchored Mapping or Sequence
        elif (
            "event is start of a Mapping" or 
            "event is start of a Sequence"
        ) and "event has anchor == `anchor`":
            events = [event]
            level = 1
        # Case 3: we're in the anchored subtree
        elif level > 0:
            events.append(event)
            # Case 3a: we're entering a nested Mapping or Sequence
            if "event is start of a Mapping" or "event is start of a Sequence":
                level += 1
            # Case 3b: we're exiting a nested Mapping or Sequence
            elif "event is end of a Mapping" or "event is end of a Sequence":
                level -= 1
            # Case 3c: we're exiting the anchored subtree
            if level == 0:
                break
```

It may seem pretty inductive and straightforward when you consider that there are only a few possible
structures that a single anchored node can take in a YAML file. But it took a good amount of trial
and error against a variety of unit test cases to settle on this design.

If you'd like more in-depth information about how this helper function is used in the package to
support the `!import.anchor` and `!import-all.anchor` tags, I encourage you to check out the source
code on Github.

## `!import-all-parameterized`

Something that I didn't get around to mentioning was a feature that I consider very important to
the usability of the package: parameterized imports (though this may seem like a convoluted and
unnecessary feature). The idea is that you can specify a glob pattern with one or more wildcards
in it (like with `!import-all`), but you can attach to some of those glob patterns string names
which are then merged into the resulting Python objects parsed from each file.

\\
For instance, imagine we had the following directory structure:

```
recipes/
    - Gingerbread.yml
    - ChocolateChip.yml
    - Sugar.yml
    - Oatmeal.yml
    - PeanutButter.yml
    ...
```
\\
We could imagine each of these YAML files have a similar structure,

```yaml
ingredients:
  - ingredient 1
  - ingredient 2
  - ...
instructions:
  - instruction 1
  - instruction 2
  - ...
```

For the ease of the developer (slash baker), we can assume that they would like to be able to add 
new recipes to the directory without needing to touch any other configs. There might be an outer 
`recipes.yml` file where we want to import each of the recipes into a sequence of mappings of their 
contents.

```yaml
# recipes.yml
recipes:
  cookies:
    - name: Gingerbread
      <<: !import recipes/Gingerbread.yml
    - name: Chocolate Chip
      <<: !import recipes/ChocolateChip.yml
    - name: Sugar
      <<: !import recipes/Sugar.yml
    - name: Oatmeal
      <<: !import recipes/Oatmeal.yml
    - name: Peanut Butter
      <<: !import recipes/PeanutButter.yml

# Each recipe looks like
# - name: ...
#   ingredients:
#     - ...
#   instructions:
#     - ...
```

This simply won't work because of how unwieldly it is and that it breaks our core requirement that
we should be able to add new recipes without adding more YAML entries to an ever-expanding index. 
Likewise, if we tried to use `!import-all`, we'd end up with a sequence of recipes which don't have 
names!

```yaml
# recipes.yml
recipes:
  cookies: !import-all recipes/*.yml

# Each recipe looks like
# - ingredients:
#     - ...
#   instructions:
#     - ...
```
\\
So we could use this specialized tag, `import-all-parameterized`, to ensure that we capture the name
of each file as a dedicated field in each resulting Python object:

```yaml
# recipes.yml
recipes:
  cookies: !import-all-parameterized recipes/{name:*}.yml

# Each recipe looks like
# - name: Gingerbread
#   ingredients:
#     - ...
#   instructions:
#     - ...
```

This is a powerful feature for managing modular YAML files in a project. It allows us to outsource
some of the hierarchical categories of our YAML documents to the filesystem, which can also make
navigating the project's definitions a little easier.
\\
In addition to simple `*` wildcards which can store a single component of the path, entire sub-paths
can also be stored as a parameter:

```yaml
# recipes.yml
recipes: !import-all-parameterized recipes/{category_tree:**}/{name:*}.yml

# Each recipe looks like
# - category_tree: baking/cookies
#   name: Gingerbread
#   ingredients:
#     - ...
#   instructions:
#     - ...
```

## Customizing local import behavior

As a final touch to make the package usable in downstream applications, I needed to finally
deprecate my assumption that the imports should always be seeking from the Python process's working
directory.

I ultimately implemented this by maintaining a global variable which was used to retrieve the
root of the filesystem from which all imports should be resolved. This variable could be get/set by
calling a function in the corresponding module of the package:

```python
import os
from yaml_extras import yaml_import

# Get the current import root
root = yaml_import.get_relative_import_dir()

# Set the import root to my home
yaml_import.set_relative_import_dir(os.environ.get("HOME"))
```
\\
This was a simple solution to a problem that I had been putting off for a while, and I'm glad to
have finally implemented it in a way which wasn't too nasty.

## Conclusion

I'm very proud of the work I've done on this package, and I'm excited to see if other people see
the same potential in it that I do for simplifying certain repetitive and template-worthy tasks
in their projects. I'm also excited to see if I can continue to improve the package and make it
more user-friendly and suitable for additional use cases.

\\
Links:

- [yaml-extras on PyPI](https://pypi.org/project/yaml-extras/)
- [yaml-extras on Github](https://github.com/dsillman2000/yaml-extras)
- [yaml-extras documentation](https://yaml-extras.pages.dev)
