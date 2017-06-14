/**
 * Collection module.
 *
 * License:
 *     MIT. See LICENSE for full details.
 */
module etcetera.collection.linkedlist;

/**
 * Imports.
 */
import core.exception;
import core.memory;
import core.stdc.stdlib : malloc, free;
import std.range;
import std.traits;

/**
 * A generic doubly linked list implementation.
 *
 * Params:
 *     T = The type stored in each node in the list.
 */
struct LinkedList(T) if (is(T == Unqual!T))
{
	@nogc:
	nothrow:

	/**
	 * A node in the linked list.
	 *
	 * Params:
	 *     T = The type stored in each node in the list.
	 */
	private static struct Node
	{
		/**
		 * The previous node.
		 */
		public Node* prev;

		/**
		 * The next node.
		 */
		public Node* next;

		/**
		 * The node data.
		 */
		public T data;
	}

	/**
	 * The reference count.
	 */
	private int* _refCount;

	/**
	 * The starting node.
	 */
	private Node* _first;

	/**
	 * The last node.
	 */
	private Node* _last;

	/**
	 * The number of items in the list.
	 */
	private size_t _count;

	/*
	 * Disable the default constructor.
	 */
	@disable this();

	/**
	 * Construct a new linked list.
	 *
	 * Params:
	 *     items = An array of items to initialise the collection with.
	 */
	public this(T[] items)
	{
		this._refCount  = cast(int*) malloc(int.sizeof);
		*this._refCount = 1;

		foreach (item; items)
		{
			this.insertLast(item);
		}
	}

	/**
	 * Copy constructor post blit.
	 */
	public this(this) pure
	{
		if (this._refCount !is null)
		{
			*this._refCount += 1;
		}
	}

	/**
	 * Destructor.
	 */
	public ~this()
	{
		if (this._refCount !is null)
		{
			*this._refCount -= 1;

			if (*this._refCount <= 0)
			{
				this.clear();
				free(this._refCount);
			}
		}
	}

	/**
	 * Get the number of items stored in the list.
	 *
	 * Returns:
	 *     The number of items stored in the list.
	 */
	public @property size_t count() const pure
	{
		return this._count;
	}

	/**
	 * Test if the list is empty or not.
	 *
	 * Returns:
	 *     true if the list is empty, false if not.
	 */
	public @property bool empty() const pure
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
	public void insertFirst(T item)
	{
		auto node = cast(Node*) malloc(Node.sizeof);

		if (node is null)
		{
			onOutOfMemoryError();
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

		static if (hasIndirections!(T))
		{
			GC.addRange(node, Node.sizeof, typeid(T));
		}

		this._count++;
	}

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
	public @property T first() pure
	{
		assert(this._first, "Linked list empty, getting first value failed.");

		return (*this._first).data;
	}

	/**
	 * Remove the first item in the list.
	 */
	public void removeFirst()
	{
		if (this._first !is null)
		{
			if ((*this._first).next !is null)
			{
				this._first = (*this._first).next;
				GC.removeRange((*this._first).prev);
				free((*this._first).prev);
				(*this._first).prev = null;
			}
			else
			{
				GC.removeRange(this._first);
				free(this._first);
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
	public void insertLast(T item)
	{
		auto node = cast(Node*) malloc(Node.sizeof);

		if (node is null)
		{
			onOutOfMemoryError();
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

		static if (hasIndirections!(T))
		{
			GC.addRange(node, Node.sizeof, typeid(T));
		}

		this._count++;
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
	public @property T last() pure
	{
		assert(this._last, "Linked list empty, getting last value failed.");

		return (*this._last).data;
	}

	/**
	 * Remove the last item in the list.
	 */
	public void removeLast()
	{
		if (this._last !is null)
		{
			if ((*this._last).prev !is null)
			{
				this._last = (*this._last).prev;
				GC.removeRange((*this._last).next);
				free((*this._last).next);
				(*this._last).next = null;
			}
			else
			{
				GC.removeRange(this._last);
				free(this._last);
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
	public void insert(T item, size_t index)
	{
		assert(index >= 0 && index <= this._count, "Index outside of list bounds.");

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
			auto newNode = cast(Node*) malloc(Node.sizeof);

			if (newNode is null)
			{
				onOutOfMemoryError();
			}

			(*newNode).data = item;

			if (index > this._count / 2)
			{
				size_t listIndex = this._count - 1;
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

			static if (hasIndirections!(T))
			{
				GC.addRange(newNode, Node.sizeof, typeid(T));
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
	public T get(size_t index) pure
	{
		assert(this._count, "List empty, getting value failed.");
		assert(index >= 0 && index < this._count, "Index outside of list bounds.");

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
				size_t listIndex = this._count - 1;
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

		assert(false, "Error accessing linked list.");
	}

	/**
	 * Update the item at the specified index. The index must be between (and
	 * including) 0 and be below the number returned by the count method.
	 *
	 * This method uses a linear search to find the index in the list. The only
	 * optimisation done is that if the index is past half way, the search
	 * starts from the last item and works backwards.
	 *
	 * Params:
	 *     index = The index of the item to update.
	 *     item = The new item to insert.
	 *
	 * Throws:
	 *     $(PARAM_TABLE
	 *         $(PARAM_ROW AssertError, If index is outside of limits.)
	 *     )
	 */
	public void update(size_t index, T item) pure
	{
		assert(this._count, "List empty, updating value failed.");
		assert(index >= 0 && index < this._count, "Index outside of list bounds.");

		if (index == 0)
		{
			(*this._first).data = item;
		}
		else if (index == this._count - 1)
		{
			(*this._last).data = item;
		}
		else
		{
			if (index >= this._count / 2)
			{
				size_t listIndex = this._count - 1;
				for (auto listNode = this._last; listNode !is null; listIndex--, listNode = (*listNode).prev)
				{
					if (listIndex == index)
					{
						(*listNode).data = item;
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
						(*listNode).data = item;
					}
				}
			}
		}
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
	public void remove(size_t index)
	{
		assert(this._count, "List empty, getting value failed.");
		assert(index >= 0 && index < this._count, "Index outside of list bounds.");

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
				size_t listIndex = this._count - 1;
				auto node = this._last;

				while (node !is null)
				{
					if (listIndex == index)
					{
						(*(*node).prev).next = (*node).next;
						(*(*node).next).prev = (*node).prev;
						GC.removeRange(node);
						free(node);
						this._count--;
						break;
					}

					node = (*node).prev;
					listIndex--;
				}
			}
			else
			{
				size_t listIndex;
				auto node = this._first;

				while (node !is null)
				{
					if (listIndex == index)
					{
						(*(*node).prev).next = (*node).next;
						(*(*node).next).prev = (*node).prev;
						GC.removeRange(node);
						free(node);
						this._count--;
						break;
					}

					node = (*node).next;
					listIndex++;
				}
			}
		}
	}

	/**
	 * Check if a value is contained in the list.
	 *
	 * This is a simple linear search and can take quite some time with large
	 * lists.
	 *
	 * Params:
	 *     item = The item to find in the list.
	 *
	 * Returns:
	 *     true if the item is found on the list, false if not.
	 */
	public bool contains(T item) pure
	{
		if (!this.empty)
		{
			for (auto node = this._first; node !is null; node = (*node).next)
			{
				// For the time being we have to handle classes and interfaces as a
				// special case when comparing because Object.opEquals is not @nogc.
				static if (is(T == class) || is(T == interface))
				{
					if (item is (*node).data)
					{
						return true;
					}
				}
				else
				{
					if (item == (*node).data)
					{
						return true;
					}
				}
			}
		}

		return false;
	}

	/**
	 * Clears the list and deallocates all memory used by the nodes.
	 */
	public void clear()
	{
		auto node = this._first;
		auto next = this._first;

		while (next !is null)
		{
			next = (*node).next;

			GC.removeRange(node);
			free(node);

			node = next;
		}

		this._count = 0;
		this._first = null;
		this._last  = null;
	}

	/**
	 * Return a bidirectional range to allow this list to be used with various
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
	 * auto list = LinkedList!(string)([]);
	 *
	 * list.insertLast("Qux");
	 * list.insertLast("Baz");
	 * list.insertLast("Foo");
	 * list.insertLast("Bar");
	 *
	 * assert(list.byValue.canFind("Baz"));
	 * assert(list.byValue.retro.map!(toLower).equal(["bar", "foo", "baz", "qux"]));
	 * ---
	 */
	public auto byValue() pure
	{
		static struct Result
		{
			private Node* _first;
			private Node* _last;
			private size_t _count;

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

			public @property size_t length()
			{
				return this._count;
			}
		}

		static assert(isBidirectionalRange!(Result));
		static assert(hasLength!(Result));

		return Result(this._first, this._last, this._count);
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
	 * auto list = LinkedList!(string)([]);
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
	public int opApply(scope int delegate(ref T) nothrow @nogc dg)
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
	 * auto list = LinkedList!(string)([]);
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
	public int opApply(scope int delegate(ref size_t, ref T) nothrow @nogc dg)
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
	 * auto list = LinkedList!(string)([]);
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
	public int opApplyReverse(scope int delegate(ref T) nothrow @nogc dg)
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
	 * auto list = LinkedList!(string)([]);
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
	public int opApplyReverse(scope int delegate(ref size_t, ref T) nothrow @nogc dg)
	{
		int result;
		size_t index = this._count - 1;

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

	auto list = LinkedList!(string)(["Qux", "Baz"]);

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

// Test reference counting.

unittest
{
	auto foo(T)(T list)
	{
		assert(*list._refCount == 2);
	}

	auto bar(T)(ref T list)
	{
		assert(*list._refCount == 1);
	}

	auto baz(T)(T list)
	{
		assert(*list._refCount == 1);
		return list;
	}

	auto qux()
	{
		return LinkedList!(string)([]);
	}

	auto list = LinkedList!(string)([]);

	assert(*list._refCount == 1);

	foo(list);
	assert(*list._refCount == 1);

	bar(list);
	assert(*list._refCount == 1);

	list = baz(LinkedList!(string)([]));
	assert(*list._refCount == 1);

	list = qux();
	assert(*list._refCount == 1);
}

// Test big datasets.

unittest
{
	import std.algorithm;

	auto list = LinkedList!(int)([]);

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
	assert(list.contains(1));
	assert(list.contains(limit));
	assert(list.byValue.canFind(1));
	assert(list.byValue.canFind(limit));
	assert(list.byValue.length == limit);
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
	assert(list.contains(1));
	assert(list.contains(limit));
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
	assert(!list.contains(1));
	assert(!list.contains(limit));
	assert(!list.byValue.canFind(1));
	assert(!list.byValue.canFind(limit));
	assert(list.byValue.length == 0);
}

// Interogate the interface.

unittest
{
	auto list = LinkedList!(byte)([]);

	list.insertLast(3);
	list.insertFirst(1);
	list.insert(2, 1);
	list.insertLast(5);
	list.insert(4, 3);

	assert(list.get(0) == 1);
	assert(list.get(1) == 2);
	assert(list.get(2) == 3);
	assert(list.get(3) == 4);
	assert(list.get(4) == 5);

	list.update(0, 8);
	list.update(1, 8);
	list.update(2, 8);
	list.update(3, 8);
	list.update(4, 8);

	list.remove(1);
	list.remove(2);
	list.remove(0);
	list.remove(1);
	list.remove(0);
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

	auto list = LinkedList!(Foo)([]);
	auto foo  = new Foo(1);

	list.insert(foo, 0);
	list.insert(new Foo(3), 1);
	list.insert(new Foo(2), 1);

	assert(list.contains(foo));
	assert(!list.contains(new Foo(1)));
	assert(list.last._foo == 3);

	list.clear();
	assert(list.empty);
}

// Test storing interfaces.

unittest
{
	interface Foo
	{
		public void foo();
	}

	auto list = LinkedList!(Foo)([]);
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

	auto list = LinkedList!(Foo)([]);
	auto foo  = Foo(1);

	list.insertLast(foo);

	assert(list.contains(foo));
	assert(!list.contains(Foo(2)));
	assert(list.last._foo == 1);
}

// Test the range interface.

unittest
{
	import std.algorithm;
	import std.range;
	import std.string;

	auto list = LinkedList!(string)(["Foo", "Bar", "Baz"]);

	assert(list.byValue.canFind("Baz"));
	assert(list.byValue.map!(toLower).array == ["foo", "bar", "baz"]);
	assert(list.byValue.save.array == ["Foo", "Bar", "Baz"]);
}

// Test iteration.

unittest
{
	auto list = LinkedList!(byte)([2, 4, 6, 8]);

	size_t counter;
	auto data  = [2, 4, 6, 8];

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

