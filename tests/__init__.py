import os
import functools
import tempfile

here = os.path.dirname(__file__)

def with_test_file(method):
    @functools.wraps(method)
    def _wrapped(*args, **kwargs):
        f = tempfile.NamedTemporaryFile(suffix='.bloom')
        kwargs['filename'] = f.name
        try:
            return method(*args, **kwargs)
        finally:
            f.close()
    return _wrapped
