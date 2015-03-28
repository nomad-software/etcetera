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
import core.memory;
import std.range;
import std.traits;

/**
 * A node in the linked list.
 *
 * Params:
 *     T = The type stored in each node in the list.
 */
private struct Node(T)
{
	/**
	 * The previous node.
	 */
	public Node!(T)* prev;

	/**
	 * The next node.
	 */
	public Node!(T)* next;

	/**
	 * The node data.
	 */
	public T data;
}

/**
 * Template defining a delegate suitable to be used as a ForeachAggregate.
 *
 * Params:
 *     T = The type stored in each node in the list.
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
 * Params:
 *     T = The type stored in each node in the list.
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
 *
 * Params:
 *     T = The type stored in each node in the list.
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
	final public @property T first() nothrow pure
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
	final public @property T last() nothrow pure
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
	 *         $(PARAM_ROW OutOfMemoryError, If memory allocation fails.)
	 *     )
	 */
	final public void insertFirst(T item) nothrow
	{
		static if (hasIndirections!(T))
		{
			auto node = cast(Node!(T)*)GC.malloc(Node!(T).sizeof, GC.BlkAttr.NO_MOVE, typeid(T));
			GC.addRoot(node);
		}
		else
		{
			auto node = cast(Node!(T)*)GC.malloc(Node!(T).sizeof, GC.BlkAttr.NO_MOVE | GC.BlkAttr.NO_SCAN, typeid(T));
			GC.addRoot(node);
		}

		(*node).prev = null;
		(*node).next = null;
		(*node).data = item;

		if (this._first !is null)
		{
			(*this._first).prev = node;
			(*node).next = this._first;
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
	 * Remove the first item in the list.
	 */
	final public void removeFirst() nothrow
	{
		if (this._first !is null)
		{
			if ((*this._first).next !is null)
			{
				this._first = (*this._first).next;
				GC.removeRoot((*this._first).prev);
				GC.free((*this._first).prev);
				(*this._first).prev = null;
			}
			else
			{
				GC.removeRoot(this._first);
				GC.free(this._first);
				this._first = null;
				this._last  = null;
			}

			this._count--;
		}
	}

	/**
	 * Insert a new item at the end of the list.
	 *
	 * Params:
	 *     item = The item to insert.
	 *
	 * Throws:
	 *     $(PARAM_TABLE
	 *         $(PARAM_ROW OutOfMemoryError, If memory allocation fails.)
	 *     )
	 */
	final public void insertLast(T item) nothrow
	{
		static if (hasIndirections!(T))
		{
			auto node = cast(Node!(T)*)GC.malloc(Node!(T).sizeof, GC.BlkAttr.NO_MOVE, typeid(T));
			GC.addRoot(node);
		}
		else
		{
			auto node = cast(Node!(T)*)GC.malloc(Node!(T).sizeof, GC.BlkAttr.NO_MOVE | GC.BlkAttr.NO_SCAN, typeid(T));
			GC.addRoot(node);
		}

		(*node).prev = null;
		(*node).next = null;
		(*node).data = item;

		if (this._last !is null)
		{
			(*this._last).next = node;
			(*node).prev = this._last;
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
	 * Remove the last item in the list.
	 */
	final public void removeLast() nothrow
	{
		if (this._last !is null)
		{
			if ((*this._last).prev !is null)
			{
				this._last = (*this._last).prev;
				GC.removeRoot((*this._last).next);
				GC.free((*this._last).next);
				(*this._last).next = null;
			}
			else
			{
				GC.removeRoot(this._last);
				GC.free(this._last);
				this._first = null;
				this._last  = null;
			}

			this._count--;
		}
	}

	/**
	 * Insert a new item at the specified index. The index must be between (and 
	 * including) 0 and the number returned by the count method.
	 *
	 * This method uses a linear search to find the index in the list. The only 
	 * optimisation done is that if the index is past half way, the search 
	 * starts from the last item and works backwards.
	 *
	 * Params:
	 *     item = The item to insert.
	 *     index = The index in which to insert the item.
	 *
	 * Throws:
	 *     $(PARAM_TABLE
	 *         $(PARAM_ROW AssertError, If index is outside of limits.)
	 *         $(PARAM_ROW OutOfMemoryError, If memory allocation fails.)
	 *     )
	 */
	final public void insert(T item, size_t index) nothrow
	{
		assert(index >= 0 || index <= this._count, "Index outside of list bounds.");

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
			static if (hasIndirections!(T))
			{
				auto newNode = cast(Node!(T)*)GC.malloc(Node!(T).sizeof, GC.BlkAttr.NO_MOVE, typeid(T));
				GC.addRoot(newNode);
			}
			else
			{
				auto newNode = cast(Node!(T)*)GC.malloc(Node!(T).sizeof, GC.BlkAttr.NO_MOVE | GC.BlkAttr.NO_SCAN, typeid(T));
				GC.addRoot(newNode);
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
	 * Get the item at the specified index. The index must be between (and 
	 * including) 0 and be below the number returned by the count method.
	 *
	 * This method uses a linear search to find the index in the list. The only 
	 * optimisation done is that if the index is past half way, the search 
	 * starts from the last item and works backwards.
	 *
	 * Params:
	 *     index = The index of the item to return.
	 *
	 * Throws:
	 *     $(PARAM_TABLE
	 *         $(PARAM_ROW AssertError, If index is outside of limits.)
	 *     )
	 */
	final public T get(size_t index) nothrow pure
	{
		assert(this._count, "List empty, getting value failed.");
		assert(index >= 0 || index < this._count, "Index outside of list bounds.");

		if (index == 0)
		{
			return (*this._first).data;
		}
		else if (index == this._count - 1)
		{
			return (*this._last).data;
		}
		else
		{
			if (index >= this._count / 2)
			{
				size_t listIndex = this.count - 1;
				for (auto listNode = this._last; listNode !is null; listIndex--, listNode = (*listNode).prev)
				{
					if (listIndex == index)
					{
						return (*listNode).data;
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
						return (*listNode).data;
					}
				}
			}
		}
		assert(0, "Error accessing linked list.");
	}

	/**
	 * Remove the item at the specified index. The index must be between (and 
	 * including) 0 and be below the number returned by the count method.
	 *
	 * This method uses a linear search to find the index in the list. The only 
	 * optimisation done is that if the index is past half way, the search 
	 * starts from the last item and works backwards.
	 *
	 * Params:
	 *     index = The index of the item to remove.
	 *
	 * Throws:
	 *     $(PARAM_TABLE
	 *         $(PARAM_ROW AssertError, If index is outside of limits.)
	 *     )
	 */
	final public void remove(size_t index) nothrow
	{
		assert(this._count, "List empty, getting value failed.");
		assert(index >= 0 || index < this._count, "Index outside of list bounds.");

		if (index == 0)
		{
			this.removeFirst();
		}
		else if (index == this._count - 1)
		{
			this.removeLast();
		}
		else
		{
			if (index >= this._count / 2)
			{
				size_t listIndex = this.count - 1;
				for (auto listNode = this._last; listNode !is null; listIndex--, listNode = (*listNode).prev)
				{
					if (listIndex == index)
					{
						(*(*listNode).prev).next = (*listNode).next;
						(*(*listNode).next).prev = (*listNode).prev;
						GC.removeRoot(listNode);
						GC.free(listNode);
						this._count--;
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
						(*(*listNode).prev).next = (*listNode).next;
						(*(*listNode).next).prev = (*listNode).prev;
						GC.removeRoot(listNode);
						GC.free(listNode);
						this._count--;
						break;
					}
				}
			}
		}
	}

	/**
	 * Clears the list and deallocates all memory used by the nodes.
	 */
	final public void clear() nothrow
	{
		for (auto node = this._first; node !is null; node = (*node).next)
		{
			GC.removeRoot(node);
			GC.free(node);
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
	final public auto byValue() nothrow pure
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
	final public int opApply(ForeachAggregate!(T) dg)
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
	final public int opApply(IndexedForeachAggregate!(T) dg)
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
	final public int opApplyReverse(ForeachAggregate!(T) dg)
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
	final public int opApplyReverse(IndexedForeachAggregate!(T) dg)
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

	list.clear();
	assert(list.empty);
	assert(list.count == 0);
}

unittest
{
	import std.algorithm;

	auto list = new LinkedList!(int);

	assert(list.empty);
	assert(list.count == 0);

	int limit = 1_000_000;

	for (int x = 1; x <= limit ; x++)
	{
		list.insertLast(x);
		assert(list.last == x);
		assert(list.count == x);
	}

	assert(list.last == limit);
	assert(list.count == limit);
	assert(list.byValue.canFind(1));
	assert(list.byValue.canFind(limit));
	assert(!list.empty);

	for (int x = limit; x >= 1 ; x--)
	{
		assert(list.count == x);
		assert(list.last == x);
		list.removeLast();
	}

	assert(list.empty);

	for (int x = 1; x <= limit ; x++)
	{
		list.insertFirst(x);
		assert(list.first == x);
		assert(list.count == x);
	}

	assert(list.first == limit);
	assert(list.count == limit);
	assert(list.byValue.canFind(1));
	assert(list.byValue.canFind(limit));
	assert(!list.empty);

	for (int x = limit; x >= 1 ; x--)
	{
		assert(list.count == x);
		assert(list.first == x);
		list.removeFirst();
	}

	assert(list.empty);

	for (int x = 1; x <= limit ; x++)
	{
		list.insertLast(x);
		assert(list.last == x);
		assert(list.count == x);
	}

	list.clear();

	assert(list.empty);
	assert(list.count == 0);
	assert(!list.byValue.canFind(1));
	assert(!list.byValue.canFind(limit));
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
	auto list = new LinkedList!(string);

	list.insertFirst("Qux");
	assert(list.first == "Qux");
	assert(list.byValue.array == ["Qux"]);

	list.insertFirst("Baz");
	assert(list.first == "Baz");
	assert(list.byValue.array == ["Baz", "Qux"]);

	list.insertFirst("Bar");
	assert(list.first == "Bar");
	assert(list.byValue.array == ["Bar", "Baz", "Qux"]);

	list.insertFirst("Foo");
	assert(list.first == "Foo");
	assert(list.byValue.array == ["Foo", "Bar", "Baz", "Qux"]);
}

unittest
{
	auto list = new LinkedList!(string);

	list.insertLast("Foo");
	list.insertLast("Bar");
	list.insertLast("Baz");
	list.insertLast("Qux");

	assert(list.first == "Foo");
	assert(list.last == "Qux");
	assert(list.byValue.array == ["Foo", "Bar", "Baz", "Qux"]);
	assert(list.count == 4);

	list.removeFirst();
	assert(list.first == "Bar");
	assert(list.last == "Qux");
	assert(list.byValue.array == ["Bar", "Baz", "Qux"]);
	assert(list.count == 3);

	list.removeFirst();
	assert(list.first == "Baz");
	assert(list.last == "Qux");
	assert(list.byValue.array == ["Baz", "Qux"]);
	assert(list.count == 2);

	list.removeFirst();
	assert(list.first == "Qux");
	assert(list.last == "Qux");
	assert(list.byValue.array == ["Qux"]);
	assert(list.count == 1);

	list.removeFirst();
	assert(list._first is null);
	assert(list._last is null);
	assert(list.byValue.array == []);
	assert(list.count == 0);
}

unittest
{
	auto list = new LinkedList!(string);

	list.insertLast("Foo");
	assert(list.last == "Foo");
	assert(list.byValue.array == ["Foo"]);

	list.insertLast("Bar");
	assert(list.last == "Bar");
	assert(list.byValue.array == ["Foo", "Bar"]);

	list.insertLast("Baz");
	assert(list.last == "Baz");
	assert(list.byValue.array == ["Foo", "Bar", "Baz"]);

	list.insertLast("Qux");
	assert(list.last == "Qux");
	assert(list.byValue.array == ["Foo", "Bar", "Baz", "Qux"]);
}

unittest
{
	auto list = new LinkedList!(string);

	list.insertLast("Foo");
	list.insertLast("Bar");
	list.insertLast("Baz");
	list.insertLast("Qux");

	assert(list.first == "Foo");
	assert(list.last == "Qux");
	assert(list.byValue.array == ["Foo", "Bar", "Baz", "Qux"]);
	assert(list.count == 4);

	list.removeLast();
	assert(list.first == "Foo");
	assert(list.last == "Baz");
	assert(list.byValue.array == ["Foo", "Bar", "Baz"]);
	assert(list.count == 3);

	list.removeLast();
	assert(list.first == "Foo");
	assert(list.last == "Bar");
	assert(list.byValue.array == ["Foo", "Bar"]);
	assert(list.count == 2);

	list.removeLast();
	assert(list.first == "Foo");
	assert(list.last == "Foo");
	assert(list.byValue.array == ["Foo"]);
	assert(list.count == 1);

	list.removeLast();
	assert(list._first is null);
	assert(list._last is null);
	assert(list.byValue.array == []);
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

	list.insertLast("Foo");
	list.insertLast("Bar");
	list.insertLast("Baz");
	list.insertLast("Qux");

	assert(list.get(0) == list.first);
	assert(list.get(1) == "Bar");
	assert(list.get(2) == "Baz");
	assert(list.get(list.count - 1) == list.last);

	assert(list.byValue.array == ["Foo", "Bar", "Baz", "Qux"]);
	assert(list.count == 4);
}

unittest
{
	auto list = new LinkedList!(string);

	list.insertLast("Foo");
	list.insertLast("Bar");
	list.insertLast("Baz");
	list.insertLast("Qux");
	list.insertLast("Quux");

	assert(list.byValue.array == ["Foo", "Bar", "Baz", "Qux", "Quux"]);
	assert(list.count == 5);

	list.remove(2);
	assert(list.byValue.array == ["Foo", "Bar", "Qux", "Quux"]);
	assert(list.count == 4);

	list.remove(1);
	assert(list.byValue.array == ["Foo", "Qux", "Quux"]);
	assert(list.count == 3);

	list.remove(2);
	assert(list.byValue.array == ["Foo", "Qux"]);
	assert(list.count == 2);

	list.remove(0);
	assert(list.byValue.array == ["Qux"]);
	assert(list.count == 1);

	list.remove(0);
	assert(list.byValue.array == []);
	assert(list.count == 0);
	assert(list._first is null);
	assert(list._last is null);
}

unittest
{
	auto list = new LinkedList!(int);

	assert(list.empty);
	assert(list.count == 0);

	int limit = 1000;

	for (int x = 1; x <= limit ; x++)
	{
		list.insertLast(x);
		assert(list.last == x);
		assert(list.count == x);
	}

	assert(list.count == limit);
	assert(!list.empty);

	list.insert(1337, 995);

	assert(list.get(994) == 995);
	assert(list.get(995) == 1337);
	assert(list.get(996) == 996);

	list.remove(995);

	assert(list.get(994) == 995);
	assert(list.get(995) == 996);
	assert(list.get(996) == 997);
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

	auto list = new LinkedList!(Foo);

	list.insert(new Foo(1), 0);
	list.insert(new Foo(3), 1);
	list.insert(new Foo(2), 1);

	assert(list.get(0)._foo == 1);
	assert(list.get(1)._foo == 2);
	assert(list.get(2)._foo == 3);
}

