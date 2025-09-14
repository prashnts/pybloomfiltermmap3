import pybloomfilter

def main():
    print(pybloomfilter.VERSION)
    fruit = pybloomfilter.BloomFilter(100000, 0.1, '/tmp/words.bloom')
    fruit.update(('apple', 'pear', 'orange', 'apple'))
    print(len(fruit))
    print('mike' in fruit)
    print('apple' in fruit)


if __name__ == "__main__":
    main()
