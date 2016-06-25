/**
 * Collection module.
 *
 * License:
 *     MIT. See LICENSE for full details.
 */
module etcetera.collection.binaryheap;

/**
 * Imports.
 */
import core.exception;
import core.memory;
import core.stdc.stdlib : malloc, calloc, realloc, free;
import core.stdc.string : memset;
import std.algorithm;
import std.functional;
import std.range;
import std.traits;

/**
 * A generic binary heap implementation.
 *
 * Params:
 *     T = The type stored in the heap.
 *     pred = A predicate that returns true if the first parameter is greater
 *     than the second. This predicate defines the sorting order between the
 *     heap items and is called during insertion and extraction.
 */
struct BinaryHeap(T, alias pred) if (is(T == Unqual!T) && is(typeof(binaryFun!(pred)(T.init, T.init)) == bool))
{
	@nogc:
	nothrow:

	/**
	 * The reference count.
	 */
	private int* _refCount;

	/**
	 * The comparison method.
	 */
	private alias greaterFirst = binaryFun!(pred);

	/**
	 * A pointer to the heap data.
	 */
	private T* _data;

	/**
	 * A pointer to the end of the heap.
	 */
	private T* _end;

	/**
	 * The minimum size in bytes that the heap will allocate.
	 */
	private size_t _minSize;

	/**
	 * The current size in bytes of the heap.
	 */
	private size_t _size;

	/**
	 * The number of items currently held in the heap.
	 */
	private size_t _count;

	/**
	 * A flag representing if the internal state is sorted or not.
	 */
	private bool _stateIsSorted;

	/*
	 * Disable the default constructor.
	 */
	@disable this();

	/**
	 * Construct a new binary heap.
	 *
	 * When created, this collection is allocated enough memory for a minimum
	 * amount of items. If the collection becomes full, the allocation will
	 * double, ad infinitum. If items only occupy half of the collection, the
	 * allocation will be halfed. The collection will never shrink below the
	 * minimum capacity amount.
	 *
	 * Params:
	 *     minCapacity = The minimum number of items to allocate space for.
	 *                   The heap will never shrink below this allocation.
	 *
	 * Throws:
	 *     $(PARAM_TABLE
	 *         $(PARAM_ROW AssertError, If the minimum allocated size is not big enough for at least one item.)
	 *         $(PARAM_ROW OutOfMemoryError, If memory allocation fails.)
	 *     )
	 */
	public this(size_t minCapacity)
	{
		assert(minCapacity >= 1, "Heap must allow for at least one item.");

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

		this._end = this._data - 1;
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
	 * Get the number of items stored in the heap.
	 *
	 * Returns:
	 *     The number of items stored in the heap.
	 */
	public @property size_t count() const pure
	{
		return this._count;
	}

	/**
	 * Test if the heap is empty or not.
	 *
	 * Returns:
	 *     true if the heap is empty, false if not.
	 */
	public @property bool empty() const pure
	{
		return (this._count == 0);
	}

	/**
	 * The current item capacity of the heap. This will change if the heap
	 * reallocates more memory.
	 *
	 * Returns:
	 *     The capacity of how many items the heap can hold.
	 */
	private @property size_t capacity() const pure
	{
		return this._size / T.sizeof;
	}

	/**
	 * Insert an item into the heap.
	 *
	 * This method reallocates and doubles the memory used by the heap if no
	 * more items can be stored in available memory.
	 *
	 * Params:
	 *     item = The item to insert into the heap.
	 *
	 * Throws:
	 *     $(PARAM_TABLE
	 *         $(PARAM_ROW OutOfMemoryError, If memory reallocation fails.)
	 *     )
	 */
	public void insert(T item)
	{
		this._end++;

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

			this._end = this._data + this._count;

			memset(this._end, 0, this._size / 2);
		}

		this._count++;

		*this._end = item;
		this.siftUp(this._end - this._data);
		this._stateIsSorted = false;
	}

	/**
	 * Peek at the item on the top of the heap. This does not extract the item.
	 *
	 * Returns:
	 *     The item at the top of the heap.
	 *
	 * Throws:
	 *     $(PARAM_TABLE
	 *         $(PARAM_ROW AssertError, If the heap is empty.)
	 *     )
	 */
	public T peek() pure
	{
		assert(this._count, "Heap empty, peeking failed.");

		return *this._data;
	}

	/**
	 * Extract the value from the top of the heap and re-order the remaining
	 * items.
	 *
	 * Returns:
	 *     An item from the top of the heap.
	 *
	 * Throws:
	 *     $(PARAM_TABLE
	 *         $(PARAM_ROW AssertError, If the heap is empty.)
	 *         $(PARAM_ROW OutOfMemoryError, If memory reallocation fails.)
	 *     )
	 */
	public T extract()
	{
		assert(this._count, "Heap empty, extracting failed.");

		this._count--;
		auto extracted = *this._data;

		*this._data = *this._end;

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

			this._end   = this._data + (this._count - 1);
		}
		else
		{
			memset(this._end, 0, T.sizeof);
			this._end--;
		}

		this.siftDown(0);
		this._stateIsSorted = false;

		return extracted;
	}

	/**
	 * Check if a value is contained in the heap.
	 *
	 * This is a simple linear search and can take quite some time with large
	 * heaps.
	 *
	 * Params:
	 *     item = The item to find in the heap.
	 *
	 * Returns:
	 *     true if the item is found on the heap, false if not.
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
	 * Clears the heap.
	 *
	 * This method reallocates the memory used by the heap to the minimum size
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

		this._end           = this._data - 1;
		this._count         = 0;
		this._stateIsSorted = false;
	}

	/**
	 * Sift child items up through the heap if they are greater than their
	 * parents.
	 *
	 * Params:
	 *     childIndex = The index of the item to sift up. The index must
	 *     contain a child item.
	 */
	private void siftUp(size_t childIndex)
	{
		T parent;
		T child;
		size_t parentIndex;

		if (childIndex > 0)
		{
			if (childIndex > 2)
			{
				if (childIndex % 2 == 0)
				{
					parentIndex = (childIndex - 2) / 2;
				}
				else
				{
					parentIndex = (childIndex - 1) / 2;
				}
			}
			else
			{
				parentIndex = 0;
			}

			parent = *(this._data + parentIndex);
			child  = *(this._data + childIndex);

			if (this.greaterFirst(child, parent))
			{
				*(this._data + parentIndex) = child;
				*(this._data + childIndex)  = parent;

				if (parentIndex > 0)
				{
					this.siftUp(parentIndex);
				}
			}
		}
	}

	/**
	 * Sift parent items down through the heap if they are lesser than their
	 * children.
	 *
	 * Params:
	 *     parentIndex = The index of the item to sift down. The index must
	 *     contain a parent item.
	 */
	private void siftDown(size_t parentIndex)
	{
		T parent;
		T child1;
		T child2;
		size_t child1Index;
		size_t child2Index;

		child1Index = (2 * parentIndex) + 1;
		child2Index = (2 * parentIndex) + 2;

		// The parent has no children.
		if (this._count <= child1Index)
		{
			return;
		}

		// The parent has one child.
		else if (this._count == child2Index)
		{
			parent = *(this._data + parentIndex);
			child1 = *(this._data + child1Index);

			if (this.greaterFirst(child1, parent))
			{
				*(this._data + parentIndex) = child1;
				*(this._data + child1Index) = parent;

				this.siftDown(child1Index);
			}
		}
		// The parent has two children.
		else
		{
			parent = *(this._data + parentIndex);
			child1 = *(this._data + child1Index);
			child2 = *(this._data + child2Index);

			// Compare the parent against the greater child.
			if (this.greaterFirst(child1, child2))
			{
				if (this.greaterFirst(child1, parent))
				{
					*(this._data + parentIndex) = child1;
					*(this._data + child1Index) = parent;

					this.siftDown(child1Index);
				}
			}
			else
			{
				if (this.greaterFirst(child2, parent))
				{
					*(this._data + parentIndex) = child2;
					*(this._data + child2Index) = parent;

					this.siftDown(child2Index);
				}
			}
		}
	}

	/**
	 * Sort the internal data to allow it to be iterated.
	 *
	 * Even though we are tinkering with the internal state here, once sorted
	 * it's still a fully correct heap.
	 */
	private auto sort()
	{
		if (!this._stateIsSorted)
		{
			this._data[0 .. this._count].sort!(greaterFirst);
		}
	}

	/**
	 * Return a forward range to allow this heap to be used with various
	 * other algorithms.
	 *
	 * Returns:
	 *     A forward range representing this heap.
	 *
	 * Example:
	 * ---
	 * import std.algorithm;
	 *
	 * auto heap = BinaryHeap!(int, "a > b")(16);
	 *
	 * heap.insert(2);
	 * heap.insert(1);
	 * heap.insert(3);

	 * assert(heap.byValue.canFind(2));
	 * assert(heap.byValue.map!(x => x + 1).array == [4, 3, 2]);
	 * ---
	 *
	 * Warning:
	 *     When using this method to return a range there is an upfront
	 *     performance cost of sorting the internal state before the range is
	 *     returned.
	 */
	public auto byValue()
	{
		static struct Result
		{
			private T* _data;
			private T* _end;
			private size_t _count;

			public @property ref T front()
			{
				return *this._data;
			}

			public @property bool empty()
			{
				return this._data > this._end;
			}

			public void popFront()
			{
				this._data++;
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

		this.sort();

		return Result(this._data, this._end, this._count);
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
	 * auto heap = BinaryHeap!(int, "a < b")(16);
	 * heap.insert(2);
	 * heap.insert(1);
	 * heap.insert(3);
	 *
	 * foreach (value; heap)
	 * {
	 * 	writefln("%s", value);
	 * }
	 * ---
	 */
	public int opApply(scope int delegate(ref T) nothrow @nogc dg)
	{
		int result;
		this.sort();

		for (T* pointer = this._data; pointer <= this._end; pointer++)
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
	 * auto heap = BinaryHeap!(int, "a < b")(16);
	 * heap.insert(2);
	 * heap.insert(1);
	 * heap.insert(3);
	 *
	 * foreach (index, value; heap)
	 * {
	 * 	writefln("%s: %s", index, value);
	 * }
	 * ---
	 */
	public int opApply(scope int delegate(ref size_t, ref T) nothrow @nogc dg)
	{
		int result;
		size_t index;
		this.sort();

		for (T* pointer = this._data; pointer <= this._end; index++, pointer++)
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
	auto heap = BinaryHeap!(int, "a > b")(8);
	heap.insert(1);
	heap.insert(3);
	heap.insert(2);

	assert(!heap.empty);
	assert(heap.count == 3);
	assert(heap.contains(2));

	assert(heap.peek() == 3);
	assert(heap.extract() == 3);
	assert(heap.extract() == 2);

	heap.clear();

	assert(!heap.contains(3));
	assert(heap.empty);
	assert(heap.count == 0);
}

// Test reference counting.

unittest
{
	auto foo(T)(T heap)
	{
		assert(*heap._refCount == 2);
	}

	auto bar(T)(ref T heap)
	{
		assert(*heap._refCount == 1);
	}

	auto baz(T)(T heap)
	{
		assert(*heap._refCount == 1);
		return heap;
	}

	auto qux()
	{
		return BinaryHeap!(string, "a > b")(1);
	}

	auto heap = BinaryHeap!(string, "a > b")(16);

	assert(*heap._refCount == 1);

	foo(heap);
	assert(*heap._refCount == 1);

	bar(heap);
	assert(*heap._refCount == 1);

	heap = baz(BinaryHeap!(string, "a > b")(1));
	assert(*heap._refCount == 1);

	heap = qux();
	assert(*heap._refCount == 1);
}

// Test big datasets.

unittest
{
	import std.algorithm;

	auto heap = BinaryHeap!(int, (int a, int b) => a > b)(8_192);

	assert(heap.empty);
	assert(heap.count == 0);
	assert(heap.capacity == 8_192);

	int limit = 1_000_000;

	for (int x = 1; x <= limit ; x++)
	{
		heap.insert(x);
		assert(heap.peek() == x);
		assert(heap.count == x);
	}

	assert(heap.peek() == limit);
	assert(heap.count == limit);
	assert(heap.contains(1));
	assert(heap.contains(limit));
	assert(heap.byValue.canFind(1));
	assert(heap.byValue.canFind(limit));
	assert(heap.byValue.length == limit);
	assert(!heap.empty);
	assert(heap.capacity == 1_048_576);

	for (int x = limit; x >= 1 ; x--)
	{
		assert(heap.count == x);
		assert(heap.peek() == x);
		assert(heap.extract() == x);
	}

	assert(heap.empty);
	assert(heap.capacity == 8_192);

	for (int x = 1; x <= limit ; x++)
	{
		heap.insert(x);
		assert(heap.peek() == x);
		assert(heap.count == x);
	}

	heap.clear();

	assert(heap.empty);
	assert(heap.count == 0);
	assert(!heap.contains(1));
	assert(!heap.contains(limit));
	assert(!heap.byValue.canFind(1));
	assert(!heap.byValue.canFind(limit));
	assert(heap.byValue.length == 0);
	assert(heap.capacity == 8_192);
}

// Test the memory layout.

unittest
{
	auto heap = BinaryHeap!(int, delegate(int a, int b){return a > b;})(4);

	assert(heap.empty);
	assert(heap.count == 0);
	assert(heap.capacity == 4);
	assert(heap._data[0 .. heap.capacity] == [0, 0, 0, 0]);

	heap.insert(3);
	assert(heap._data[0 .. heap.capacity] == [3, 0, 0, 0]);

	heap.insert(2);
	assert(heap._data[0 .. heap.capacity] == [3, 2, 0, 0]);

	heap.insert(5);
	assert(heap._data[0 .. heap.capacity] == [5, 2, 3, 0]);

	heap.insert(4);
	assert(heap._data[0 .. heap.capacity] == [5, 4, 3, 2]);

	heap.insert(1);
	assert(heap.capacity == 8);
	assert(heap._data[0 .. heap.capacity] == [5, 4, 3, 2, 1, 0, 0, 0]);

	heap.insert(6);
	assert(heap._data[0 .. heap.capacity] == [6, 4, 5, 2, 1, 3, 0, 0]);

	heap.insert(7);
	assert(heap._data[0 .. heap.capacity] == [7, 4, 6, 2, 1, 3, 5, 0]);

	heap.insert(8);
	assert(heap._data[0 .. heap.capacity] == [8, 7, 6, 4, 1, 3, 5, 2]);

	assert(heap.extract() == 8);
	assert(heap._data[0 .. heap.capacity] == [7, 4, 6, 2, 1, 3, 5, 0]);

	assert(heap.extract() == 7);
	assert(heap._data[0 .. heap.capacity] == [6, 4, 5, 2, 1, 3, 0, 0]);

	assert(heap.extract() == 6);
	assert(heap._data[0 .. heap.capacity] == [5, 4, 3, 2, 1, 0, 0, 0]);

	assert(heap.extract() == 5);
	assert(heap.capacity == 4);
	assert(heap._data[0 .. heap.capacity] == [4, 2, 3, 1]);

	assert(heap.extract() == 4);
	assert(heap._data[0 .. heap.capacity] == [3, 2, 1, 0]);

	assert(heap.extract() == 3);
	assert(heap._data[0 .. heap.capacity] == [2, 1, 0, 0]);

	assert(heap.extract() == 2);
	assert(heap._data[0 .. heap.capacity] == [1, 0, 0, 0]);

	assert(heap.extract() == 1);
	assert(heap._data[0 .. heap.capacity] == [0, 0, 0, 0]);

	assert(heap.empty);
	assert(heap.count == 0);
}

// Test storing objects.

unittest
{
	class Person
	{
		public int priority;
		public string name;

		public this(int priority, string name)
		{
			this.priority = priority;
			this.name     = name;
		}
	}

	auto priorityQueue = BinaryHeap!(Person, "a.priority > b.priority")(1);
	auto foo           = new Person(1, "Foo");

	priorityQueue.insert(foo);
	priorityQueue.insert(new Person(4, "Bar"));
	priorityQueue.insert(new Person(2, "Baz"));

	assert(priorityQueue.contains(foo));
	assert(!priorityQueue.contains(new Person(1, "Foo")));
	assert(priorityQueue.extract().name == "Bar");

	priorityQueue.clear();
	assert(priorityQueue.empty);
}

// Test storing structs.

unittest
{
	struct Foo
	{
		public int foo;
	}

	auto heap = BinaryHeap!(Foo, "a.foo > b.foo")(16);
	auto foo  = Foo(1);

	heap.insert(foo);

	assert(heap.contains(foo));
	assert(!heap.contains(Foo(2)));
	assert(heap.extract().foo == 1);
}

// Test the range interface.

unittest
{
	import std.algorithm;

	int limit = 1_000;

	auto heap = BinaryHeap!(int, "a > b")(16);

	for (int x = 1; x <= limit ; x++)
	{
		heap.insert(x);
	}

	assert(heap.byValue.canFind(500));
	assert(heap.byValue.take(5).array == [1000, 999, 998, 997, 996]);
	assert(heap.byValue.save.take(5).array == [1000, 999, 998, 997, 996]);

	for (int x = limit; x >= 1 ; x--)
	{
		assert(heap.extract() == x);
	}
}

// Test iteration.

unittest
{
	auto heap = BinaryHeap!(int, "a < b")(16);
	heap.insert(4);
	heap.insert(1);
	heap.insert(3);
	heap.insert(2);

	size_t counter;
	auto data  = [1, 2, 3, 4];

	counter = 0;
	foreach (value; heap)
	{
		assert(value == data[counter++]);
	}

	counter = 0;
	foreach (index, value; heap)
	{
		assert(index == counter);
		assert(value == data[counter++]);
	}
}

