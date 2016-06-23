/**
 * Collection module.
 *
 * License:
 *     MIT. See LICENSE for full details.
 */
module etcetera.collection.queue;

/**
 * Imports.
 */
import core.exception;
import core.memory;
import core.stdc.stdlib : malloc, calloc, realloc, free;
import core.stdc.string : memcpy, memmove, memset;
import std.range;
import std.traits;

/**
 * A generic first-in-first-out (FIFO) queue implementation.
 *
 * Params:
 *     T = The type stored in the queue.
 */
struct Queue(T)
{
	@nogc:
	nothrow:

	/**
	 * The reference count.
	 */
	private int* _refCount;

	/**
	 * A pointer to the queue data.
	 */
	private T* _data;

	/**
	 * A pointer to the front of the queue.
	 */
	private T* _front;

	/**
	 * The offset of the front inside the allocated memory.
	 */
	private size_t _frontOffset;

	/**
	 * A pointer to the back of the queue.
	 */
	private T* _back;

	/**
	 * The offset of the back inside the allocated memory.
	 */
	private size_t _backOffset;

	/**
	 * The minimum size in bytes that the queue will allocate.
	 */
	private size_t _minSize;

	/**
	 * The current size in bytes of the queue.
	 */
	private size_t _size;

	/**
	 * The number of items currently held in the queue.
	 */
	private size_t _count;

	/*
	 * Disable the default constructor.
	 */
	@disable this();

	/**
	 * Construct a new queue.
	 *
	 * By default the queue is allocated enough memory for 8,192 items. If more
	 * items are added, the queue can grow by doubling its allocation, ad
	 * infinitum. If the items within reduce to only use half of the current
	 * allocation the queue will half it. The queue will never shrink below the
	 * minimum capacity amount.
	 *
	 * Params:
	 *     minCapacity = The minimum number of items to allocate space for.
	 *                   The queue will never shrink below this allocation.
	 *
	 * Throws:
	 *     $(PARAM_TABLE
	 *         $(PARAM_ROW AssertError, If the minimum allocated size is not big enough for at least one item.)
	 *         $(PARAM_ROW OutOfMemoryError, If memory allocation fails.)
	 *     )
	 */
	public this(size_t minCapacity)
	{
		assert(minCapacity >= 1, "Queue must allow for at least one item.");

		this._refCount  = cast(int*) malloc(int.sizeof);
		*this._refCount = 1;

		this._minSize = minCapacity * T.sizeof;
		this._size    = this._minSize;
		this._data    = cast(T*) calloc(minCapacity, T.sizeof);

		if (this._data is null)
		{
			onOutOfMemoryError();
		}

		static if (hasIndirections!(T))
		{
			GC.addRange(this._data, this._size, typeid(T));
		}

		this._front = this._data;
		this._back  = this._data - 1;
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
			GC.removeRange(this._data);

			free(this._refCount);
			free(this._data);
		}
	}

	/**
	 * Get the number of items stored in the queue.
	 *
	 * Returns:
	 *     The number of items stored in the queue.
	 */
	public @property size_t count() const pure
	{
		return this._count;
	}

	/**
	 * Test if the queue is empty or not.
	 *
	 * Returns:
	 *     true if the queue is empty, false if not.
	 */
	public @property bool empty() const pure
	{
		return (this._count == 0);
	}

	/**
	 * The current item capacity of the queue. This will change if the queue
	 * reallocates more memory.
	 *
	 * Returns:
	 *     The capacity of how many items the queue can hold.
	 */
	private @property size_t capacity() const pure
	{
		return this._size / T.sizeof;
	}

	/**
	 * Add an item to the queue.
	 *
	 * This method reallocates and doubles the memory used by the queue if no
	 * more items can be stored in available memory.
	 *
	 * Params:
	 *     item = The item to push onto the queue.
	 *
	 * Throws:
	 *     $(PARAM_TABLE
	 *         $(PARAM_ROW OutOfMemoryError, If memory reallocation fails.)
	 *     )
	 */
	public void enqueue(T item)
	{
		if (this._count == this.capacity)
		{
			GC.removeRange(this._data);

			this._frontOffset = this._front - this._data;

			this._size *= 2;
			this._data  = cast(T*) realloc(this._data, this._size);

			if (this._data is null)
			{
				onOutOfMemoryError();
			}

			static if (hasIndirections!(T))
			{
				GC.addRange(this._data, this._size, typeid(T));
			}

			if (this._frontOffset > 0)
			{
				memcpy(this._data + this._count, this._data, this._frontOffset * T.sizeof);
				memmove(this._data, this._data + this._frontOffset, this._count * T.sizeof);
			}

			this._front = this._data;
			this._back  = this._data + (this._count - 1);

			memset(this._data + this._count, 0, this._size / 2);
		}

		this._back++;

		if (this._back == (this._data + this.capacity))
		{
			this._back = this._data;
		}

		this._count++;

		*this._back = item;
	}

	/**
	 * Return the front item in the queue but don't remove it.
	 *
	 * Returns:
	 *     The front item in the queue.
	 *
	 * Throws:
	 *     $(PARAM_TABLE
	 *         $(PARAM_ROW AssertError, If the queue is empty.)
	 *     )
	 */
	public T peek() pure
	{
		assert(this._count, "Queue empty, peeking failed.");

		return *this._front;
	}

	/**
	 * Remove and return the front item in the queue.
	 *
	 * This method reallocates the memory used by the queue, halfing it if
	 * half will adequately hold all the items.
	 *
	 * Returns:
	 *     The front item in the queue.
	 *
	 * Throws:
	 *     $(PARAM_TABLE
	 *         $(PARAM_ROW AssertError, If the queue is empty.)
	 *         $(PARAM_ROW OutOfMemoryError, If memory reallocation fails.)
	 *     )
	 */
	public T dequeue()
	{
		assert(this._count, "Queue empty, dequeuing failed.");

		this._count--;
		auto dequeued = *(this._front);

		memset(this._front, 0, T.sizeof);

		this._front++;

		if (this._front == (this._data + this.capacity))
		{
			this._front = this._data;
		}

		if ((this._count <= (this.capacity / 2)) && ((this._size / 2) >= this._minSize))
		{
			this._frontOffset = this._front - this._data;
			this._backOffset  = this._back - this._data;

			if (this._front > this._back)
			{
				memmove(this._data + (this.capacity - this._frontOffset), this._data, (this._backOffset + 1) * T.sizeof);
				memcpy(this._data, this._front, (this.capacity - this._frontOffset) * T.sizeof);
			}
			else
			{
				memmove(this._data, this._front, (this._count + 1) * T.sizeof);
			}

			GC.removeRange(this._data);

			this._size /= 2;
			this._data  = cast(T*) realloc(this._data, this._size);

			if (this._data is null)
			{
				onOutOfMemoryError();
			}

			static if (hasIndirections!(T))
			{
				GC.addRange(this._data, this._size, typeid(T));
			}

			this._front = this._data;
			this._back  = this._data + (this.capacity - 1);
		}

		return dequeued;
	}

	/**
	 * Check if a value is contained in the queue.
	 *
	 * This is a simple linear search and can take quite some time with large
	 * queues.
	 *
	 * Params:
	 *     item = The item to find in the queue.
	 *
	 * Returns:
	 *     true if the item is found on the queue, false if not.
	 */
	public bool contains(T item)
	{
		if (!this.empty)
		{
			for (T* x = this._data; x < this._data + this.capacity ; x++)
			{
				if (this._front > this._back && x > this._back && x < this._front)
				{
					continue;
				}
				else if (this._front <= this._back && x < this._front)
				{
					continue;
				}
				else if (this._front <= this._back && x > this._back)
				{
					break;
				}

				// For the time being we have to handle classes and interfaces as a
				// special case when comparing because Object.opEquals is not @nogc.
				static if (is(T == class) || is(T == interface))
				{
					if (*x is item)
					{
						return true;
					}
				}
				else
				{
					if (*x == item)
					{
						return true;
					}
				}
			}
		}

		return false;
	}

	/**
	 * Clears the queue.
	 *
	 * This method reallocates the memory used by the queue to the minimum size
	 * if more is currently allocated.
	 *
	 * Throws:
	 *     $(PARAM_TABLE
	 *         $(PARAM_ROW OutOfMemoryError, If memory reallocation fails.)
	 *     )
	 */
	public void clear()
	{
		if (this._size > this._minSize)
		{
			GC.removeRange(this._data);

			this._size = this._minSize;
			this._data = cast(T*) realloc(this._data, this._size);

			if (this._data is null)
			{
				onOutOfMemoryError();
			}

			static if (hasIndirections!(T))
			{
				GC.addRange(this._data, this._size, typeid(T));
			}
		}

		memset(this._data, 0, this._size);

		this._front = this._data;
		this._back  = this._data + (this.capacity - 1);
		this._count = 0;
	}

	/**
	 * Return a forward range to allow this queue to be used with various
	 * other algorithms.
	 *
	 * Returns:
	 *     A forward range representing this queue.
	 *
	 * Example:
	 * ---
	 * import std.algorithm;
	 * import std.string;
	 *
	 * auto queue = Queue!(string)(16);
	 *
	 * queue.enqueue("Foo");
	 * queue.enqueue("Bar");
	 * queue.enqueue("Baz");
	 *
	 * assert(queue.byValue.canFind("Baz"));
	 * assert(queue.byValue.map!(toLower).array == ["foo", "bar", "baz"]);
	 * ---
	 */
	public auto byValue() pure
	{
		static struct Result
		{
			private T* _data;
			private T* _front;
			private size_t _size;
			private size_t _count;

			public @property ref T front()
			{
				return *this._front;
			}

			public @property bool empty()
			{
				return this._count <= 0;
			}

			public void popFront()
			{
				this._front++;
				this._count--;

				if (this._front == (this._data + (this._size / T.sizeof)))
				{
					this._front = this._data;
				}
			}

			public @property auto save()
			{
				return this;
			}

			public @property size_t length()
			{
				return this._count;
			}
		}

		static assert(isForwardRange!(Result));
		static assert(hasLength!(Result));

		return Result(this._data, this._front, this._size, this._count);
	}

	/**
	 * Enable forward iteration in foreach loops.
	 *
	 * Params:
	 *     dg = A delegate that replaces the foreach loop.
	 *
	 * Returns:
	 *     A return value to determine if the loop should continue.
	 *
	 * See_Also:
	 *     $(LINK http://ddili.org/ders/d.en/foreach_opapply.html)
	 *
	 * Example:
	 * ---
	 * import std.stdio;
	 *
	 * auto queue = Queue!(string)(16);
	 *
	 * queue.enqueue("Foo");
	 * queue.enqueue("Bar");
	 * queue.enqueue("Baz");
	 *
	 * foreach (value; queue)
	 * {
	 * 	writefln("%s", value);
	 * }
	 * ---
	 */
	final public int opApply(scope int delegate(ref T) nothrow @nogc dg)
	{
		int result   = 0;
		T* front     = this._front;
		size_t count = this._count;

		while (count)
		{
			result = dg(*front);

			if (result)
			{
				break;
			}

			front++;
			count--;

			if (front == (this._data + this.capacity))
			{
				front = this._data;
			}
		}

		return result;
	}

	/**
	 * Enable forward iteration in foreach loops using an index.
	 *
	 * Params:
	 *     dg = A delegate that replaces the foreach loop.
	 *
	 * Returns:
	 *     A return value to determine if the loop should continue.
	 *
	 * See_Also:
	 *     $(LINK http://ddili.org/ders/d.en/foreach_opapply.html)
	 *
	 * Example:
	 * ---
	 * import std.stdio;
	 *
	 * auto queue = Queue!(string)(16);
	 *
	 * queue.enqueue("Foo");
	 * queue.enqueue("Bar");
	 * queue.enqueue("Baz");
	 *
	 * foreach (index, value; queue)
	 * {
	 * 	writefln("%s: %s", index, value);
	 * }
	 * ---
	 */
	final public int opApply(scope int delegate(ref size_t, ref T) nothrow @nogc dg)
	{
		int result   = 0;
		T* front     = this._front;
		size_t count = this._count;
		size_t index = 0;

		while (count)
		{
			result = dg(index, *front);

			if (result)
			{
				break;
			}

			front++;
			count--;
			index++;

			if (front == (this._data + this.capacity))
			{
				front = this._data;
			}
		}

		return result;
	}
}

///
unittest
{
	import std.algorithm;
	import std.string;

	auto queue = Queue!(string)(8);

	queue.enqueue("Foo");
	queue.enqueue("Bar");
	queue.enqueue("Baz");

	assert(!queue.empty);
	assert(queue.count == 3);
	assert(queue.contains("Bar"));
	assert(queue.byValue.map!(toLower).array == ["foo", "bar", "baz"]);

	assert(queue.peek() == "Foo");
	assert(queue.dequeue() == "Foo");
	assert(queue.dequeue() == "Bar");

	queue.clear();

	assert(!queue.contains("Baz"));
	assert(queue.empty);
	assert(queue.count == 0);

}

// Test reference counting.

unittest
{
	auto foo(T)(T queue)
	{
		assert(*queue._refCount == 2);
	}

	auto bar(T)(ref T queue)
	{
		assert(*queue._refCount == 1);
	}

	auto baz(T)(T queue)
	{
		assert(*queue._refCount == 1);
		return queue;
	}

	auto qux()
	{
		return Queue!(string)(1);
	}

	auto queue = Queue!(string)(16);

	assert(*queue._refCount == 1);

	foo(queue);
	assert(*queue._refCount == 1);

	bar(queue);
	assert(*queue._refCount == 1);

	queue = baz(Queue!(string)(1));
	assert(*queue._refCount == 1);

	queue = qux();
	assert(*queue._refCount == 1);
}

// Test big datasets.

unittest
{
	import std.algorithm;

	auto queue = Queue!(int)(8_192);

	assert(queue.empty);
	assert(queue.count == 0);
	assert(queue.capacity == 8_192);

	int limit = 1_000_000;

	for (int x = 1; x <= limit ; x++)
	{
		queue.enqueue(x);
		assert(queue.peek() == 1);
		assert(queue.count == x);
	}

	assert(queue.peek() == 1);
	assert(queue.count == limit);
	assert(queue.contains(1));
	assert(queue.contains(limit));
	assert(queue.byValue.canFind(1));
	assert(queue.byValue.canFind(limit));
	assert(queue.byValue.length == limit);
	assert(!queue.empty);
	assert(queue.capacity == 1_048_576);

	for (int x = 1; x <= limit ; x++)
	{
		assert(queue.peek() == x);
		assert(queue.dequeue() == x);
		assert(queue.count == limit - x);
	}

	assert(queue.empty);
	assert(queue.capacity == 8_192);

	for (int x = 1; x <= limit ; x++)
	{
		queue.enqueue(x);
		assert(queue.peek() == 1);
		assert(queue.count == x);
	}

	queue.clear();

	assert(queue.empty);
	assert(queue.count == 0);
	assert(!queue.contains(1));
	assert(!queue.contains(limit));
	assert(!queue.byValue.canFind(1));
	assert(!queue.byValue.canFind(limit));
	assert(queue.byValue.length == 0);
	assert(queue.capacity == 8_192);
}

// Test the memory layout.

unittest
{
	auto queue = Queue!(byte)(1);

	queue.enqueue(1);
	assert(queue._data[0 .. queue._size] == [1]);

	queue.enqueue(2);
	assert(queue._data[0 .. queue._size] == [1, 2]);

	queue.enqueue(3);
	assert(queue._data[0 .. queue._size] == [1, 2, 3, 0]);

	queue.enqueue(4);
	assert(queue._data[0 .. queue._size] == [1, 2, 3, 4]);
	assert(queue.contains(4));

	assert(queue.dequeue() == 1);
	assert(queue._data[0 .. queue._size] == [0, 2, 3, 4]);
	assert(!queue.contains(1));

	queue.enqueue(5);
	assert(queue._data[0 .. queue._size] == [5, 2, 3, 4]);
	assert(queue.contains(4));
	assert(queue.contains(5));

	assert(queue.dequeue() == 2);
	assert(queue._data[0 .. queue._size] == [5, 0, 3, 4]);
	assert(!queue.contains(2));

	assert(queue.dequeue() == 3);
	assert(queue._data[0 .. queue._size] == [4, 5]);
	assert(!queue.contains(2));

	queue.enqueue(6);
	queue.enqueue(7);
	assert(queue.dequeue() == 4);
	queue.enqueue(8);
	assert(queue._data[0 .. queue._size] == [8, 5, 6, 7]);
	queue.enqueue(9);
	assert(queue._data[0 .. queue._size] == [5, 6, 7, 8, 9, 0, 0, 0]);
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

	auto queue = Queue!(Foo)(1);
	auto foo   = new Foo(1);

	queue.enqueue(foo);
	queue.enqueue(new Foo(2));
	queue.enqueue(new Foo(3));

	assert(queue.contains(foo));
	assert(!queue.contains(new Foo(1)));
	assert(queue.dequeue()._foo == 1);

	queue.clear();
	assert(queue.empty);
}

// Test storing interfaces.

unittest
{
	interface Foo
	{
		public void foo();
	}

	auto foo = Queue!(Foo)(16);
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

	auto queue = Queue!(Foo)(16);
	auto foo   = Foo(1);

	queue.enqueue(foo);

	assert(queue.contains(foo));
	assert(!queue.contains(Foo(2)));
	assert(queue.dequeue()._foo == 1);
}

// Test the range interface.

unittest
{
	import std.algorithm;
	import std.string;

	auto queue = Queue!(string)(16);

	queue.enqueue("Foo");
	queue.enqueue("Bar");
	queue.enqueue("Baz");

	assert(queue.byValue.canFind("Baz"));
	assert(queue.byValue.map!(toLower).array == ["foo", "bar", "baz"]);
	assert(queue.byValue.save.array == ["Foo", "Bar", "Baz"]);

	auto bytes = Queue!(byte)(1);
	bytes.enqueue(1);
	bytes.enqueue(2);
	bytes.enqueue(3);
	bytes.enqueue(4);
	bytes.dequeue();
	bytes.enqueue(5);

	assert(bytes._data[0 .. bytes._size] == [5, 2, 3, 4]);
	assert(bytes.byValue.save.array == [2, 3, 4, 5]);
}

// Test iteration.

unittest
{
	auto queue  = Queue!(byte)(1);
	byte[] data = [1, 2, 3, 4];

	int counter;

	queue.enqueue(1);
	queue.enqueue(2);
	queue.enqueue(3);
	queue.enqueue(4);
	queue.dequeue();
	queue.enqueue(5);

	assert(queue._data[0 .. queue._size] == [5, 2, 3, 4]);

	data = [2, 3, 4, 5];

	counter = 0;
	foreach (value; queue)
	{
		assert(value == data[counter++]);
	}

	counter = 0;
	foreach (index, value; queue)
	{
		assert(index == counter);
		assert(value == data[counter++]);
	}
}

