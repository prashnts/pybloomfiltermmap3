# cython: language_level=3

VERSION = (0, 5, 7)
AUTHOR = "Michael Axiak"

__VERSION__ = VERSION


cimport cbloomfilter
cimport cpython

import array
from base64 import b64encode, b64decode
import errno as eno
import math
import os
import random
import shutil
import sys
import warnings
import zlib


cdef extern int errno
cdef NoConstruct = object()


cdef _construct_access(mode):
    result = os.F_OK
    if 'w' in mode:
        result |= os.W_OK
    if 'r' in mode:
        result |= os.R_OK
    return result


cdef _construct_mode(mode):
    result = os.O_RDONLY
    if 'w' in mode:
        result |= os.O_RDWR
    if 'b' in mode and hasattr(os, 'O_BINARY'):
        result |= os.O_BINARY
    if mode.endswith('+'):
        result |= os.O_CREAT
    return result


cdef class BloomFilter:
    """
    Creates a new BloomFilter object with a given capacity and error_rate.

    :param int capacity: the maximum number of elements this filter
        can contain while keeping the false positive rate under ``error_rate``.
    :param float error_rate: false positive probability that will hold
        given that ``capacity`` is not exceeded.
    :param str filename: filename to use to create the new Bloom filter.
        If a filename is not provided, an in-memory Bloom filter will be created.
    :param str mode: (*not applicable for an in-memory Bloom filter*)
        file access mode.
    :param int perm: (*not applicable for an in-memory Bloom filter*)
        file access permission flags.
    :param list hash_seeds: optionally specify hash seeds to use for the
        hashing algorithm. Each hash seed must not exceed 32 bits. The number
        of hash seeds will determine the number of hashes performed.

    **Note that we do not check capacity.** This is important, because
    we want to be able to support logical OR and AND (see :meth:`BloomFilter.union`
    and :meth:`BloomFilter.intersection`). The capacity and error_rate then together
    serve as a contract -- you add less than capacity items, and the Bloom filter
    will have an error rate less than error_rate.

    Raises :class:`OSError` if the supplied filename does not exist or if user
    lacks permission to access such file. Raises :class:`ValueError` if the supplied
    ``error_rate`` is invalid, ``hash_seeds`` does not contain valid hash seeds, or
    if the file cannot be read.
    """

    cdef cbloomfilter.BloomFilter * _bf
    cdef int _closed
    cdef int _in_memory
    cdef int _oflags

    def __cinit__(self, capacity, error_rate, filename=None, perm=0755, hash_seeds=None):
        self._closed = 0
        self._in_memory = 0
        self._oflags = os.O_RDWR

        if capacity is NoConstruct:
            return

        self._create(capacity, error_rate, filename, perm, hash_seeds)

    def _create(self, capacity, error_rate, filename=None, perm=0755, hash_seeds=None):
        cdef char * seeds
        cdef long long num_bits

        # Make sure that if the filename is defined, that the
        # file exists
        if filename and os.path.exists(filename):
            os.unlink(filename)

        # For why we round down for determining the number of hashes:
        # http://corte.si/%2Fposts/code/bloom-filter-rules-of-thumb/index.html
        # "The number of hashes determines the number of bits that need to
        # be read to test for membership, the number of bits that need to be
        # written to add an element, and the amount of computation needed to
        # calculate hashes themselves. We may sometimes choose to use a less
        # than optimal number of hashes for performance reasons (especially
        # when we choose to round down when the calculated optimal number of
        # hashes is fractional)."

        if not (0 < error_rate < 1):
            raise ValueError("error_rate allowable range (0.0, 1.0) %f" % (error_rate,))

        array_seeds = array.array('I')

        if hash_seeds:
            for seed in hash_seeds:
                if not isinstance(seed, int) or seed < 0 or seed.bit_length() > 32:
                    raise ValueError("invalid hash seed '%s', must be >= 0 "
                                        "and up to 32 bits in size" % seed)
            num_hashes = len(hash_seeds)
            array_seeds.extend(hash_seeds)
        else:
            num_hashes = max(math.floor(math.log2(1 / error_rate)), 1)
            array_seeds.extend([random.getrandbits(32) for i in range(num_hashes)])

        test = array_seeds.tobytes()
        seeds = test

        bits_per_hash = math.ceil(
                capacity * abs(math.log(error_rate)) /
                (num_hashes * (math.log(2) ** 2)))

        # Minimum bit vector of 128 bits
        num_bits = max(num_hashes * bits_per_hash,128)

        # print("k = %d  m = %d  n = %d   p ~= %.8f" % (
        #     num_hashes, num_bits, capacity,
        #     (1.0 - math.exp(- float(num_hashes) * float(capacity) / num_bits))
        #     ** num_hashes))

        # If a filename is provided, we should make a mmap-file
        # backed bloom filter. Otherwise, it will be malloc
        if filename:
            self._bf = cbloomfilter.bloomfilter_Create_Mmap(capacity,
                                                    error_rate,
                                                    filename.encode(),
                                                    num_bits,
                                                    self._oflags | os.O_CREAT,
                                                    perm,
                                                    <int *>seeds,
                                                    num_hashes)
        else:
            self._in_memory = 1
            self._bf = cbloomfilter.bloomfilter_Create_Malloc(capacity,
                                                    error_rate,
                                                    num_bits,
                                                    <int *>seeds,
                                                    num_hashes)
        if self._bf is NULL:
            if filename:
                raise OSError(errno, '%s: %s' % (os.strerror(errno),
                                                    filename))
            else:
                cpython.PyErr_NoMemory()

    def _open(self, filename, mode="rw"):
        # Should not overwrite
        mode = mode.replace("+", "")

        if not os.path.exists(filename):
            raise OSError(eno.ENOENT, '%s: %s' % (os.strerror(eno.ENOENT),
                                                        filename))
        if not os.access(filename, _construct_access(mode)):
            raise OSError("Insufficient permissions for file %s" % filename)

        self._oflags = _construct_mode(mode)
        self._bf = cbloomfilter.bloomfilter_Create_Mmap(0,
                                                0,
                                                filename.encode(),
                                                0,
                                                self._oflags,
                                                0,
                                                NULL, 0)
        if self._bf is NULL:
            raise ValueError("Invalid %s file: %s" %
                                (self.__class__.__name__, filename))

    def __dealloc__(self):
        cbloomfilter.bloomfilter_Destroy(self._bf)
        self._bf = NULL

    @property
    def bit_array(self):
        """Bit vector representation of the Bloom filter contents.
        Returns an integer.
        """
        self._assert_open()
        start_pos = self._bf.array.preamblebytes
        end_pos = start_pos + self._bf.array.bytes
        arr = (<char *>cbloomfilter.mbarray_CharData(self._bf.array))[start_pos:end_pos]
        return int.from_bytes(arr, byteorder="big", signed=False)

    @property
    def hash_seeds(self):
        """Integer seeds used for the random hashing. Returns a list of integers."""
        self._assert_open()
        seeds = array.array('I')
        seeds.frombytes(
            (<char *>self._bf.hash_seeds)[:4 * self.num_hashes]
        )
        return seeds

    @property
    def capacity(self):
        """The maximum number of elements this filter can contain while keeping
        the false positive rate under :attr:`BloomFilter.error_rate`.
        Returns an integer.
        """
        self._assert_open()
        return self._bf.max_num_elem

    @property
    def error_rate(self):
        """The acceptable probability of false positives. Returns a float."""
        self._assert_open()
        return self._bf.error_rate

    @property
    def num_hashes(self):
        """Number of hash functions used when computing."""
        self._assert_open()
        return self._bf.num_hashes

    @property
    def num_bits(self):
        """Number of bits used in the filter as buckets."""
        self._assert_open()
        return self._bf.array.bits

    @property
    def bit_count(self):
        """Number of bits set to one."""
        self._assert_open()
        return cbloomfilter.mbarray_BitCount(self._bf.array)

    @property
    def approx_len(self):
        """Approximate number of items in the set.

        See also:
        - https://en.wikipedia.org/wiki/Bloom_filter#The_union_and_intersection_of_sets
        - https://citeseerx.ist.psu.edu/viewdoc/download?doi=10.1.1.1063.3591&rep=rep1&type=pdf
        """
        m = self.num_bits
        k = self.num_hashes
        X = self.bit_count

        n = -(m / k) * math.log(1 - (X / m), math.e)
        return round(n)

    def _name(self):
        self._assert_open()
        if self._in_memory:
            raise NotImplementedError('Cannot access .name on an in-memory %s'
                                        % self.__class__.__name__)
        if self._bf.array.filename is NULL:
            return None
        return self._bf.array.filename

    @property
    def name(self):
        """PENDING DEPRECATION - use :meth:`BloomFilter.filename` instead.

        File name (compatible with file objects). Does not apply to an in-memory
        :class:`BloomFilter` and will raise :class:`ValueError` if accessed.
        Returns an encoded string.
        """
        warnings.warn('name will be deprecated in future versions, use '
                      'filename instead', PendingDeprecationWarning)
        return self._name()

    @property
    def filename(self):
        """File name (compatible with file objects). Does not apply to an in-memory
        :class:`BloomFilter` and will raise :class:`ValueError` if accessed.
        Returns a string.
        """
        return self._name().decode()

    @property
    def read_only(self):
        """Indicates if the opened :class:`BloomFilter` is read-only.
        Always ``False`` for an in-memory :class:`BloomFilter`.
        """
        self._assert_open()
        return not self._in_memory and not self._oflags & os.O_RDWR

    def fileno(self):
        """Bloom filter file descriptor."""
        self._assert_open()
        return self._bf.array.fd

    def __repr__(self):
        self._assert_open()
        my_name = self.__class__.__name__
        return '<%s capacity: %d, error: %0.3f, num_hashes: %d>' % (
            my_name, self._bf.max_num_elem, self._bf.error_rate,
            self._bf.num_hashes)

    def __str__(self):
        return self.__repr__()

    def sync(self):
        """Forces a ``sync()`` call on the underlying mmap file object. Use this if
        you are about to copy the file and you want to be sure you got
        everything correctly.
        """
        self._assert_open()
        self._assert_writable()
        cbloomfilter.mbarray_Sync(self._bf.array)

    def clear_all(self):
        """Removes all elements from the Bloom filter at once."""
        self._assert_open()
        self._assert_writable()
        cbloomfilter.bloomfilter_Clear(self._bf)

    def __contains__(self, item_):
        """Checks to see if item is contained in the filter, with
        an acceptable false positive rate of :attr:`BloomFilter.error_rate`.

        :param item: hashable object
        :rtype: bool
        """
        self._assert_open()
        cdef cbloomfilter.Key key
        if isinstance(item_, str):
            item = item_.encode()
            key.shash = item
            key.nhash = len(item)
        elif isinstance(item_, bytes):
            item = item_
            key.shash = item
            key.nhash = len(item)
        else:
            item = item_
            key.shash = NULL
            key.nhash = hash(item)
        return cbloomfilter.bloomfilter_Test(self._bf, &key) == 1

    def copy_template(self, filename, perm=0755):
        """Creates a new :class:`BloomFilter` object with the exact same parameters.
        Once this is performed, the two filters are comparable, so
        you can perform set operations using logical operators.

        :param str filename: new filename
        :param int perm: file access permission flags
        :rtype: :class:`BloomFilter`
        """
        self._assert_open()
        cdef BloomFilter copy = BloomFilter(NoConstruct, 0)
        if os.path.exists(filename):
            os.unlink(filename)
        copy._bf = cbloomfilter.bloomfilter_Copy_Template(self._bf, filename.encode(), perm)
        return copy

    def copy(self, filename):
        """Copies the current :class:`BloomFilter` object to another object
        with a new filename.

        :param str filename: new filename
        :rtype: :class:`BloomFilter`
        """
        self._assert_open()
        if self._in_memory:
            raise NotImplementedError('Cannot call .copy on an in-memory %s' %
                                      self.__class__.__name__)
        shutil.copy(self._bf.array.filename, filename)
        return self.open(filename)

    def add(self, item_):
        """Adds an item to the Bloom filter. Returns a boolean indicating whether
        this item was present in the Bloom filter prior to adding
        (see :meth:`BloomFilter.__contains__`).

        :param item: hashable object
        :rtype: bool
        """
        self._assert_open()
        self._assert_writable()
        cdef cbloomfilter.Key key
        if isinstance(item_, str):
            item = item_.encode()
            key.shash = item
            key.nhash = len(item)
        elif isinstance(item_, bytes):
            item = item_
            key.shash = item
            key.nhash = len(item)
        else:
            item = item_
            key.shash = NULL
            key.nhash = hash(item)

        result = cbloomfilter.bloomfilter_Add(self._bf, &key)
        if result == 2:
            raise RuntimeError("Some problem occured while trying to add key.")
        return bool(result)

    def update(self, iterable):
        """Calls :meth:`BloomFilter.add` on all items in the iterable."""
        for item in iterable:
            self.add(item)

    def __len__(self):
        """Returns the number of distinct elements that have been
        added to the :class:`BloomFilter` object, subject to the error
        given in :attr:`BloomFilter.error_rate`.

        The length reported here is exact as long as no set `union` or
        `intersection` were performed. Otherwise we report an approximation
        of based on :attr:`BloomFilter.bit_count`.

        :param item: hashable object
        :rtype: int
        """
        self._assert_open()
        if not self._bf.count_correct:
            return self.approx_len
        return self._bf.elem_count

    def close(self):
        """Closes the currently opened :class:`BloomFilter` file descriptor.
        Following accesses to this instance will raise a :class:`ValueError`.

        *Caution*: this will delete an in-memory filter irrecoverably!
        """
        if self._closed == 0:
            self._closed = 1
            cbloomfilter.bloomfilter_Destroy(self._bf)
            self._bf = NULL

    def union(self, BloomFilter other):
        """Performs a set OR with another comparable filter. You can (only) construct
        comparable filters with :meth:`BloomFilter.copy_template` above.

        The computation will occur *in place*. That is, calling::

            >>> bf.union(bf2)

        is a way of adding *all* the elements of ``bf2`` to ``bf``.

        *NB: Calling this function will render future calls to len()
        invalid.*

        :param BloomFilter other: filter to perform the union with
        :rtype: :class:`BloomFilter`
        """
        self._assert_open()
        self._assert_writable()
        other._assert_open()
        self._assert_comparable(other)
        cbloomfilter.mbarray_Or(self._bf.array, other._bf.array)
        self._bf.count_correct = 0
        return self

    def __ior__(self, BloomFilter other):
        """See :meth:`BloomFilter.union`."""
        return self.union(other)

    def intersection(self, BloomFilter other):
        """The same as :meth:`BloomFilter.union` above except it uses
        a set AND instead of a set OR.

        *NB: Calling this function will render future calls to len()
        invalid.*

        :param BloomFilter other: filter to perform the intersection with
        :rtype: :class:`BloomFilter`
        """
        self._assert_open()
        self._assert_writable()
        other._assert_open()
        self._assert_comparable(other)
        cbloomfilter.mbarray_And(self._bf.array, other._bf.array)
        self._bf.count_correct = 0
        return self

    def __iand__(self, BloomFilter other):
        """See :meth:`BloomFilter.intersection`."""
        return self.intersection(other)

    def _assert_open(self):
        if self._closed != 0:
            raise ValueError("I/O operation on closed file")

    def _assert_writable(self):
        if self.read_only:
            raise ValueError("Write operation on read-only file")

    def _assert_comparable(self, BloomFilter other):
        error = ValueError("The two %s objects are not the same type (hint: "
                           "use copy_template)" % self.__class__.__name__)
        if self._bf.array.bits != other._bf.array.bits:
            raise error
        if self.hash_seeds != other.hash_seeds:
            raise error
        return

    def to_base64(self):
        """Creates a compressed, base64 encoded version of the :class:`BloomFilter`.
        Since the Bloom filter is efficiently in binary on the file system,
        this may not be too useful. I find it useful for debugging so I can
        copy filters from one terminal to another in their entirety.

        :rtype: base64 encoded string representing filter
        """
        self._assert_open()
        bfile = open(self.filename, "rb")
        fl_content = bfile.read()
        result = b64encode(zlib.compress(b64encode(zlib.compress(
            fl_content, 9))))
        bfile.close()
        return result

    @classmethod
    def from_base64(cls, filename, string, perm=0755):
        """Unpacks the supplied base64 string (as returned by :meth:`BloomFilter.to_base64`)
        into the supplied filename and return a :class:`BloomFilter` object using that
        file.

        :param str filename: new filename
        :param int perm: file access permission flags
        :rtype: :class:`BloomFilter`
        """
        bfile_fp = os.open(filename, _construct_mode("w+"), perm)
        os.write(bfile_fp, zlib.decompress(b64decode(zlib.decompress(
            b64decode(string)))))
        os.close(bfile_fp)
        return cls.open(filename)

    @classmethod
    def open(cls, filename, mode="rw"):
        """Creates a :class:`BloomFilter` object from an existing file.

        :param str filename: existing filename
        :param str mode: file access mode
        :rtype: :class:`BloomFilter`
        """
        instance = cls(NoConstruct, 0)
        instance._open(filename, mode)
        return instance
