/**
 * Collections module.
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
import std.traits;

/**
 * A abstract generic binary heap implementation.
 */
abstract class BinaryHeap(T)
{
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
	private size_t _count = 0;

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
		assert(this.count > 0, "Heap empty, peeking failed.");

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
		assert(this.count > 0, "Heap empty, extracting failed.");

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

		this._end   = this._data - 1;
		this._count = 0;
	}

	/**
	 * Sift items up through the heap. This method uses the compare method for 
	 * all comparisons.
	 *
	 * Params:
	 *     position = The position of the item to sift up. The position must 
	 *     contain a child item.
	 */
	final private void siftUp(size_t position) nothrow
	{
		static T parent;
		static T child;

		if (position > 0)
		{
			size_t parentPosition;

			if (position > 2)
			{
				if (position % 2 == 0)
				{
					parentPosition = (position - 2) / 2;
				}
				else
				{
					parentPosition = (position - 1) / 2;
				}
			}
			else
			{
				parentPosition = 0;
			}

			parent = *(this._data + parentPosition);
			child  = *(this._data + position);

			if (this.compare(child, parent) > 0)
			{
				*(this._data + parentPosition) = child;
				*(this._data + position)       = parent;

				if (parentPosition > 0)
				{
					this.siftUp(parentPosition);
				}
			}
		}
	}

	/**
	 * Sift items down through the heap. This method uses the compare method for 
	 * all comparisons.
	 *
	 * Params:
	 *     position = The position of the item to sift down. The position must 
	 *     contain a parent item.
	 */
	final private void siftDown(size_t position) nothrow
	{
		static T parent;
		static T child1;
		static T child2;

		if (this._count <= (2 * position) + 1)
		{
			return;
		}
		else if (this._count == (2 * position) + 2)
		{
			parent = *(this._data + position);
			child1 = *(this._data + ((2 * position) + 1));

			if (this.compare(child1, parent) > 0)
			{
				*(this._data + position)             = child1;
				*(this._data + ((2 * position) + 1)) = parent;

				this.siftDown((2 * position) + 1);
			}
		}
		else
		{
			parent = *(this._data + position);
			child1 = *(this._data + ((2 * position) + 1));
			child2 = *(this._data + ((2 * position) + 2));

			if (this.compare(child1, child2) > 0)
			{
				if (this.compare(child1, parent))
				{
					*(this._data + position)             = child1;
					*(this._data + ((2 * position) + 1)) = parent;

					this.siftDown((2 * position) + 1);
				}
			}
			else
			{
				if (this.compare(child2, parent))
				{
					*(this._data + position)             = child2;
					*(this._data + ((2 * position) + 2)) = parent;

					this.siftDown((2 * position) + 2);
				}
			}
		}
	}

	/**
	 * This method defines the sorting order between the heap items and is 
	 * called during insertion and extraction. This method is abstract and 
	 * needs implementing in the extending type.
	 *
	 * Params:
	 *     item1  = The first item.
	 *     item2 = The second item.
	 *
	 * Returns:
	 *     An integer representing the sorting order between the two items. The 
	 *     result of the comparison is a positive integer if item1 is greater 
	 *     than item2, 0 if they are equal, negative otherwise.
	 *
	 */
	abstract public int compare(T item1, T item2) const pure nothrow;
}

///
unittest
{
	class MaxHeap : BinaryHeap!(int)
	{
		override public int compare(int item1, int item2) const pure nothrow
		{
			return item1 - item2;
		}
	}

	auto heap = new MaxHeap();
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
	class MaxHeap : BinaryHeap!(int)
	{
		override public int compare(int item1, int item2) const pure nothrow
		{
			return item1 - item2;
		}
	}

	auto heap = new MaxHeap();

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
	class MaxHeap : BinaryHeap!(byte)
	{
		final public this(size_t minCapacity = 10_000) nothrow
		{
			super(minCapacity);
		}

		override public int compare(byte item1, byte item2) const pure nothrow
		{
			return item1 - item2;
		}
	}

	auto heap = new MaxHeap(4);

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

		this(int priority, string name)
		{
			this.priority = priority;
			this.name     = name;
		}
	}

	class PriorityQueue : BinaryHeap!(Person)
	{
		override public int compare(Person item1, Person item2) const pure nothrow
		{
			return item1.priority - item2.priority;
		}
	}

	auto queue = new PriorityQueue();

	queue.insert(new Person(1, "Foo"));
	queue.insert(new Person(4, "Bar"));
	queue.insert(new Person(2, "Baz"));
	queue.insert(new Person(3, "Quxx"));

	assert(queue.extract().name == "Bar");
	assert(queue.extract().name == "Quxx");
	assert(queue.extract().name == "Baz");
	assert(queue.extract().name == "Foo");
}

