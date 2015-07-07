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
import core.memory;
import core.stdc.string : memcpy, memmove, memset;
import std.traits;

/**
 * A generic first-in-first-out (FIFO) queue implementation.
 *
 * Params:
 *     T = The type stored in the queue.
 */
class Queue(T)
{
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
	private immutable size_t _minSize;

	/**
	 * The current size in bytes of the queue.
	 */
	private size_t _size;

	/**
	 * The number of items currently held in the queue.
	 */
	private size_t _count = 0;

	/**
	 * Construct a new queue.
	 *
	 * By default the queue is allocated enough memory for 10,000 items. If 
	 * more items are added, the queue can grow by doubling its allocation, ad 
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
	final public this(size_t minCapacity = 10_000) nothrow
	{
		assert(minCapacity >= 1, "Queue must allow for at least one item.");

		this._minSize = minCapacity * T.sizeof;
		this._size    = this._minSize;

		static if (hasIndirections!(T))
		{
			this._data = cast(T*)GC.calloc(this._size, GC.BlkAttr.NO_MOVE, typeid(T));
		}
		else
		{
			this._data = cast(T*)GC.calloc(this._size, GC.BlkAttr.NO_MOVE | GC.BlkAttr.NO_SCAN, typeid(T));
		}

		this._front = this._data;
		this._back  = this._data - 1;
	}

	/**
	 * Get the number of items stored in the queue.
	 *
	 * Returns:
	 *     The number of items stored in the queue.
	 */
	final public @property size_t count() const nothrow pure
	{
		return this._count;
	}

	/**
	 * Test if the queue is empty or not.
	 *
	 * Returns:
	 *     true if the queue is empty, false if not.
	 */
	final public @property bool empty() const nothrow pure
	{
		return (this._count == 0);
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
	final public void enqueue(T item) nothrow
	{
		if (this._count == this.capacity)
		{
			this._frontOffset = this._front - this._data;

			this._size *= 2;
			this._data  = cast(T*)GC.realloc(this._data, this._size, GC.BlkAttr.NONE, typeid(T));

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
	final public T peek() nothrow pure
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
	final public T dequeue() nothrow
	{
		assert(this._count, "Queue empty, dequeuing failed.");

		static T dequeued;

		this._count--;
		dequeued = *(this._front);

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

			this._size /= 2;
			this._data  = cast(T*)GC.realloc(this._data, this._size, GC.BlkAttr.NONE, typeid(T));

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
	final public bool contains(T item)
	{
		if (!this.empty)
		{
			if (this._front > this._back)
			{
				for (T* x = this._data; x <= this._back; x++)
				{
					if (*x == item)
					{
						return true;
					}
				}
				for (T* x = this._front; x < this._data + this.capacity; x++)
				{
					if (*x == item)
					{
						return true;
					}
				}
			}
			else
			{
				for (T* x = this._front; x <= this._back; x++)
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
	final public void clear() nothrow
	{
		if (this._size > this._minSize)
		{
			this._size = this._minSize;
			this._data = cast(T*)GC.realloc(this._data, this._size, GC.BlkAttr.NONE, typeid(T));
		}

		memset(this._data, 0, this._size);

		this._front = this._data;
		this._back  = this._data + (this.capacity - 1);
		this._count = 0;
	}

	/**
	 * The current item capacity of the queue. This will change if the queue 
	 * reallocates more memory.
	 *
	 * Returns:
	 *     The capacity of how many items the queue can hold.
	 */
	final private @property size_t capacity() const nothrow pure
	{
		return this._size / T.sizeof;
	}
}

///
unittest
{
	auto queue = new Queue!(string);

	queue.enqueue("Foo");
	queue.enqueue("Bar");
	queue.enqueue("Baz");

	assert(!queue.empty);
	assert(queue.count == 3);
	assert(queue.contains("Bar"));

	assert(queue.peek() == "Foo");
	assert(queue.dequeue() == "Foo");
	assert(queue.dequeue() == "Bar");

	queue.clear();

	assert(!queue.contains("Baz"));
	assert(queue.empty);
	assert(queue.count == 0);

}

unittest
{
	auto queue = new Queue!(int);

	assert(queue.empty);
	assert(queue.count == 0);
	assert(queue.capacity == 10_000);

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
	assert(!queue.empty);
	assert(queue.capacity == 1_280_000);

	for (int x = 1; x <= limit ; x++)
	{
		assert(queue.peek() == x);
		assert(queue.dequeue() == x);
		assert(queue.count == limit - x);
	}

	assert(queue.empty);
	assert(queue.capacity == 10_000);

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
	assert(queue.capacity == 10_000);
}

unittest
{
	auto queue = new Queue!(byte)(1);

	queue.enqueue(1);
	assert(queue._data[0 .. 1] == [1]);
	assert(queue.contains(1));

	queue.enqueue(2);
	assert(queue._data[0 .. 2] == [1, 2]);
	assert(queue.contains(2));

	queue.enqueue(3);
	assert(queue._data[0 .. 3] == [1, 2, 3]);
	assert(queue.contains(3));

	queue.enqueue(4);
	assert(queue._data[0 .. 4] == [1, 2, 3, 4]);
	assert(queue.contains(4));

	assert(queue.dequeue() == 1);
	assert(queue._data[0 .. 4] == [0, 2, 3, 4]);
	assert(!queue.contains(1));

	assert(queue.dequeue() == 2);
	assert(!queue.contains(2));
	assert(queue._data[0 .. 2] == [3, 4]);

	assert(queue.dequeue() == 3);
	assert(!queue.contains(3));
	assert(queue._data[0 .. 1] == [4]);

	assert(queue.dequeue() == 4);
	assert(!queue.contains(4));
	assert(queue.empty);
}

unittest
{
	auto queue = new Queue!(short)(1);

	queue.enqueue(1);
	assert(queue.contains(1));
	assert(queue._data[0 .. 1] == [1]);

	queue.enqueue(2);
	assert(queue.contains(2));
	assert(queue._data[0 .. 2] == [1, 2]);

	queue.enqueue(3);
	assert(queue.contains(3));
	assert(queue._data[0 .. 3] == [1, 2, 3]);

	queue.enqueue(4);
	assert(queue.contains(4));
	assert(queue._data[0 .. 4] == [1, 2, 3, 4]);

	assert(queue.dequeue() == 1);
	assert(!queue.contains(1));
	assert(queue._data[0 .. 4] == [0, 2, 3, 4]);

	queue.enqueue(5);
	// Make sure the new back and front can still be searched.
	assert(queue.contains(4));
	assert(queue.contains(5));
	assert(queue._data[0 .. 4] == [5, 2, 3, 4]);

	assert(queue.dequeue() == 2);
	assert(!queue.contains(2));
	assert(queue._data[0 .. 4] == [5, 0, 3, 4]);

	assert(queue.dequeue() == 3);
	assert(!queue.contains(3));
	assert(queue._data[0 .. 2] == [4, 5]);

	assert(queue.dequeue() == 4);
	assert(!queue.contains(4));
	assert(queue._data[0 .. 1] == [5]);

	assert(queue.dequeue() == 5);
	assert(!queue.contains(5));
	assert(queue.empty);
}

unittest
{
	auto queue = new Queue!(int)(1);

	queue.enqueue(1);
	assert(queue.contains(1));
	assert(queue._data[0 .. 1] == [1]);

	queue.enqueue(2);
	assert(queue.contains(2));
	assert(queue._data[0 .. 2] == [1, 2]);

	queue.enqueue(3);
	assert(queue.contains(3));
	assert(queue._data[0 .. 3] == [1, 2, 3]);

	queue.enqueue(4);
	assert(queue.contains(4));
	assert(queue._data[0 .. 4] == [1, 2, 3, 4]);

	assert(queue.dequeue() == 1);
	assert(!queue.contains(1));
	assert(queue._data[0 .. 4] == [0, 2, 3, 4]);

	queue.enqueue(5);
	assert(queue.contains(5));
	assert(queue._data[0 .. 4] == [5, 2, 3, 4]);

	assert(queue.dequeue() == 2);
	assert(!queue.contains(2));
	assert(queue._data[0 .. 4] == [5, 0, 3, 4]);

	queue.enqueue(6);
	assert(queue.contains(6));
	assert(queue._data[0 .. 4] == [5, 6, 3, 4]);

	assert(queue.dequeue() == 3);
	assert(!queue.contains(3));
	assert(queue._data[0 .. 4] == [5, 6, 0, 4]);

	assert(queue.dequeue() == 4);
	assert(!queue.contains(4));
	assert(queue._data[0 .. 2] == [5, 6]);

	assert(queue.dequeue() == 5);
	assert(!queue.contains(5));
	assert(queue._data[0 .. 1] == [6]);

	assert(queue.dequeue() == 6);
	assert(!queue.contains(6));
	assert(queue.empty);
}

unittest
{
	auto queue = new Queue!(long)(1);

	queue.enqueue(1);
	assert(queue.contains(1));
	assert(queue._data[0 .. 1] == [1]);

	queue.enqueue(2);
	assert(queue.contains(2));
	assert(queue._data[0 .. 2] == [1, 2]);

	queue.enqueue(3);
	assert(queue.contains(3));
	assert(queue._data[0 .. 3] == [1, 2, 3]);

	queue.enqueue(4);
	assert(queue.contains(3));
	assert(queue._data[0 .. 4] == [1, 2, 3, 4]);

	assert(queue.dequeue() == 1);
	assert(!queue.contains(1));
	assert(queue._data[0 .. 4] == [0, 2, 3, 4]);

	queue.enqueue(5);
	assert(queue.contains(5));
	assert(queue._data[0 .. 4] == [5, 2, 3, 4]);

	assert(queue.dequeue() == 2);
	assert(!queue.contains(2));
	assert(queue._data[0 .. 4] == [5, 0, 3, 4]);

	queue.enqueue(6);
	assert(queue.contains(6));
	assert(queue._data[0 .. 4] == [5, 6, 3, 4]);

	assert(queue.dequeue() == 3);
	assert(!queue.contains(3));
	assert(queue._data[0 .. 4] == [5, 6, 0, 4]);

	queue.enqueue(7);
	assert(queue.contains(7));
	assert(queue._data[0 .. 4] == [5, 6, 7, 4]);

	assert(queue.dequeue() == 4);
	assert(!queue.contains(4));
	assert(queue._data[0 .. 4] == [5, 6, 7, 0]);

	assert(queue.dequeue() == 5);
	assert(!queue.contains(5));
	assert(queue._data[0 .. 2] == [6, 7]);

	assert(queue.dequeue() == 6);
	assert(!queue.contains(6));
	assert(queue._data[0 .. 1] == [7]);

	assert(queue.dequeue() == 7);
	assert(!queue.contains(7));
	assert(queue.empty);
}

unittest
{
	auto queue = new Queue!(long)(1);

	queue.enqueue(1);
	assert(queue.contains(1));
	assert(queue._data[0 .. 1] == [1]);

	queue.enqueue(2);
	assert(queue.contains(2));
	assert(queue._data[0 .. 2] == [1, 2]);

	queue.enqueue(3);
	assert(queue.contains(3));
	assert(queue._data[0 .. 3] == [1, 2, 3]);

	queue.enqueue(4);
	assert(queue.contains(3));
	assert(queue._data[0 .. 4] == [1, 2, 3, 4]);

	assert(queue.dequeue() == 1);
	assert(!queue.contains(1));
	assert(queue._data[0 .. 4] == [0, 2, 3, 4]);

	queue.enqueue(5);
	assert(queue.contains(5));
	assert(queue._data[0 .. 4] == [5, 2, 3, 4]);

	queue.enqueue(6);
	assert(queue.contains(6));
	assert(queue._data[0 .. 5] == [2, 3, 4, 5, 6]);

	queue.enqueue(7);
	assert(queue.contains(7));
	assert(queue._data[0 .. 6] == [2, 3, 4, 5, 6, 7]);

	queue.enqueue(8);
	assert(queue.contains(8));
	assert(queue._data[0 .. 7] == [2, 3, 4, 5, 6, 7, 8]);
}

unittest
{
	auto queue = new Queue!(byte)(4);

	assert(queue.capacity == 4);
	assert(queue._data[0 .. 4] == [0, 0, 0, 0]);

	queue.enqueue(1);
	queue.enqueue(2);
	queue.enqueue(3);
	queue.enqueue(4);
	assert(queue._data[0 .. 4] == [1, 2, 3, 4]);

	queue.enqueue(5);
	assert(queue.capacity == 8);
	assert(queue._data[0 .. 8] == [1, 2, 3, 4, 5, 0, 0, 0]);

	assert(queue.dequeue() == 1);
	assert(queue.capacity == 4);
	assert(queue._data[0 .. 4] == [2, 3, 4, 5]);

	assert(queue.dequeue() == 2);
	assert(queue.dequeue() == 3);
	assert(queue.capacity == 4);
	assert(queue._data[0 .. 4] == [0, 0, 4, 5]);

	queue.clear();
	assert(queue._data[0 .. 4] == [0, 0, 0, 0]);
}

unittest
{
	class Foo
	{
		private int _foo;

		public this(int foo) nothrow
		{
			this._foo = foo;
		}
	}

	auto queue = new Queue!(Foo)(4);

	queue.enqueue(new Foo(1));
	queue.enqueue(new Foo(2));
	queue.enqueue(new Foo(3));

	assert(queue.dequeue()._foo == 1);
	assert(queue.dequeue()._foo == 2);
	assert(queue.dequeue()._foo == 3);
}

