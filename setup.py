import os
import sys

from setuptools import setup, Extension

if sys.version_info < (3, 5):
    raise SystemError("This package is for Python 3.5 and above.")

here = os.path.dirname(__file__)

# Get the long description from the README file
with open(os.path.join(here, "README.markdown"), encoding="utf-8") as fp:
    long_description = fp.read()

setup_kwargs = {}

ext_files = [
    "src/mmapbitarray.c",
    "src/bloomfilter.c",
    "src/md5.c",
    "src/primetester.c",
    "src/MurmurHash3.c",
]

# Branch out based on `--cython` in `argv`. Specifying `--cython` will try to cythonize source whether
# Cython module is available or not (`force_cythonize`).
cythonize = True
force_cythonize = False

if "--cython" in sys.argv:
    force_cythonize = True
    sys.argv.remove("--cython")

# Always try to cythonize `pybloomfilter.pyx` if Cython is available
# or if `--cython` was passed
try:
    from Cython.Distutils import build_ext
except ModuleNotFoundError:
    if force_cythonize:
        print(
            "Cannot Cythonize: Cython module not found. "
            "Hint: to build pybloomfilter using the distributed "
            "source code, simply run 'python setup.py install'."
        )
        sys.exit(1)
    cythonize = False

if cythonize:
    ext_files.append("src/pybloomfilter.pyx")
    setup_kwargs["cmdclass"] = {"build_ext": build_ext}
else:
    # Use `pybloomfilter.c` distributed with the package.
    # Note that we let the exception bubble up if `pybloomfilter.c` doesn't exist.
    ext_files.append("src/pybloomfilter.c")

ext_modules = [Extension("pybloomfilter", ext_files)]

setup(
    name="pybloomfiltermmap3",
    version="0.5.5",
    author="Prashant Sinha",
    author_email="prashant@noop.pw",
    url="https://github.com/prashnts/pybloomfiltermmap3",
    description="A fast implementation of Bloom filter for Python 3 built on mmap",
    long_description=long_description,
    long_description_content_type="text/markdown",
    license="MIT License",
    test_suite="tests.test_all",
    ext_modules=ext_modules,
    python_requires=">=3.5, <4",
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
