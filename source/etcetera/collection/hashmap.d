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
import core.exception;
import core.internal.hash;
import core.memory;
import core.stdc.stdlib : malloc, calloc, free;
import etcetera.collection.linkedlist;
import std.algorithm;
import std.traits;

/**
 * A generic chained hash map implementation.
 *
 * Params:
 *     K = The key type used in the hash map.
 *     V = The value type stored in the hash map.
 */
struct HashMap(K, V) if (is(K == Unqual!K) && is(V == Unqual!V))
{
	@nogc:
	nothrow:

	/**
	 * A payload stored inside the bucket linked list.
	 *
	 * Params:
	 *     K = The key type.
	 *     V = The value type.
	 */
	private static struct Payload
	{
		public K key;
		public V value;
	}

	/**
	 * The reference count.
	 */
	private int* _refCount;

	/*
	 * The type of each bucket. Because this hash map implementation is
	 * chained, each bucket represents a linked list.
	 */
	alias Bucket = LinkedList!(Payload);

	/**
	 * A pointer to the hash map bucket data.
	 */
	private Bucket* _data;

	/**
	 * The minimum amount of buckets to allocate.
	 */
	private size_t _minBuckets;

	/**
	 * The current number of buckets.
	 */
	private size_t _bucketNumber;

	/**
	 * The factor used to determine whether or not to increase the hash map's
	 * memory allocation.
	 */
	private float _loadFactor = 0.75;

	/**
	 * The number of items currently held in the hash map.
	 */
	private size_t _count;

	/*
	 * Disable the default constructor.
	 */
	@disable this();

	/**
	 * Construct a new hash map.
	 *
	 * When created, this collection is allocated enough memory for a minimum
	 * amount of items. Once a particular load has been achieved (specified by
	 * the load factor), the allocation will double, ad infinitum. If items
	 * only occupy half of the collection, the allocation will be halfed. The
	 * collection will never shrink below the minimum capacity amount.
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
	public this(size_t minBuckets)
	{
		assert(minBuckets >= 1, "Hash map must allow for at least one bucket.");

		this._refCount  = cast(int*) malloc(int.sizeof);
		*this._refCount = 1;

		this._minBuckets   = minBuckets;
		this._bucketNumber = this._minBuckets;
		this._data         = cast(Bucket*) calloc(minBuckets, Bucket.sizeof);

		if (this._data is null)
		{
			onOutOfMemoryError();
		}
	}

	/**
	 * Copy constructor post blit.
	 */
	public this(this) pure
	{
		*this._refCount += 1;
	}

	/**
	 * Destructor.
	 */
	public ~this()
	{
		*this._refCount -= 1;

		if (*this._refCount <= 0)
		{
			free(this._refCount);
			free(this._data);
		}
	}

	/**
	 * Add an item to the hash map referenced by key.
	 *
	 * Params:
	 *     key = The key under which to add the item.
	 *     item = The item to add.
	 */
	public void put(K key, V item)
	{
		if (this._count + 1 >= (this._bucketNumber * this._loadFactor))
		{
			this.resize(this._bucketNumber * 2);
		}

		auto bucket = this._data + (core.internal.hash.hashOf(key) % this._bucketNumber);

		if (bucket is null)
		{
			*bucket = Bucket([]);
		}

		foreach (index, payload; *bucket)
		{
			if (payload.key == key)
			{
				(*bucket).update(index, Payload(key, item));
				return;
			}
		}

		(*bucket).insertLast(Payload(key, item));
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
	public V get(K key)
	{
		auto bucket = this._data + (core.internal.hash.hashOf(key) % this._bucketNumber);

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
	public void remove(K key)
	{
		auto bucket = this._data + (core.internal.hash.hashOf(key) % this._bucketNumber);

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
	 *         $(PARAM_ROW AssertError, If the minimum allocated size is below the minimum bucket size.)
	 *         $(PARAM_ROW OutOfMemoryError, If memory allocation fails.)
	 *     )
	 */
	private void resize(size_t bucketNumber)
	{
		assert(bucketNumber >= this._minBuckets, "The hash map must only resize greater or equal to the minimum bucket size.");

		auto oldData         = this._data;
		auto oldBucketNumber = this._bucketNumber;

		this._bucketNumber = bucketNumber;
		this._data         = cast(Bucket*) calloc(this._bucketNumber, Bucket.sizeof);

		if (this._data is null)
		{
			onOutOfMemoryError();
		}

		this._count = 0;

		for (auto bucket = oldData; bucket < oldData + oldBucketNumber; bucket++)
		{
			if (bucket !is null)
			{
				foreach (payload; *bucket)
				{
					this.put(payload.key, payload.value);
				}

				(*bucket).clear();
			}
		}

		free(oldData);
	}

	/**
	 * Get the number of items stored in the hash map.
	 *
	 * Returns:
	 *     The number of items stored in the hash map.
	 */
	public @property size_t count() const pure
	{
		return this._count;
	}

	/**
	 * Test if the hash map is empty or not.
	 *
	 * Returns:
	 *     true if the hash map is empty, false if not.
	 */
	public @property bool empty() const pure
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
	public bool hasValue(V value)
	{
		for (auto bucket = this._data; bucket < this._data + this._bucketNumber; bucket++)
		{
			if (bucket !is null)
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
	public bool hasKey(K key)
	{
		auto bucket = this._data + (core.internal.hash.hashOf(key) % this._bucketNumber);

		if (bucket !is null)
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
	public void clear()
	{
		free(this._data);


		this._data = cast(Bucket*) calloc(this._minBuckets, Bucket.sizeof);

		if (this._data is null)
		{
			onOutOfMemoryError();
		}

		this._bucketNumber = this._minBuckets;
		this._count        = 0;
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
	public void opIndexAssign(V value, K key)
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
	public void opIndexOpAssign(string op)(V value, K key)
	{
		// static if (op == "~") { this.put(key, this.get(key) ~ value); }
		     static if (op == "+"  ) { this.put(key, this.get(key) +  value); }
		else static if (op == "-"  ) { this.put(key, this.get(key) -  value); }
		else static if (op == "*"  ) { this.put(key, this.get(key) *  value); }
		else static if (op == "/"  ) { this.put(key, this.get(key) /  value); }
		else static if (op == "%"  ) { this.put(key, this.get(key) %  value); }
		else static if (op == "^^" ) { this.put(key, this.get(key) ^^ value); }
		else static if (op == "&"  ) { this.put(key, this.get(key) &  value); }
		else static if (op == "|"  ) { this.put(key, this.get(key) |  value); }
		else static if (op == "^"  ) { this.put(key, this.get(key) ^  value); }
		else static if (op == "<<" ) { this.put(key, this.get(key) << value); }
		else static if (op == ">>" ) { this.put(key, this.get(key) >> value); }
		else static if (op == ">>>") { this.put(key, this.get(key) >> value); }
		else { assert(false, "Assignment operator not supported."); }
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
	public V opIndex(K key)
	{
		return this.get(key);
	}
}

///
unittest
{
	auto hashMap = HashMap!(string, string)(16);

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
	import std.algorithm;
	import std.conv;
	import std.stdio;

	auto hashMap = HashMap!(string, int)(16);

	assert(hashMap.empty);
	assert(hashMap.count == 0);

	int limit = 200_000;

	for (int x = 1; x <= limit ; x++)
	{
		hashMap.put(x.to!(string), x);
		assert(hashMap.get(x.to!(string)) == x);
		assert(hashMap.count == x);
	}

	assert(hashMap.get(limit.to!(string)) == limit);
	assert(hashMap.count == limit);
	assert(hashMap.hasValue(1));
	assert(hashMap.hasValue(limit));
	assert(hashMap.hasKey("1"));
	assert(hashMap.hasKey(limit.to!(string)));

	// assert(hashMap.byValue.canFind(1));
	// assert(hashMap.byValue.canFind(limit));
	// assert(hashMap.byValue.length == limit);
	assert(!hashMap.empty);

	for (int x = limit; x >= 1 ; x--)
	{
		assert(hashMap.count == x);
		assert(hashMap.get(x.to!(string)) == x);
		hashMap.remove(x.to!(string));
	}

	assert(hashMap.empty);

	for (int x = 1; x <= limit ; x++)
	{
		hashMap.put(x.to!(string), x);
		assert(hashMap.get(x.to!(string)) == x);
		assert(hashMap.count == x);
	}

	hashMap.clear();

	assert(hashMap.empty);
	assert(hashMap.count == 0);
	assert(!hashMap.hasValue(1));
	assert(!hashMap.hasValue(limit));
	assert(!hashMap.hasKey("1"));
	assert(!hashMap.hasKey(limit.to!(string)));
	// assert(hashMap.byValue.length == 0);
}

unittest
{
	auto hashMap = HashMap!(string, string)(1);
	assert(hashMap._bucketNumber == 1);

	hashMap.put("foo", "Lorem ipsum");
	assert(hashMap._bucketNumber == 2);

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
	// auto stringMap = HashMap!(string, string)(16);
	// stringMap["foo"] = "Lorem ipsum";

	// stringMap["foo"] ~= " dolor sit amet";
	// assert(stringMap["foo"] == "Lorem ipsum dolor sit amet");

	auto intMap = HashMap!(string, uint)(16);
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

