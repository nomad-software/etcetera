/**
 * Collection module.
 *
 * License:
 *     MIT. See LICENSE for full details.
 */
module etcetera.collection.stack;

/**
 * Imports.
 */
import core.exception;
import core.memory;
import core.stdc.stdlib : malloc, calloc, realloc, free;
import core.stdc.string : memset;
import std.range;
import std.traits;

/**
 * A generic last-in-first-out (LIFO) stack implementation.
 *
 * Params:
 *     T = The type stored in the stack.
 */
struct Stack(T) if (is(T == Unqual!T))
{
	@nogc:
	nothrow:

	/**
	 * The reference count.
	 */
	private int* _refCount;

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
	private size_t _minSize;

	/**
	 * The current size in bytes of the stack.
	 */
	private size_t _size;

	/**
	 * The number of items currently held in the stack.
	 */
	private size_t _count;

	/*
	 * Disable the default constructor.
	 */
	@disable this();

	/**
	 * Construct a new stack.
	 *
	 * When created, this collection is allocated enough memory for a minimum
	 * amount of items. If the collection becomes full, the allocation will
	 * double, ad infinitum. If items only occupy half of the collection, the
	 * allocation will be halfed. The collection will never shrink below the
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
	public this(size_t minCapacity)
	{
		assert(minCapacity >= 1, "Stack must allow for at least one item.");

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

		this._pointer = this._data - 1;
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
	 * Get the number of items stored in the stack.
	 *
	 * Returns:
	 *     The number of items stored in the stack.
	 */
	public @property size_t count() const pure
	{
		return this._count;
	}

	/**
	 * Test if the stack is empty or not.
	 *
	 * Returns:
	 *     true if the stack is empty, false if not.
	 */
	public @property bool empty() const pure
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
	private @property size_t capacity() const pure
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
	public void push(T item)
	{
		this._pointer++;

		if (this._count == this.capacity)
		{
			GC.removeRange(this._data);

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
	public T peek() pure
	{
		assert(this._count, "Stack empty, peeking failed.");

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
	public T pop()
	{
		assert(this._count, "Stack empty, popping failed.");

		this._count--;
		auto popped = *this._pointer;

		if ((this._count <= (this.capacity / 2)) && ((this._size / 2) >= this._minSize))
		{
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
	public bool contains(T item) pure
	{
		if (!this.empty)
		{
			for (T* x = this._data; x < this._data + this._count ; x++)
			{
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

		this._pointer = this._data - 1;
		this._count   = 0;
	}

	/**
	 * Return a forward range to allow this stack to be used with various
	 * other algorithms.
	 *
	 * Returns:
	 *     A forward range representing this stack.
	 *
	 * Example:
	 * ---
	 * import std.algorithm;
	 * import std.string;
	 *
	 * auto stack = Stack!(string)(16);
	 *
	 * stack.push("Foo");
	 * stack.push("Bar");
	 * stack.push("Baz");
	 *
	 * assert(stack.byValue.canFind("Baz"));
	 * assert(stack.byValue.map!(toLower).array == ["baz", "bar", "foo"]);
	 * ---
	 */
	public auto byValue() pure
	{
		static struct Result
		{
			private T* _data;
			private T* _pointer;
			private size_t _count;

			public @property ref T front()
			{
				return *this._pointer;
			}

			public @property bool empty()
			{
				return this._pointer < this._data;
			}

			public void popFront()
			{
				this._pointer--;
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

		return Result(this._data, this._pointer, this._count);
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
	 * auto stack = Stack!(string)(4);
	 *
	 * stack.push("Foo");
	 * stack.push("Bar");
	 * stack.push("Baz");
	 *
	 * foreach (value; stack)
	 * {
	 * 	writefln("%s", value);
	 * }
	 * ---
	 */
	final public int opApply(scope int delegate(ref T) nothrow @nogc dg)
	{
		int result;

		for (T* pointer = this._pointer; pointer >= this._data; pointer--)
		{
			result = dg(*pointer);

			if (result)
			{
				break;
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
	 * auto stack = Stack!(string)(4);
	 *
	 * stack.push("Foo");
	 * stack.push("Bar");
	 * stack.push("Baz");
	 *
	 * foreach (index, value; stack)
	 * {
	 * 	writefln("%s: %s", index, value);
	 * }
	 * ---
	 */
	final public int opApply(scope int delegate(ref size_t, ref T) nothrow @nogc dg)
	{
		int result;
		size_t index;

		for (T* pointer = this._pointer; pointer >= this._data; index++, pointer--)
		{
			result = dg(index, *pointer);

			if (result)
			{
				break;
			}
		}

		return result;
	}
}

///
unittest
{
	import std.algorithm;
	import std.range;
	import std.string;

	auto stack = Stack!(string)(8);

	stack.push("Foo");
	stack.push("Bar");
	stack.push("Baz");

	assert(!stack.empty);
	assert(stack.count == 3);
	assert(stack.contains("Bar"));
	assert(stack.byValue.map!(toLower).array == ["baz", "bar", "foo"]);
	assert(stack.peek() == "Baz");
	assert(stack.pop() == "Baz");
	assert(stack.pop() == "Bar");

	stack.clear();

	assert(!stack.contains("Foo"));
	assert(stack.empty);
	assert(stack.count == 0);
}

// Test reference counting.

unittest
{
	auto foo(T)(T stack)
	{
		assert(*stack._refCount == 2);
	}

	auto bar(T)(ref T stack)
	{
		assert(*stack._refCount == 1);
	}

	auto baz(T)(T stack)
	{
		assert(*stack._refCount == 1);
		return stack;
	}

	auto qux()
	{
		return Stack!(string)(1);
	}

	auto stack = Stack!(string)(16);

	assert(*stack._refCount == 1);

	foo(stack);
	assert(*stack._refCount == 1);

	bar(stack);
	assert(*stack._refCount == 1);

	stack = baz(Stack!(string)(1));
	assert(*stack._refCount == 1);

	stack = qux();
	assert(*stack._refCount == 1);
}

// Test big datasets.

unittest
{
	import std.algorithm;

	auto stack = Stack!(int)(8_192);

	assert(stack.empty);
	assert(stack.count == 0);
	assert(stack.capacity == 8_192);

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
	assert(stack.byValue.canFind(1));
	assert(stack.byValue.canFind(limit));
	assert(stack.byValue.length == limit);
	assert(!stack.empty);
	assert(stack.capacity == 1_048_576);

	for (int x = limit; x >= 1 ; x--)
	{
		assert(stack.count == x);
		assert(stack.peek() == x);
		assert(stack.pop() == x);
	}

	assert(stack.empty);
	assert(stack.capacity == 8_192);

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
	assert(!stack.byValue.canFind(1));
	assert(!stack.byValue.canFind(limit));
	assert(stack.byValue.length == 0);
	assert(stack.capacity == 8_192);
}

// Test the memory layout.

unittest
{
	auto stack = Stack!(byte)(4);

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

	auto stack = Stack!(Foo)(1);
	auto foo   = new Foo(1);

	stack.push(foo);
	stack.push(new Foo(2));
	stack.push(new Foo(3));

	assert(stack.contains(foo));
	assert(!stack.contains(new Foo(1)));
	assert(stack.pop()._foo == 3);

	stack.clear();
	assert(stack.empty);
}

// Test storing interfaces.

unittest
{
	interface Foo
	{
		public void foo();
	}

	auto foo = Stack!(Foo)(16);
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

	auto stack = Stack!(Foo)(16);
	auto foo   = Foo(1);

	stack.push(foo);

	assert(stack.contains(foo));
	assert(!stack.contains(Foo(2)));
	assert(stack.pop()._foo == 1);
}

// Test the range interface.

unittest
{
	import std.algorithm;
	import std.range;
	import std.string;

	auto stack = Stack!(string)(16);

	stack.push("Foo");
	stack.push("Bar");
	stack.push("Baz");

	assert(stack.byValue.canFind("Baz"));
	assert(stack.byValue.map!(toLower).array == ["baz", "bar", "foo"]);
	assert(stack.byValue.save.array == ["Baz", "Bar", "Foo"]);
}

// Test iteration.

unittest
{
	import std.range;

	auto stack = Stack!(string)(16);

	stack.push("Foo");
	stack.push("Bar");
	stack.push("Baz");
	stack.push("Qux");

	size_t counter;
	auto data  = ["Qux", "Baz", "Bar", "Foo"];

	foreach (value; stack.byValue)
	{
		assert(value == data[counter++]);
	}

	counter = 0;
	foreach (index, value; stack.byValue.enumerate)
	{
		assert(index == counter);
		assert(value == data[counter++]);
	}

	counter = 0;
	foreach (value; stack.byValue.save)
	{
		assert(value == data[counter++]);
	}

	counter = 0;
	foreach (value; stack)
	{
		assert(value == data[counter++]);
	}

	counter = 0;
	foreach (index, value; stack)
	{
		assert(index == counter);
		assert(value == data[counter++]);
	}

	assert(stack.pop() == "Qux");
	assert(stack.pop() == "Baz");
	assert(stack.pop() == "Bar");
	assert(stack.pop() == "Foo");
}

