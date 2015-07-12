/**
 * Meta module.
 *
 * License:
 *     MIT. See LICENSE for full details.
 */
module etcetera.meta.foreachaggregate;

/**
 * Template defining a delegate suitable to be used as a ForeachAggregate.
 *
 * Params:
 *     T = The type of the foreach aggregate.
 *
 * See_Also:
 *    $(LINK http://dlang.org/statement.html#ForeachStatement)
 *    $(LINK http://ddili.org/ders/d.en/foreach_opapply.html)
 */
public template ForeachAggregate(T)
{
	alias ForeachAggregate = int delegate(ref T);
}

///
unittest
{
	class Foo
	{
		private string[] _data = ["foo", "bar", "baz", "qux"];

		public int opApply(ForeachAggregate!(string) dg)
		{
			int result;

			for (int x = 0; x < this._data.length; x++)
			{
				result = dg(this._data[x]);

				if (result)
				{
					break;
				}
			}

			return result;
		}
	}

	auto foo = new Foo();

	foreach (string value; foo)
	{
		// ...
	}
}
