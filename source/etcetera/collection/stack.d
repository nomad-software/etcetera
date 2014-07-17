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
import core.stdc.stdlib : calloc, realloc, free;

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
	 * reduces to use only half of its allocation the allocation is halfed. The 
	 * stack will never uses below the minimum allocation amount.
	 *
	 * Params:
	 *     minSize = The minimum size of the stack. Set to 32kb by default.
	 */
	final public this(size_t minSize = 32_000)
	{
		assert(minSize >= T.sizeof, "Stack must allocate for at least one item.");

		this._minSize = minSize;
		this._size    = this._minSize;
		this._data    = cast(T*)calloc(this.capacity, T.sizeof);
		this._pointer = this._data - 1;
	}

	/**
	 * Push an item onto the stack.
	 *
	 * Params:
	 *     item = The item to push onto the stack.
	 */
	final public void push(T item)
	{
		this._pointer++;

		if (this.count == this.capacity)
		{
			this._size   *= 2;
			this._data    = cast(T*)realloc(this._data, this._size);
			this._pointer = this._data + this._count;
		}

		this._count++;

		*this._pointer = item;
	}

	/**
	 * Return the latest item pushed onto the stack.
	 *
	 * Returns:
	 *     The last item pushed onto the stack.
	 *
	 * Throws:
	 *     AssertError if the stack is empty.
	 */
	final public T peek()
	{
		assert(this.count > 0, "Stack empty, peeking failed.");

		return *this._pointer;
	}

	/**
	 * Return the latest item pushed onto the stack and remove it from the stack.
	 *
	 * Returns:
	 *     The last item pushed onto the stack.
	 *
	 * Throws:
	 *     AssertError if the stack is empty.
	 */
	final public T pop()
	{
		assert(this.count > 0, "Stack empty, popping failed.");

		this._pointer--;
		this._count--;

		if ((this._count <= (this.capacity / 2)) && ((this._size / 2) >= this._minSize))
		{
			this._popped  = *(this._pointer + 1);
			this._size   /= 2;
			this._data    = cast(T*)realloc(this._data, this._size);
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
	final public @property size_t count()
	{
		return this._count;
	}

	/**
	 * Test if the stack is empty or not.
	 *
	 * Returns:
	 *     true if the stack is empty, false if not.
	 */
	final public @property bool empty()
	{
		return (this._count == 0);
	}

	/**
	 * Check if a value is contained in the stack.
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
	 * Clear the stack.
	 */
	final public void clear()
	{
		if (this._size > this._minSize)
		{
			this._size = this._minSize;
			this._data = cast(T*)realloc(this._data, this._size);
		}

		this._pointer = this._data - 1;
		this._count   = 0;
	}

	/**
	 * The current item capacity of the stack. This will change if the stack 
	 * reallocates more memory.
	 */
	final private @property size_t capacity()
	{
		return this._size / T.sizeof;
	}

	/**
	 * Destructor.
	 */
	final private ~this()
	{
		free(this._data);
	}

}

///
unittest
{
	auto stack = new Stack!(int);

	assert(stack.empty);
	assert(stack.count == 0);

	int limit = 1_000_000;

	for (int x = 1; x <= limit ; x++)
	{
		stack.push(x);
	}

	assert(stack.peek() == limit);
	assert(stack.count == limit);
	assert(stack.contains(1));
	assert(stack.contains(limit));
	assert(!stack.empty);

	for (int x = limit; x >= 1 ; x--)
	{
		assert(stack.pop() == x);
	}

	assert(stack.empty);

	for (int x = 1; x <= limit ; x++)
	{
		stack.push(x);
	}

	stack.clear();

	assert(stack.empty);
	assert(stack.count == 0);
	assert(!stack.contains(1));
	assert(!stack.contains(limit));
}
