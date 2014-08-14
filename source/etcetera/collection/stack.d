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
import core.exception;
import core.stdc.stdlib : malloc, realloc, free;

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
	 * Return value for the pop method.
	 */
	private T _popped;

	/**
	 * The minimum size in bytes that the stack will allocate.
	 */
	private immutable size_t _minSize;

	/**
	 * The current size of the stack.
	 */
	private size_t _size;

	/**
	 * The number of items currently held in the stack.
	 */
	private size_t _count = 0;

	/**
	 * Construct a new stack.
	 *
	 * By default the stack is allocated 32k bytes. Once the stack grows above 
	 * that limit it is rellocated to use double, ad infinitum. If the stack 
	 * reduces to use only half of its allocation it is halfed. The stack will 
	 * never have below the minimum allocation amount.
	 *
	 * Params:
	 *     minSize = The minimum size of the stack. Set to 32kb by default.
	 *
	 * Throws:
	 *     $(PARAM_TABLE
	 *         $(PARAM_ROW AssertError, If the minimum allocated size is not big enough for at least one item.)
	 *         $(PARAM_ROW InvalidMemoryOperationError, If memory allocation fails.)
	 *     )
	 */
	final public this(size_t minSize = 32_000) nothrow
	{
		assert(minSize >= T.sizeof, "Stack must allocate for at least one item.");

		this._minSize = minSize;
		this._size    = this._minSize;
		this._data    = cast(T*)malloc(this._size);

		if (this._data is null)
		{
			throw new InvalidMemoryOperationError();
		}

		this._pointer = this._data - 1;
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
	 *         $(PARAM_ROW InvalidMemoryOperationError, If memory reallocation fails.)
	 *     )
	 */
	final public void push(T item) nothrow
	{
		this._pointer++;

		if (this.count == this.capacity)
		{
			this._size *= 2;
			this._data  = cast(T*)realloc(this._data, this._size);

			if (this._data is null)
			{
				throw new InvalidMemoryOperationError();
			}

			this._pointer = this._data + this._count;
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
	final public T peek() const nothrow pure
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
	 *         $(PARAM_ROW InvalidMemoryOperationError, If memory reallocation fails.)
	 *     )
	 */
	final public T pop() nothrow
	{
		assert(this.count > 0, "Stack empty, popping failed.");

		this._pointer--;
		this._count--;

		if ((this._count <= (this.capacity / 2)) && ((this._size / 2) >= this._minSize))
		{
			this._popped  = *(this._pointer + 1);
			this._size   /= 2;
			this._data    = cast(T*)realloc(this._data, this._size);

			if (this._data is null)
			{
				throw new InvalidMemoryOperationError();
			}

			this._pointer = this._data + (this._count - 1);
			return this._popped;
		}

		return *(this._pointer + 1);
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
	final public bool contains(T item) nothrow
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
	 *         $(PARAM_ROW InvalidMemoryOperationError, If memory reallocation fails.)
	 *     )
	 */
	final public void clear() nothrow
	{
		if (this._size > this._minSize)
		{
			this._size = this._minSize;
			this._data = cast(T*)realloc(this._data, this._size);

			if (this._data is null)
			{
				throw new InvalidMemoryOperationError();
			}
		}

		this._pointer = this._data - 1;
		this._count   = 0;
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
	 * Destructor.
	 */
	final private ~this() nothrow
	{
		free(this._data);
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
	assert(stack.capacity == 8000);

	int limit = 1_024_000;

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
	assert(stack.capacity == 1024000);

	for (int x = limit; x >= 1 ; x--)
	{
		assert(stack.count == x);
		assert(stack.peek() == x);
		assert(stack.pop() == x);
	}

	assert(stack.empty);
	assert(stack.capacity == 8000);

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
	assert(stack.capacity == 8000);
}
