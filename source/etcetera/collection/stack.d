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
 * A standard stack type implementation.
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
	private immutable size_t _minimumSize;

	/**
	 * The current size of the stack.
	 */
	private size_t _size;

	/**
	 * The number of items currently held in the stack.
	 */
	private size_t _count = 0;

	/*
	 * Constructor.
	 */
	public this()
	{
		this._minimumSize = 32_000;
		this._size = this._minimumSize;
		this._data = cast(T*)calloc(this.capacity, T.sizeof);
		this._pointer = this._data;
		this._pointer--;
	}

	/**
	 * Destructor.
	 */
	~this()
	{
		free(this._data);
	}

	/**
	 * Push an item onto the stack.
	 *
	 * Params:
	 *     item = The item to push onto the stack.
	 */
	public void push(T item)
	{
		this._pointer++;

		if (this.capacity < (this._count + 1))
		{
			this._size *= 2;
			this._data = cast(T*)realloc(this._data, this._size);
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
	public T peek()
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
	public T pop()
	{
		assert(this.count > 0, "Stack empty, popping failed.");

		this._pointer--;
		this._count--;

		if ((this._count <= (this.capacity / 2)) && ((this._size / 2) >= this._minimumSize))
		{
			this._popped = *(this._pointer + 1);
			this._size /= 2;
			this._data = cast(T*)realloc(this._data, this._size);
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
	public @property size_t count()
	{
		return this._count;
	}

	/**
	 * Test if the stack is empty or not.
	 *
	 * Returns:
	 *     true if the stack is empty, false if not.
	 */
	public @property bool empty()
	{
		return (this._count == 0);
	}

	/**
	 * The current item capacity of the stack. This will change if the stack 
	 * reallocates more memory.
	 */
	private @property size_t capacity()
	{
		return this._size / T.sizeof;
	}
}

///
unittest
{
	auto stack = new Stack!(int);
	int iterations = 1_000_000;

	assert(stack.empty);

	for (int x = 1; x <= iterations ; x++)
	{
		stack.push(x);
	}

	assert(stack.peek() == iterations);
	assert(stack.count == iterations);
	assert(!stack.empty);

	for (int x = iterations; x >= 1 ; x--)
	{
		assert(stack.pop() == x);
	}

	assert(stack.empty);
}
