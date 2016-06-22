/**
 * Meta module.
 *
 * License:
 *     MIT. See LICENSE for full details.
 */
module etcetera.meta.indexedforeachaggregate;

/**
 * Template defining a delegate suitable to be used as an indexed 
 * ForeachAggregate.
 *
 * Params:
 *     T = The type of the foreach aggregate.
 *
 * See_Also:
 *    $(LINK http://dlang.org/statement.html#ForeachStatement)
 *    $(LINK http://ddili.org/ders/d.en/foreach_opapply.html)
 */
public template IndexedForeachAggregate(T)
{
	alias IndexedForeachAggregate = int delegate(ref size_t, ref T) nothrow @nogc;
}

///
unittest
{
	class Foo
	{
		private string[] _data = ["foo", "bar", "baz", "qux"];

		public int opApply(IndexedForeachAggregate!(string) dg)
		{
			int result;
			size_t index;

			for (int x = 0; x < this._data.length; index++, x++)
			{
				result = dg(index, this._data[x]);

				if (result)
				{
					break;
				}
			}

			return result;
		}
	}

	auto foo = new Foo();

	foreach (index, value; foo)
	{
		// ...
	}
}
