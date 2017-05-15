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

		bool opEquals()(auto ref Payload other) {
			// For the time being we have to handle classes and interfaces as a
			// special case when comparing because Object.opEquals is not @nogc.
			static if (is(V == class) || is(V == interface))
			{
				if (this.value is other.value)
				{
					return true;
				}
			}
			else
			{
				if (this.value == other.value)
				{
					return true;
				}
			}

			return false;
		}
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
					// For the time being we have to handle classes and interfaces as a
					// special case when comparing because Object.opEquals is not @nogc.
					static if (is(V == class) || is(V == interface))
					{
						if (payload.value is value)
						{
							return true;
						}
					}
					else
					{
						if (payload.value == value)
						{
							return true;
						}
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
	 * ---
	 */
	public void opIndexOpAssign(string op)(V value, K key)
	{
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
	auto map = HashMap!(string, string)(16);

	map.put("foo", "Lorem ipsum");
	map.put("bar", "Dolor sit amet");

	assert(!map.empty);
	assert(map.count == 2);

	assert(map.hasKey("foo"));
	assert(map.hasValue("Lorem ipsum"));
	assert(map.get("foo") == "Lorem ipsum");

	map.remove("bar");
	assert(!map.hasKey("bar"));

	map.clear();
	assert(!map.hasValue("Lorem ipsum"));
	assert(map.empty);
	assert(map.count == 0);
}

// Test reference counting.

unittest
{
	auto foo(T)(T map)
	{
		assert(*map._refCount == 2);
	}

	auto bar(T)(ref T map)
	{
		assert(*map._refCount == 1);
	}

	auto baz(T)(T map)
	{
		assert(*map._refCount == 1);
		return map;
	}

	auto qux()
	{
		return HashMap!(string, string)(16);
	}

	auto map = HashMap!(string, string)(16);

	assert(*map._refCount == 1);

	foo(map);
	assert(*map._refCount == 1);

	bar(map);
	assert(*map._refCount == 1);

	map = baz(HashMap!(string, string)(16));
	assert(*map._refCount == 1);

	map = qux();
	assert(*map._refCount == 1);
}

// Test big datasets.

unittest
{
	import std.algorithm;
	import std.conv;
	import std.stdio;

	auto map = HashMap!(string, int)(16);

	assert(map.empty);
	assert(map.count == 0);

	int limit = 50_000;

	for (int x = 1; x <= limit ; x++)
	{
		map.put(x.to!(string), x);
		assert(map.get(x.to!(string)) == x);
		assert(map.count == x);
	}

	assert(map.get(limit.to!(string)) == limit);
	assert(map.count == limit);
	assert(map.hasValue(1));
	assert(map.hasValue(limit));
	assert(map.hasKey("1"));
	assert(map.hasKey(limit.to!(string)));

	// assert(map.byValue.canFind(1));
	// assert(map.byValue.canFind(limit));
	// assert(map.byValue.length == limit);
	assert(!map.empty);

	for (int x = limit; x >= 1 ; x--)
	{
		assert(map.count == x);
		assert(map.get(x.to!(string)) == x);
		map.remove(x.to!(string));
	}

	assert(map.empty);

	for (int x = 1; x <= limit ; x++)
	{
		map.put(x.to!(string), x);
		assert(map.get(x.to!(string)) == x);
		assert(map.count == x);
	}

	map.clear();

	assert(map.empty);
	assert(map.count == 0);
	assert(!map.hasValue(1));
	assert(!map.hasValue(limit));
	assert(!map.hasKey("1"));
	assert(!map.hasKey(limit.to!(string)));
	// assert(map.byValue.length == 0);
}

// Test bucketizing.

unittest
{
	auto map = HashMap!(string, string)(1);
	assert(map._bucketNumber == 1);

	map.put("foo", "Lorem ipsum");
	assert(map._bucketNumber == 2);

	map.put("bar", "Dolor sit amet");
	map.put("baz", "Consectetur adipiscing elit");

	assert(map.count == 3);

	map.remove("baz");
	map.remove("foo");
	map.remove("bar");

	assert(map.empty);
}

// Test operator overloading.

unittest
{
	auto map = HashMap!(string, uint)(16);
	map["bar"] = 100;

	map["bar"] += 1;
	assert(map["bar"] == 101);

	map["bar"] -= 1;
	assert(map["bar"] == 100);

	map["bar"] *= 3;
	assert(map["bar"] == 300);

	map["bar"] /= 2;
	assert(map["bar"] == 150);

	map["bar"] %= 4;
	assert(map["bar"] == 2);

	map["bar"] ^^= 8;
	assert(map["bar"] == 256);

	map["bar"] &= 1023;
	assert(map["bar"] == 256);

	map["bar"] |= 640;
	assert(map["bar"] == 896);

	map["bar"] ^= 304;
	assert(map["bar"] == 688);

	map["bar"] <<= 2;
	assert(map["bar"] == 2752);

	map["bar"] >>= 2;
	assert(map["bar"] == 688);

	map["bar"] >>>= 5;
	assert(map["bar"] == 21);
}

// Test storing objects.

unittest
{

	class Foo
	{
		private int _foo;

		public this(int foo)
		{
			this._foo = foo;
		}
	}

	auto map = HashMap!(string, Foo)(16);
	auto foo = new Foo(1);

	map.put("foo", foo);
	map.put("bar", new Foo(3));
	map.put("baz", new Foo(2));

	assert(map.hasValue(foo));
	assert(!map.hasValue(new Foo(1)));
	assert(map.get("bar")._foo == 3);

	map.clear();
	assert(map.empty);
}

// Test storing interfaces.

unittest
{
	interface Foo
	{
		public void foo();
	}

	auto map = HashMap!(string, Foo)(16);
}

// Test storing structs.

unittest
{
	struct Foo
	{
		private int _foo;

		public this(int foo)
		{
			this._foo = foo;
		}
	}

	auto map = HashMap!(string, Foo)(16);
	auto foo = Foo(1);

	map.put("foo", foo);
	map.put("bar", Foo(3));
	map.put("baz", Foo(2));

	assert(map.hasValue(foo));
	assert(map.hasValue(Foo(1)));
	assert(map.get("bar")._foo == 3);

	map.clear();
	assert(map.empty);
}

// Test the range interface.

// Test iteration.
