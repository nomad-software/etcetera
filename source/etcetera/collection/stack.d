/**
 * Collections module.
 *
 * License:
 *     MIT. See LICENSE for full details.
 */
module etcetera.collection.stack;

/**
 * Imports.
 */
import core.memory;
import core.stdc.string : memset;
import std.traits;

/**
 * A generic last-in-first-out (LIFO) stack implementation.
 */
class Stack(T)
{
	/**
	 * A pointer to the stack data.
	 */
	private T* _data;

	/**
	 * A pointer to the latest item pushed on the stack.
	 */
	private T* _pointer;

	/**
	 * The minimum size in bytes that the stack will allocate.
	 */
	private immutable size_t _minSize;

	/**
	 * The current size in bytes of the stack.
	 */
	private size_t _size;

	/**
	 * The number of items currently held in the stack.
	 */
	private size_t _count = 0;

	/**
	 * Construct a new stack.
	 *
	 * By default the stack is allocated enough memory for 10,000 items. If 
	 * more items are added, the stack can grow by doubling its allocation, ad 
	 * infinitum. If the items within reduce to only use half of the current 
	 * allocation the stack will half it. The stack will never shrink below the 
	 * minimum capacity amount.
	 *
	 * Params:
	 *     minCapacity = The minimum number of items to allocate space for.
	 *                   The stack will never shrink below this allocation.
	 *
	 * Throws:
	 *     $(PARAM_TABLE
	 *         $(PARAM_ROW AssertError, If the minimum allocated size is not big enough for at least one item.)
	 *         $(PARAM_ROW OutOfMemoryError, If memory allocation fails.)
	 *     )
	 */
	final public this(size_t minCapacity = 10_000) nothrow
	{
		assert(minCapacity >= 1, "Stack must allow for at least one item.");

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

		this._pointer = this._data - 1;
	}

	/**
	 * Get the number of items stored in the stack.
	 *
	 * Returns:
	 *     The number of items stored in the stack.
	 */
	final public @property size_t count() const nothrow pure
	{
		return this._count;
	}

	/**
	 * Test if the stack is empty or not.
	 *
	 * Returns:
	 *     true if the stack is empty, false if not.
	 */
	final public @property bool empty() const nothrow pure
	{
		return (this._count == 0);
	}

	/**
	 * The current item capacity of the stack. This will change if the stack 
	 * reallocates more memory.
	 *
	 * Returns:
	 *     The capacity of how many items the stack can hold.
	 */
	final private @property size_t capacity() const nothrow pure
	{
		return this._size / T.sizeof;
	}

	/**
	 * Push an item onto the stack.
	 *
	 * This method reallocates and doubles the memory used by the stack if no 
	 * more items can be stored in available memory.
	 *
	 * Params:
	 *     item = The item to push onto the stack.
	 *
	 * Throws:
	 *     $(PARAM_TABLE
	 *         $(PARAM_ROW OutOfMemoryError, If memory reallocation fails.)
	 *     )
	 */
	final public void push(T item) nothrow
	{
		this._pointer++;

		if (this.count == this.capacity)
		{
			this._size   *= 2;
			this._data    = cast(T*)GC.realloc(this._data, this._size, GC.BlkAttr.NONE, typeid(T));
			this._pointer = this._data + this._count;

			memset(this._pointer, 0, this._size / 2);
		}

		this._count++;

		*this._pointer = item;
	}

	/**
	 * Return the last item pushed onto the stack but don't remove it.
	 *
	 * Returns:
	 *     The last item pushed onto the stack.
	 *
	 * Throws:
	 *     $(PARAM_TABLE
	 *         $(PARAM_ROW AssertError, If the stack is empty.)
	 *     )
	 */
	final public T peek() nothrow pure
	{
		assert(this.count > 0, "Stack empty, peeking failed.");

		return *this._pointer;
	}

	/**
	 * Remove and return the last item pushed onto the stack.
	 *
	 * This method reallocates the memory used by the stack, halfing it if 
	 * half will adequately hold all the items.
	 *
	 * Returns:
	 *     The last item pushed onto the stack.
	 *
	 * Throws:
	 *     $(PARAM_TABLE
	 *         $(PARAM_ROW AssertError, If the stack is empty.)
	 *         $(PARAM_ROW OutOfMemoryError, If memory reallocation fails.)
	 *     )
	 */
	final public T pop() nothrow
	{
		assert(this.count > 0, "Stack empty, popping failed.");

		static T popped;

		this._count--;
		popped = *this._pointer;

		if ((this._count <= (this.capacity / 2)) && ((this._size / 2) >= this._minSize))
		{
			this._size   /= 2;
			this._data    = cast(T*)GC.realloc(this._data, this._size, GC.BlkAttr.NONE, typeid(T));
			this._pointer = this._data + (this._count - 1);
		}
		else
		{
			memset(this._pointer, 0, T.sizeof);
			this._pointer--;
		}

		return popped;
	}

	/**
	 * Check if a value is contained in the stack.
	 *
	 * This is a simple linear search and can take quite some time with large 
	 * stacks.
	 *
	 * Params:
	 *     item = The item to find in the stack.
	 *
	 * Returns:
	 *     true if the item is found on the stack, false if not.
	 */
	final public bool contains(T item)
	{
		for (T* x = this._data; x < this._data + this._count ; x++)
		{
			if (*x == item)
			{
				return true;
			}
		}
		return false;
	}

	/**
	 * Clears the stack.
	 *
	 * This method reallocates the memory used by the stack to the minimum size 
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

		this._pointer = this._data - 1;
		this._count   = 0;
	}
}

///
unittest
{
	auto stack = new Stack!(string);

	stack.push("Foo");
	stack.push("Bar");
	stack.push("Baz");

	assert(!stack.empty);
	assert(stack.count == 3);
	assert(stack.contains("Bar"));

	assert(stack.peek() == "Baz");
	assert(stack.pop() == "Baz");
	assert(stack.pop() == "Bar");

	stack.clear();

	assert(!stack.contains("Foo"));
	assert(stack.empty);
	assert(stack.count == 0);
}

unittest
{
	auto stack = new Stack!(int);

	assert(stack.empty);
	assert(stack.count == 0);
	assert(stack.capacity == 10_000);

	int limit = 1_000_000;

	for (int x = 1; x <= limit ; x++)
	{
		stack.push(x);
		assert(stack.peek() == x);
		assert(stack.count == x);
	}

	assert(stack.peek() == limit);
	assert(stack.count == limit);
	assert(stack.contains(1));
	assert(stack.contains(limit));
	assert(!stack.empty);
	assert(stack.capacity == 1_280_000);

	for (int x = limit; x >= 1 ; x--)
	{
		assert(stack.count == x);
		assert(stack.peek() == x);
		assert(stack.pop() == x);
	}

	assert(stack.empty);
	assert(stack.capacity == 10_000);

	for (int x = 1; x <= limit ; x++)
	{
		stack.push(x);
		assert(stack.peek() == x);
		assert(stack.count == x);
	}

	stack.clear();

	assert(stack.empty);
	assert(stack.count == 0);
	assert(!stack.contains(1));
	assert(!stack.contains(limit));
	assert(stack.capacity == 10_000);
}

unittest
{
	auto stack = new Stack!(byte)(4);

	assert(stack.capacity == 4);
	assert(stack._data[0 .. 4] == [0, 0, 0, 0]);

	stack.push(1);
	stack.push(2);
	stack.push(3);
	stack.push(4);
	assert(stack._data[0 .. 4] == [1, 2, 3, 4]);

	stack.push(5);
	assert(stack.capacity == 8);
	assert(stack._data[0 .. 8] == [1, 2, 3, 4, 5, 0, 0, 0]);

	assert(stack.pop() == 5);
	assert(stack.capacity == 4);
	assert(stack._data[0 .. 4] == [1, 2, 3, 4]);

	assert(stack.pop() == 4);
	assert(stack.pop() == 3);
	assert(stack.capacity == 4);
	assert(stack._data[0 .. 4] == [1, 2, 0, 0]);

	stack.clear();
	assert(stack._data[0 .. 4] == [0, 0, 0, 0]);
}

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

	auto stack = new Stack!(Foo)(4);

	stack.push(new Foo(1));
	stack.push(new Foo(2));
	stack.push(new Foo(3));

	assert(stack.pop()._foo == 3);
	assert(stack.pop()._foo == 2);
	assert(stack.pop()._foo == 1);
}

