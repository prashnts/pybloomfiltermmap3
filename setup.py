import os
import sys

from setuptools import setup, Extension

if sys.version_info[0] < 3:
    raise SystemError("This package is for Python version 3 and above.")

here = os.path.dirname(__file__)

# Get the long description from the README file
with open(os.path.join(here, "README.markdown"), encoding="utf-8") as fp:
    long_description = fp.read()

setup_kwargs = {}

ext_files = [
    "src/mmapbitarray.c",
    "src/bloomfilter.c",
    "src/md5.c",
    "src/xxhash.c",
    "src/primetester.c",
    "src/MurmurHash3.c",
]

# Branch out based on `--no-cython` in `argv`.
# Assume `--cython` as default to avoid having to deal with both params being there.

if "--no-cython" in sys.argv:
    # Use the distributed `pybloomfilter.c`.
    # Note that we let the exception bubble up if `pybloomfilter.c` doesn't exist.
    ext_files.append("src/pybloomfilter.c")
    sys.argv.remove("--no-cython")
else:
    # Cythonize `pybloomfilter.pyx`
    try:
        from Cython.Distutils import build_ext
    except ModuleNotFoundError:
        print(
            "Cython module not found. Hint: to build pybloomfilter using the distributed "
            "source code, run 'python setup.py install --no-cython'."    
        )
        sys.exit(1)

    ext_files.append("src/pybloomfilter.pyx")
    setup_kwargs["cmdclass"] = {"build_ext": build_ext}

ext_modules = [Extension("pybloomfilter", ext_files)]

setup(
    name="pybloomfiltermmap3",
    version="0.4.19",
    author="Michael Axiak, Rob Stacey, Prashant Sinha",
    author_email="prashant@noop.pw",
    url="https://github.com/prashnts/pybloomfiltermmap3",
    description="A fast implementation of Bloom filter for Python 3 built on mmap",
    long_description=long_description,
    long_description_content_type="text/markdown",
    license="MIT License",
    test_suite="tests.test_all",
    ext_modules=ext_modules,
    classifiers=[
        "Development Status :: 4 - Beta",
        "Intended Audience :: Developers",
        "Intended Audience :: Science/Research",
        "License :: OSI Approved :: MIT License",
        "Programming Language :: C",
        "Programming Language :: Cython",
        "Programming Language :: Python",
        "Programming Language :: Python :: 3",
        "Topic :: Software Development :: Libraries :: Python Modules",
    ],
    **setup_kwargs
)
