/**
 * Collections module.
 *
 * License:
 *     MIT. See LICENSE for full details.
 */
module etcetera.collection.linkedlist;

/**
 * Imports.
 */
import core.exception;
import core.stdc.stdlib : malloc, realloc, free;
import std.range;

/**
 * A node in the linked list.
 */
private struct Node(T)
{
	/**
	 * The previous node.
	 */
	public Node!(T)* prev;

	/**
	 * The node data.
	 */
	public T data;

	/**
	 * The next node.
	 */
	public Node!(T)* next;
}

/**
 * Template defining a delegate suitable to be used as a ForeachAggregate.
 *
 * See_Also:
 *    $(LINK http://dlang.org/statement.html#ForeachStatement)
 */
private template ForeachAggregate(T)
{
	alias int delegate(ref T) ForeachAggregate;
}

/**
 * Template defining a delegate suitable to be used as an indexed 
 * ForeachAggregate.
 *
 * See_Also:
 *    $(LINK http://dlang.org/statement.html#ForeachStatement)
 */
private template IndexedForeachAggregate(T)
{
	alias int delegate(ref size_t, ref T) IndexedForeachAggregate;
}
/**
 * A generic doubly linked list implementation.
 */
class LinkedList(T)
{
	/**
	 * The starting node.
	 */
	private Node!(T)* _first;

	/**
	 * The last node.
	 */
	private Node!(T)* _last;

	/**
	 * The number of items in the list.
	 */
	private size_t _count;

	/**
	 * Get the first item in the list.
	 *
	 * Returns:
	 *     The first item in the list.
	 *
	 * Throws:
	 *     $(PARAM_TABLE
	 *         $(PARAM_ROW AssertError, If the list is empty.)
	 *     )
	 */
	final public @property T first() const nothrow pure
	{
		assert(this._first, "Linked list empty, getting first value failed.");

		return (*this._first).data;
	}

	/**
	 * Get the last item in the list.
	 *
	 * Returns:
	 *     The last item in the list.
	 *
	 * Throws:
	 *     $(PARAM_TABLE
	 *         $(PARAM_ROW AssertError, If the list is empty.)
	 *     )
	 */
	final public @property T last() const nothrow pure
	{
		assert(this._last, "Linked list empty, getting last value failed.");

		return (*this._last).data;
	}

	/**
	 * Get the number of items stored in the list.
	 *
	 * Returns:
	 *     The number of items stored in the list.
	 */
	final public @property size_t count() const nothrow pure
	{
		return this._count;
	}

	/**
	 * Test if the list is empty or not.
	 *
	 * Returns:
	 *     true if the list is empty, false if not.
	 */
	final public @property bool empty() const nothrow pure
	{
		return this._first is null || this._last is null;
	}

	/**
	 * Insert a new item at the beginning of the list.
	 *
	 * Params:
	 *     item = The item to insert.
	 *
	 * Throws:
	 *     $(PARAM_TABLE
	 *         $(PARAM_ROW InvalidMemoryOperationError, If memory allocation fails.)
	 *     )
	 */
	final public void insertFirst(T item) nothrow
	{
		auto node = cast(Node!(T)*)malloc(Node!(T).sizeof);

		if (node is null)
		{
			throw new InvalidMemoryOperationError();
		}

		(*node).prev = null;
		(*node).data = item;
		(*node).next = null;

		if (this._first)
		{
			(*this._first).prev = node;
			node.next = this._first;
			this._first = node;
		}
		else
		{
			this._first = node;
			this._last  = node;
		}

		this._count++;
	}

	/**
	 * Insert a new item at the end of the list.
	 *
	 * Params:
	 *     item = The item to insert.
	 *
	 * Throws:
	 *     $(PARAM_TABLE
	 *         $(PARAM_ROW InvalidMemoryOperationError, If memory allocation fails.)
	 *     )
	 */
	final public void insertLast(T item) nothrow
	{
		auto node = cast(Node!(T)*)malloc(Node!(T).sizeof);

		if (node is null)
		{
			throw new InvalidMemoryOperationError();
		}

		(*node).prev = null;
		(*node).data = item;
		(*node).next = null;

		if (this._last)
		{
			(*this._last).next = node;
			node.prev = this._last;
			this._last = node;
		}
		else
		{
			this._first = node;
			this._last  = node;
		}

		this._count++;
	}

	/**
	 * Insert a new item at the specified index. The index must be between (and 
	 * including) 0 and the number returned by the count method.
	 *
	 * Params:
	 *     item = The item to insert.
	 *     index = The index in which to insert the item.
	 *
	 * Throws:
	 *     $(PARAM_TABLE
	 *         $(PARAM_ROW RangeError, If index is outside of limits.)
	 *         $(PARAM_ROW InvalidMemoryOperationError, If memory allocation fails.)
	 *     )
	 */
	final public void insert(T item, size_t index) //nothrow
	{
		if (index < 0 || index > this._count)
		{
			throw new RangeError("Index outside of list.");
		}

		if (index == 0)
		{
			this.insertFirst(item);
		}
		else if (index == this._count)
		{
			this.insertLast(item);
		}
		else
		{
			auto newNode = cast(Node!(T)*)malloc(Node!(T).sizeof);

			if (newNode is null)
			{
				throw new InvalidMemoryOperationError();
			}

			(*newNode).data = item;

			if (index > this._count / 2)
			{
				size_t listIndex = this.count - 1;
				for (auto listNode = this._last; listNode !is null; listIndex--, listNode = (*listNode).prev)
				{
					if (listIndex == index)
					{
						(*(*listNode).prev).next = newNode;
						(*newNode).prev  = (*listNode).prev;
						(*newNode).next  = listNode;
						(*listNode).prev = newNode;
						break;
					}
				}
			}
			else
			{
				size_t listIndex;
				for (auto listNode = this._first; listNode !is null; listIndex++, listNode = (*listNode).next)
				{
					if (listIndex == index)
					{
						(*(*listNode).prev).next = newNode;
						(*newNode).prev  = (*listNode).prev;
						(*newNode).next  = listNode;
						(*listNode).prev = newNode;
						break;
					}
				}
			}

			this._count++;
		}

	}

	/**
	 * Clears the list and deallocates all memory used by the nodes.
	 */
	final public void clear() nothrow
	{
		for (auto node = this._first; node !is null; node = (*node).next)
		{
			free(node);
		}

		this._count = 0;
		this._first = null;
		this._last  = null;
	}

	/**
	 * Return a bidirectional range to allow this list to be using with various 
	 * other algorithms.
	 *
	 * Returns:
	 *     A bidirectional range representing this list.
	 *
	 * Example:
	 * ---
	 * import std.algorithm;
	 * import std.array;
	 * import std.string;
	 *
	 * auto list = new LinkedList!(string);
	 *
	 * list.insertLast("Qux");
	 * list.insertLast("Baz");
	 * list.insertLast("Foo");
	 * list.insertLast("Bar");
	 *
	 * assert(list.byValue.canFind("Baz"));
	 * assert(list.byValue.retro.map!(toLower).equal(["bar", "foo", "baz", "qux"]));
	 * assert(list.byValue.array.sort == ["Bar", "Baz", "Foo", "Qux"]);
	 * ---
	 */
	final public auto byValue()
	{
		static struct Result
		{
			private Node!(T)* _first;
			private Node!(T)* _last;

			public @property ref T front()
			{
				return (*this._first).data;
			}

			public @property ref T back()
			{
				return (*this._last).data;
			}

			public @property bool empty()
			{
				return this._first is null || this._last is null;
			}

			public void popFront()
			{
				this._first = (*this._first).next;
			}

			public void popBack()
			{
				this._last = (*this._last).prev;
			}

			public @property auto save()
			{
				return this;
			}
		}

		static assert(isBidirectionalRange!(Result));

		return Result(this._first, this._last);
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
	 * auto list = new LinkedList!(string);
	 *
	 * list.insertLast("Qux");
	 * list.insertLast("Baz");
	 * list.insertLast("Foo");
	 * list.insertLast("Bar");
	 *
	 * foreach (value; list)
	 * {
	 * 	writefln("%s", value);
	 * }
	 * ---
	 */
	final int opApply(ForeachAggregate!(T) dg)
	{
		int result;

		for (auto node = this._first; node !is null; node = (*node).next)
		{
			result = dg((*node).data);

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
	 * auto list = new LinkedList!(string);
	 *
	 * list.insertLast("Qux");
	 * list.insertLast("Baz");
	 * list.insertLast("Foo");
	 * list.insertLast("Bar");
	 *
	 * foreach (index, value; list)
	 * {
	 * 	writefln("%s: %s", index, value);
	 * }
	 * ---
	 */
	final int opApply(IndexedForeachAggregate!(T) dg)
	{
		int result;
		size_t index;

		for (auto node = this._first; node !is null; index++, node = (*node).next)
		{
			result = dg(index, (*node).data);

			if (result)
			{
				break;
			}
		}

		return result;
	}

	/**
	 * Enable reverse iteration in foreach loops.
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
	 * auto list = new LinkedList!(string);
	 *
	 * list.insertLast("Qux");
	 * list.insertLast("Baz");
	 * list.insertLast("Foo");
	 * list.insertLast("Bar");
	 *
	 * foreach_reverse (value; list)
	 * {
	 * 	writefln("%s", value);
	 * }
	 * ---
	 */
	final int opApplyReverse(ForeachAggregate!(T) dg)
	{
		int result;

		for (auto node = this._last; node !is null; node = (*node).prev)
		{
			result = dg((*node).data);

			if (result)
			{
				break;
			}
		}

		return result;
	}

	/**
	 * Enable reverse iteration in foreach loops using an index.
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
	 * auto list = new LinkedList!(string);
	 *
	 * list.insertLast("Qux");
	 * list.insertLast("Baz");
	 * list.insertLast("Foo");
	 * list.insertLast("Bar");
	 *
	 * foreach_reverse (index, value; list)
	 * {
	 * 	writefln("%s: %s", index, value);
	 * }
	 * ---
	 */
	final int opApplyReverse(IndexedForeachAggregate!(T) dg)
	{
		int result;
		size_t index = this.count - 1;

		for (auto node = this._last; node !is null; index--, node = (*node).prev)
		{
			result = dg(index, (*node).data);

			if (result)
			{
				break;
			}
		}

		return result;
	}

	/**
	 * Destructor.
	 */
	final private ~this() nothrow
	{
		this.clear();
	}
}

///
unittest
{
	import std.algorithm;

	auto list = new LinkedList!(string);

	list.insertLast("Qux");
	list.insertLast("Baz");
	list.insertLast("Foo");
	list.insertLast("Bar");

	assert(list.first == "Qux");
	assert(list.last == "Bar");
	assert(list.count == 4);
	assert(!list.empty);

	assert(list.byValue.canFind("Baz"));
	assert(list.byValue.retro.equal(["Bar", "Foo", "Baz", "Qux"]));
	assert(list.byValue.array.sort == ["Bar", "Baz", "Foo", "Qux"]);

	list.clear();
	assert(list.empty);
	assert(list.count == 0);
}

unittest
{
	auto list = new LinkedList!(int);

	list.insert(3, 0);
	assert(list.byValue.array == [3]);

	list.insert(1, 0);
	assert(list.byValue.array == [1, 3]);

	list.insert(4, 2);
	assert(list.byValue.array == [1, 3, 4]);

	list.insert(2, 1);
	assert(list.byValue.array == [1, 2, 3, 4]);
}

unittest
{
	auto list = new LinkedList!(string);

	list.insertFirst("Qux");
	assert(list.first == "Qux");

	list.insertFirst("Baz");
	assert(list.first == "Baz");

	list.insertFirst("Bar");
	assert(list.first == "Bar");

	list.insertFirst("Foo");
	assert(list.first == "Foo");

	assert(list.byValue.array == ["Foo", "Bar", "Baz", "Qux"]);
}

unittest
{
	auto list = new LinkedList!(string);

	list.insertLast("Foo");
	assert(list.last == "Foo");

	list.insertLast("Bar");
	assert(list.last == "Bar");

	list.insertLast("Baz");
	assert(list.last == "Baz");

	list.insertLast("Qux");
	assert(list.last == "Qux");

	assert(list.byValue.array == ["Foo", "Bar", "Baz", "Qux"]);
}

unittest
{
	auto list = new LinkedList!(byte);

	list.insertLast(2);
	list.insertLast(4);
	list.insertLast(6);
	list.insertLast(8);

	assert(list.first == 2);
	assert(list.last  == 8);
	assert(list.count == 4);
	assert(!list.empty);

	size_t counter;
	auto data  = [2, 4, 6, 8];

	foreach (value; list.byValue)
	{
		assert(value == data[counter++]);
	}

	counter = 0;
	foreach (value; list.byValue.save)
	{
		assert(value == data[counter++]);
	}

	counter = 0;
	foreach (value; list)
	{
		assert(value == data[counter++]);
	}

	counter = 0;
	foreach (index, value; list)
	{
		assert(index == counter);
		assert(value == data[counter++]);
	}

	counter = 0;
	foreach_reverse (value; list)
	{
		assert(value == data.retro[counter++]);
	}

	counter = 0;
	foreach_reverse (index, value; list)
	{
		assert(index == (data.length - 1) - counter);
		assert(value == data.retro[counter++]);
	}

	list.clear();
	assert(list.count == 0);
	assert(list.empty);
}

unittest
{
	auto list = new LinkedList!(int);

	assert(list.empty);
	assert(list.count == 0);

	int limit = 10_000_000;

	for (int x = 1; x <= limit ; x++)
	{
		list.insertLast(x);
		assert(list.last == x);
		assert(list.count == x);
	}

	assert(list.count == limit);
	assert(!list.empty);

	list.insert(1, 9_999_995);
}
