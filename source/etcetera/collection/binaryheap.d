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
import core.memory;
import core.stdc.string : memset;
import std.functional;
import std.range;
import std.traits;

/**
 * A generic binary heap implementation.
 *
 * Params:
 *     T = The type stored in the heap.
 *     pred = A predicate that returns true if the first parameter is 
 *     greater than the second. This predicate defines the sorting order 
 *     between the heap items and is called during insertion and extraction.
 */
class BinaryHeap(T, alias pred) if (is(typeof(binaryFun!(pred)(T.init, T.init)) == bool))
{
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
	private immutable size_t _minSize;

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

	/**
	 * Construct a new binary heap.
	 *
	 * By default the heap is allocated enough memory for 10,000 items. If 
	 * more items are added, the heap can grow by doubling its allocation, ad 
	 * infinitum. If the items within reduce to only use half of the current 
	 * allocation the heap will half it. The heap will never shrink below the 
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
	final public this(size_t minCapacity = 10_000) nothrow
	{
		assert(minCapacity >= 1, "Heap must allow for at least one item.");

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

		this._end = this._data - 1;
	}

	/**
	 * Get the number of items stored in the heap.
	 *
	 * Returns:
	 *     The number of items stored in the heap.
	 */
	final public @property size_t count() const nothrow pure
	{
		return this._count;
	}

	/**
	 * Test if the heap is empty or not.
	 *
	 * Returns:
	 *     true if the heap is empty, false if not.
	 */
	final public @property bool empty() const nothrow pure
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
	final private @property size_t capacity() const nothrow pure
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
	final public void insert(T item) nothrow
	{
		this._end++;

		if (this._count == this.capacity)
		{
			this._size *= 2;
			this._data  = cast(T*)GC.realloc(this._data, this._size, GC.BlkAttr.NONE, typeid(T));
			this._end   = this._data + this._count;

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
	final public T peek() nothrow pure
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
	final public T extract() nothrow
	{
		assert(this._count, "Heap empty, extracting failed.");

		T extracted;

		this._count--;
		extracted = *this._data;

		*this._data = *this._end;

		if ((this._count <= (this.capacity / 2)) && ((this._size / 2) >= this._minSize))
		{
			this._size /= 2;
			this._data  = cast(T*)GC.realloc(this._data, this._size, GC.BlkAttr.NONE, typeid(T));
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
	final public void clear() nothrow
	{
		if (this._size > this._minSize)
		{
			this._size = this._minSize;
			this._data = cast(T*)GC.realloc(this._data, this._size, GC.BlkAttr.NONE, typeid(T));
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
	final private void siftUp(size_t childIndex) nothrow
	{
		static T parent;
		static T child;
		static size_t parentIndex;

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
	final private void siftDown(size_t parentIndex) nothrow
	{
		static T parent;
		static T child1;
		static T child2;
		static size_t child1Index;
		static size_t child2Index;

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
	 * Sort the internal data to allow it to be iterated more easily.
	 *
	 * Even though we are tinkering with the internal state, once sorted it's 
	 * still a fully correct heap.
	 */
	final private auto sort() nothrow pure
	{
		if (!this._stateIsSorted)
		{
			for (T* back = this._end; back > this._data; back--)
			{
				for (T* front = this._data; front < back; front++)
				{
					if (this.greaterFirst(*back, *front))
					{
						T temp = *front;
						*front = *back;
						*back  = temp;
					}
				}
			}
			this._stateIsSorted = true;
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
	 * auto heap = new BinaryHeap!(int, "a > b");
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
	final public auto byValue() nothrow pure
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
}

///
unittest
{
	auto heap = new BinaryHeap!(int, "a > b");
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

unittest
{
	auto heap = new BinaryHeap!(int, (int a, int b) => a > b);

	assert(heap.empty);
	assert(heap.count == 0);
	assert(heap.capacity == 10_000);

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
	assert(!heap.empty);
	assert(heap.capacity == 1_280_000);

	for (int x = limit; x >= 1 ; x--)
	{
		assert(heap.count == x);
		assert(heap.peek() == x);
		assert(heap.extract() == x);
	}

	assert(heap.empty);
	assert(heap.capacity == 10_000);

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
	assert(heap.capacity == 10_000);
}

unittest
{
	auto heap = new BinaryHeap!(int, delegate(int a, int b){return a > b;})(4);

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

unittest
{
	class Person
	{
		public int priority;
		public string name;

		public this(int priority, string name) nothrow
		{
			this.priority = priority;
			this.name     = name;
		}
	}

	auto priorityQueue = new BinaryHeap!(Person, "a.priority > b.priority");

	priorityQueue.insert(new Person(1, "Foo"));
	priorityQueue.insert(new Person(4, "Bar"));
	priorityQueue.insert(new Person(2, "Baz"));
	priorityQueue.insert(new Person(3, "Quxx"));

	assert(priorityQueue.extract().name == "Bar");
	assert(priorityQueue.extract().name == "Quxx");
	assert(priorityQueue.extract().name == "Baz");
	assert(priorityQueue.extract().name == "Foo");
}

unittest
{
	import std.algorithm;

	int limit = 1_000;

	auto heap = new BinaryHeap!(int, "a > b");

	for (int x = 1; x <= limit ; x++)
	{
		heap.insert(x);
	}

	assert(heap.byValue.canFind(500));
	assert(heap.byValue.take(5).array == [1000, 999, 998, 997, 996]);

	for (int x = limit; x >= 1 ; x--)
	{
		assert(heap.extract() == x);
	}
}

