# Metadata lives in pyproject.toml; this only declares the C extension.
from setuptools import setup, Extension

ext_files = [
    "src/mmapbitarray.c",
    "src/bloomfilter.c",
    "src/md5.c",
    "src/primetester.c",
    "src/MurmurHash3.c",
]

try:
    from Cython.Distutils import build_ext
    ext_files.append("src/pybloomfilter.pyx")
    cmdclass = {"build_ext": build_ext}
except ModuleNotFoundError:
    # Fall back to a pre-generated pybloomfilter.c, if present.
    ext_files.append("src/pybloomfilter.c")
    cmdclass = {}

setup(
    ext_modules=[Extension("pybloomfilter", ext_files)],
    cmdclass=cmdclass,
)
