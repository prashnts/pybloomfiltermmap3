# pybloomfiltermmap3

[pybloomfiltermmap3](https://github.com/prashnts/pybloomfiltermmap3) is a Python 3 compatible fork of [pybloomfiltermmap](https://github.com/axiak/pybloomfiltermmap) by [@axiak](https://github.com/axiak).

The goal of `pybloomfiltermmap3` is simple: to provide a fast, simple, scalable, correct library for Bloom filters in Python.

[![Build Status](https://travis-ci.org/PrashntS/pybloomfiltermmap3.svg?branch=master)](https://travis-ci.org/PrashntS/pybloomfiltermmap3)
[![Documentation Status](https://readthedocs.org/projects/pybloomfiltermmap3/badge/?version=latest)](https://pybloomfiltermmap3.readthedocs.io/en/latest/?badge=latest)
[![PyPI](https://img.shields.io/pypi/v/pybloomfiltermmap3.svg)](https://pypi.python.org/pypi/pybloomfiltermmap3)
[![PyPI](https://img.shields.io/pypi/dw/pybloomfiltermmap3.svg)](https://pypi.python.org/pypi/pybloomfiltermmap3)
[![PyPI](https://img.shields.io/pypi/pyversions/pybloomfiltermmap3.svg)](https://pypi.python.org/pypi/pybloomfiltermmap3)


## Why pybloomfiltermmap3?

There are a couple reasons to use this module:

* It natively uses [mmapped files](http://en.wikipedia.org/wiki/Mmap).
* It is fast (see [benchmarks](http://axiak.github.io/pybloomfiltermmap/#benchmarks)).
* It natively does the set things you want a Bloom filter to do.


## Quickstart

After you install, the interface to use is a cross between a file
interface and an ste interface. As an example:
```python
    >>> import pybloomfilter
    >>> fruit = pybloomfilter.BloomFilter(100000, 0.1, '/tmp/words.bloom')
    >>> fruit.update(('apple', 'pear', 'orange', 'apple'))
    >>> len(fruit)
    3
    >>> 'mike' in fruit
    False
    >>> 'apple' in fruit
    True
```

To create an in-memory filter, simply omit the file location:
```python
    >>> fruit2 = pybloomfilter.BloomFilter(10000, 0.1)
    >>> fruit2.add('apple')
    >>> 'apple' in fruit2
    True
```

These in-memory filters can be pickled and reloaded:
```python
    >>> import pickle
    >>> data = pickle.dumps(fruit2)
    >>> fruit3 = pickle.loads(data)
    >>> 'apple' in fruit3
    True
```
*Caveat*: it is currently not possible to persist this filter later as an mmap file.

## Docs

Current docs are available at [pybloomfiltermmap3.rtfd.io](https://pybloomfiltermmap3.readthedocs.io/en/latest).


## Install

To install:

```shell
    $ pip install pybloomfiltermmap3
```

and you should be set.

### Note to Python 2 to < 3.5 users

This library is specifically meant for Python 3.5 and above. [As of 2020](https://www.python.org/doc/sunset-python-2/), we strongly advise you to switch to an actively maintained distribution of Python 3. If for any reason your current environment is restricted to Python 2, please see [pybloomfiltermmap](https://github.com/axiak/pybloomfiltermmap). Please note that the latter is not actively maintained and will lack bug fixes and new features.


## History and Future

[pybloomfiltermmap](https://github.com/axiak/pybloomfiltermmap) is an excellent Bloom filter implementation for Python 2 by [@axiak](https://github.com/axiak) and contributors. I, [@prashnts](https://github.com/prashnts), made initial changes to add support for Python 3 sometime in 2016 as the current [pybloomfiltermmap3](https://pypi.org/project/pybloomfiltermmap3/) on `PyPI`. Since then, with the help of contributors, there have been incremental improvements and bug fixes while maintaining the API from versions `0.4.x` and below.

Some new features and changes were first introduced in version `0.5.0`. From this point on, the goal is to reach stability, as well as add a few more APIs to expand upon the use cases. While we can't guarantee that we won't change the current interface, the transition from versions `0.4.x` and below should be quick one liners. Please open an issue if we broke your build!

Suggestions, bug reports, and / or patches are welcome!


## Contributions and development

When contributing, you should set up an appropriate Python 3 environment and install the dependencies listed in `requirements-dev.txt`.
Package installation depends on a generated `pybloomfilter.c` file, which requires Cython module to be in your current environment.


## Maintainers

* [Prashant Sinha](https://github.com/prashnts)
* [Vytautas Mizgiris](https://github.com/vmizg)


## License

See the LICENSE file. It's under the MIT License.
