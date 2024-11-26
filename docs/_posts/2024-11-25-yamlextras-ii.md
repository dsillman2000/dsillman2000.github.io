---
layout: post
author: David Sillman
title: Modular YAML II
---

Where we last left off, I was just able to import a whole YAML file's contents into another YAML file using a custom
Loader and Constructor in PyYAML for the `!import` tag. But there's a missing piece. What happens if I want to merge
multiple YAML files during import? First, let's talk about the YAML merge key, "&lt;&lt;", and how it works.

## The YAML merge key

\\
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

When attempting to load the `merged.yml` file, we get this runtime error:

```
...
yaml.constructor.ConstructorError: while constructing a mapping
...
expected a mapping or list of mappings for merging, but found scalar
```

Digging deeper into the stack trace, it becomes clear that the error is cropping up during the merge key handling,
which is performed in the `Loader` class using the `Loader.flatten_mapping` method. Let's take a look at how this method
is implemented for the stanard `yaml.SafeLoader` class:

```python
