import pybloomfilter
import random
import pickle

def main():
    print(pybloomfilter.VERSION)
    fruit = pybloomfilter.BloomFilter(100000, 0.1, '/tmp/words.bloom')
    fruit.update(('apple', 'pear', 'orange', 'apple'))
    print(len(fruit))
    print('mike' in fruit)
    print('apple' in fruit)


    bf = pybloomfilter.BloomFilter(1_000_000, 0.01)
    test_keys = ('kiwi', 'banana', 'mango', 'grape', 'watermelon', 'peach', 'plum', 'cherry', 'blueberry', 'raspberry')

    bf.update(test_keys)

    for key in test_keys:
        assert key in bf
    
    serialized = pickle.dumps(bf)
    deserialized = pickle.loads(serialized)

    for key in test_keys:
        assert key in deserialized, f"Key {key} missing after deserialization"



if __name__ == "__main__":
    main()
