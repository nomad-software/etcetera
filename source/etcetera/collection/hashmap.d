/**
 * Collection module.
 *
 * License:
 *     MIT. See LICENSE for full details.
 */
module etcetera.collection.hashmap;

/**
 * Imports.
 */
import core.memory;
import etcetera.collection.linkedlist;
import etcetera.meta;
import std.algorithm;
import std.traits;

	import std.stdio;
	import std.array;

/**
 * A payload stored inside the bucket linked list.
 *
 * Params:
 *     K = The key type.
 *     V = The value type.
 */
private struct Payload(K, V)
{
	public K key;
	public V value;
}

/**
 * A generic chained hash map implementation.
 *
 * Params:
 *     K = The key type used in the hash map.
 *     V = The value type stored in the hash map.
 */
class HashMap(K, V)
{
	/*
	 * The type of each bucket. Because this hash map implementation is
	 * chained, each bucket represents a linked list.
	 */
	alias Bucket = LinkedList!(Payload!(K, V));

	/**
	 * A pointer to the hash map bucket data.
	 */
	private Bucket* _data;

	/**
	 * The minimum amount of buckets to allocate.
	 */
	private immutable size_t _minBuckets;

	/**
	 * The current number of buckets.
	 */
	private size_t _bucketNumber;

	/**
	 * The factor used to determine whether or not to increase the hash map's
	 * memory allocation.
	 */
	private immutable float _loadFactor;

	/**
	 * The number of items currently held in the hash map.
	 */
	private size_t _count;

	/**
	 * Construct a new hash map.
	 *
	 * By default the hash map is allocated enough memory for 1,024 buckets.
	 * Each bucket can hold many items. Once a particular load has been
	 * achieved (specified by the load factor), the hash map will grow by
	 * doubling its allocation of buckets, ad infinitum. If items are removed,
	 * the hash map will reduce the amount of buckets to only use half of the
	 * current allocation. The hash map will never shrink below the minimum
	 * bucket amount.
	 *
	 * Params:
	 *     minBuckets = The minimum number of buckets to allocate space for.
	 *                   The hash map will never shrink below this allocation.
	 *     loadFactor = The factor used to determine whether or not to increase
	 *                  the hash map's memory allocation.
	 *
	 * Throws:
	 *     $(PARAM_TABLE
	 *         $(PARAM_ROW AssertError, If the minimum allocated size is not big enough for at least one bucket.)
	 *         $(PARAM_ROW OutOfMemoryError, If memory allocation fails.)
	 *     )
	 */
	final public this(size_t minBuckets = 1_024, float loadFactor = 0.75) nothrow
	{
		assert(minBuckets >= 1, "Hash map must allow for at least one bucket.");

		this._minBuckets   = minBuckets;
		this._bucketNumber = this._minBuckets;
		this._loadFactor   = loadFactor;
		this._data         = cast(Bucket*)GC.calloc(this._minBuckets * Bucket.sizeof, GC.BlkAttr.NO_MOVE, typeid(Bucket));
	}

	/**
	 * Add an item to the hash map referenced by key.
	 *
	 * Params:
	 *     key = The key under which to add the item.
	 *     item = The item to add.
	 */
	final public void put(K key, V item) nothrow
	{
		if (this._count + 1 >= (this._bucketNumber * this._loadFactor))
		{
			this.resize(this._bucketNumber * 2);
		}

		auto bucket = this._data + (hashOf(key) % this._bucketNumber);

		if (*bucket is null)
		{
			*bucket = new Bucket;
		}

		foreach (index, payload; *bucket)
		{
			if (payload.key == key)
			{
				(*bucket).update(index, Payload!(K, V)(key, item));
				return;
			}
		}

		(*bucket).insertLast(Payload!(K, V)(key, item));
		this._count++;
	}

	/**
	 * Get an item from the hash map referenced by key. The key must
	 * exist in the hash map or an error will be raised.
	 *
	 * Params:
	 *     key = The key of the item to get.
	 *
	 * Returns:
	 *     The value stored with the passed key.
	 *
	 * Throws:
	 *     $(PARAM_TABLE
	 *         $(PARAM_ROW AssertError, If key doesn't exist in the hash map.)
	 *     )
	 */
	final public V get(K key) nothrow
	{
		auto bucket = this._data + (hashOf(key) % this._bucketNumber);

		foreach (payload; *bucket)
		{
			if (payload.key == key)
			{
				return payload.value;
			}
		}

		assert(false, "Key does not exist in hash map.");
	}

	/**
	 * Remove an item from the hash map referenced by key. No errors are raised
	 * if key doesn't exist in the hash map.
	 *
	 * Params:
	 *     key = The key of the item to remove.
	 */
	final public void remove(K key) nothrow
	{
		auto bucket = this._data + (hashOf(key) % this._bucketNumber);

		foreach (index, payload; *bucket)
		{
			if (payload.key == key)
			{
				(*bucket).remove(index);
				this._count--;
			}
		}

		if ((this._bucketNumber / 2) > this._minBuckets && this._count < ((this._bucketNumber / 2) * this._loadFactor))
		{
			this.resize(this._bucketNumber / 2);
		}
	}

	/**
	 * Resize the amount of buckets available.
	 *
	 * Params:
	 *     bucketNumber = The number of buckets to resize to.
	 *
	 * Throws:
	 *     $(PARAM_TABLE
	 *         $(PARAM_ROW AssertError, If the minimum allocated size is not big enough for at least one bucket.)
	 *         $(PARAM_ROW OutOfMemoryError, If memory allocation fails.)
	 *     )
	 */
	final private void resize(size_t bucketNumber) nothrow
	{
		assert(bucketNumber >= this._minBuckets, "The hash map must only resize greater or equal to the minimum bucket size.");

		auto oldData         = this._data;
		auto oldBucketNumber = this._bucketNumber;

		this._bucketNumber = bucketNumber;
		this._data         = cast(Bucket*)GC.calloc(this._bucketNumber * Bucket.sizeof, GC.BlkAttr.NO_MOVE, typeid(Bucket));
		this._count        = 0;

		for (auto bucket = oldData; bucket < oldData + oldBucketNumber; bucket++)
		{
			if (*bucket !is null)
			{
				foreach (payload; *bucket)
				{
					this.put(payload.key, payload.value);
				}
			}
		}

		GC.free(oldData);
	}

	/**
	 * Get the number of items stored in the hash map.
	 *
	 * Returns:
	 *     The number of items stored in the hash map.
	 */
	final public @property size_t count() const nothrow pure
	{
		return this._count;
	}

	/**
	 * Test if the hash map is empty or not.
	 *
	 * Returns:
	 *     true if the hash map is empty, false if not.
	 */
	final public @property bool empty() const nothrow pure
	{
		return (this._count == 0);
	}

	/**
	 * Returns true if the value is contained within the hash map.
	 *
	 * This is a simple linear search and can take quite some time with large
	 * hash maps.
	 *
	 * Params:
	 *     value = The value to check.
	 *
	 * Returns:
	 *     true if the value id found, false if not.
	 */
	final public bool hasValue(V value) nothrow
	{
		for (auto bucket = this._data; bucket < this._data + this._bucketNumber; bucket++)
		{
			if (*bucket !is null)
			{
				foreach (payload; *bucket)
				{
					if (payload.value == value)
					{
						return true;
					}
				}
			}
		}

		return false;
	}

	/**
	 * Returns true if the key is used within the hash map.
	 *
	 * This is a simple linear search and can take quite some time with large
	 * hash maps.
	 *
	 * Params:
	 *     key = The key to check.
	 *
	 * Returns:
	 *     true if the key is used, false if not.
	 */
	final public bool hasKey(K key) nothrow
	{
		auto bucket = this._data + (hashOf(key) % this._bucketNumber);

		if (*bucket !is null)
		{
			foreach (payload; *bucket)
			{
				if (payload.key == key)
				{
					return true;
				}
			}
		}

		return false;
	}

	/**
	 * Clears the hash map.
	 *
	 * This method reallocates the memory used by the hash map to the minimum
	 * bucket size if more is currently allocated.
	 *
	 * Throws:
	 *     $(PARAM_TABLE
	 *         $(PARAM_ROW OutOfMemoryError, If memory reallocation fails.)
	 *     )
	 */
	final public void clear() nothrow
	{
		for (auto bucket = this._data; bucket < this._data + this._bucketNumber; bucket++)
		{
			if (*bucket !is null)
			{
				(*bucket).clear();
			}
		}

		this.resize(this._minBuckets);
	}

	/**
	 * Overload the index assignment operator to set values using a key.
	 *
	 * Params:
	 *     value = The value to store.
	 *     key = The key to store the value against.
	 *
	 * Example:
	 * ---
	 * hashMap["foo"] = "Lorem ipsum";
	 * ---
	 */
	final public void opIndexAssign(V value, K key) nothrow
	{
		this.put(key, value);
	}

	/**
	 * Overload index assignment operators to modify values referenced by key.
	 *
	 * Params:
	 *     value = The value to store.
	 *     key = The key to store the value against.
	 *
	 * Example:
	 * ---
	 * hashMap["foo"] += 1;
	 * hashMap["foo"] -= 2;
	 * hashMap["foo"] *= 3;
	 * hashMap["foo"] /= 4;
	 * hashMap["foo"] %= 5;
	 * hashMap["foo"] ^^= 6;
	 * hashMap["foo"] &= 7;
	 * hashMap["foo"] |= 8;
	 * hashMap["foo"] ^= 9;
	 * hashMap["foo"] <<= 10;
	 * hashMap["foo"] >>= 11;
	 * hashMap["foo"] >>>= 12;
	 * hashMap["bar"] ~= "Lorem ipsum";
	 * ---
	 */
	final public void opIndexOpAssign(string op)(V value, K key) nothrow
	{
		mixin("this.put(key, this.get(key) " ~ op ~ " value);");
	}

	/**
	 * Overload the index operator to retrieve values via a key.
	 *
	 * Params:
	 *     key = The key from which to retrieve the value.
	 *
	 * Example:
	 * ---
	 * assert(hashMap["foo"] == "Lorem ipsum");
	 * ---
	 */
	final public V opIndex(K key) nothrow
	{
		return this.get(key);
	}
}

///
unittest
{
	auto hashMap = new HashMap!(string, string);

	hashMap.put("foo", "Lorem ipsum");
	hashMap.put("bar", "Dolor sit amet");

	assert(!hashMap.empty);
	assert(hashMap.count == 2);

	assert(hashMap.hasKey("foo"));
	assert(hashMap.hasValue("Lorem ipsum"));
	assert(hashMap.get("foo") == "Lorem ipsum");

	hashMap.remove("bar");
	assert(!hashMap.hasKey("bar"));

	hashMap.clear();
	assert(!hashMap.hasValue("Lorem ipsum"));
	assert(hashMap.empty);
	assert(hashMap.count == 0);
}

unittest
{
	auto hashMap = new HashMap!(string, string)(1);

	hashMap.put("foo", "Lorem ipsum");
	hashMap.put("bar", "Dolor sit amet");
	hashMap.put("baz", "Consectetur adipiscing elit");

	assert(hashMap.count == 3);

	hashMap.remove("baz");
	hashMap.remove("foo");
	hashMap.remove("bar");

	assert(hashMap.empty);
}

unittest
{
	auto stringMap = new HashMap!(string, string);
	stringMap["foo"] = "Lorem ipsum";

	stringMap["foo"] ~= " dolor sit amet";
	assert(stringMap["foo"] == "Lorem ipsum dolor sit amet");

	auto intMap = new HashMap!(string, uint);
	intMap["bar"] = 100;

	intMap["bar"] += 1;
	assert(intMap["bar"] == 101);

	intMap["bar"] -= 1;
	assert(intMap["bar"] == 100);

	intMap["bar"] *= 3;
	assert(intMap["bar"] == 300);

	intMap["bar"] /= 2;
	assert(intMap["bar"] == 150);

	intMap["bar"] %= 4;
	assert(intMap["bar"] == 2);

	intMap["bar"] ^^= 8;
	assert(intMap["bar"] == 256);

	intMap["bar"] &= 1023;
	assert(intMap["bar"] == 256);

	intMap["bar"] |= 640;
	assert(intMap["bar"] == 896);

	intMap["bar"] ^= 304;
	assert(intMap["bar"] == 688);

	intMap["bar"] <<= 2;
	assert(intMap["bar"] == 2752);

	intMap["bar"] >>= 2;
	assert(intMap["bar"] == 688);

	intMap["bar"] >>>= 5;
	assert(intMap["bar"] == 21);
}

