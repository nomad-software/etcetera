/**
 * String module.
 *
 * License:
 *     MIT. See LICENSE for full details.
 */
module etcetera.string.unquote;

/**
 * Imports.
 */
import std.algorithm;
import std.traits;
import std.typecons;

/**
 * Remove single, double or back quotes from around a passed string. Strings 
 * will only be unquoted if they start and end with matching quotes.
 *
 * Params:
 *     text = The string to remove quotes from.
 *
 * Returns:
 *     If the above rules apply the unquoted string, otherwise it's returned 
 *     unchanged.
 */
public T unquote(T)(T text) @safe pure if (isSomeString!(T))
{
	auto quotes = tuple('"', '\'', '`');

	if (text.startsWith(quotes.expand) == text.endsWith(quotes.expand))
	{
		return text.strip!(a => a.among(quotes.expand) > 0);
	}
	else
	{
		return text;
	}
}

///
unittest
{
	assert(unquote(`"Lorem ipsum dolor sit amet."`) == "Lorem ipsum dolor sit amet.");
	assert(unquote("'Lorem ipsum dolor sit amet.'") == "Lorem ipsum dolor sit amet.");
	assert(unquote("`Lorem ipsum dolor sit amet.`") == "Lorem ipsum dolor sit amet.");
}

unittest
{
	auto edgeCases = [
		["naked", "naked"],

		[`quotes "in the" middle`, `quotes "in the" middle`],
		["quotes 'in the' middle", "quotes 'in the' middle"],
		["quotes `in the` middle", "quotes `in the` middle"],

		[`"missmatched'`, `"missmatched'`],
		["'missmatched`", "'missmatched`"],

		[`only one"`, `only one"`],
		[`"only one`, `"only one`],
		["only one'", "only one'"],
		["'only one", "'only one"],
		["only one`", "only one`"],
		["`only one", "`only one"],
	];

	foreach (test; edgeCases)
	{
		assert(unquote(test[0]) == test[1]);
	}
}

unittest
{
	wstring[][] utf16 = [
		[`"Lorem ipsum dolor sit amet."`w, "Lorem ipsum dolor sit amet."w],
		["'Lorem ipsum dolor sit amet.'"w, "Lorem ipsum dolor sit amet."w],
		["`Lorem ipsum dolor sit amet.`"w, "Lorem ipsum dolor sit amet."w],
	];

	foreach (test; utf16)
	{
		assert(unquote(test[0]) == test[1]);
	}
}

unittest
{
	dstring[][] utf32 = [
		[`"Lorem ipsum dolor sit amet."`d, "Lorem ipsum dolor sit amet."d],
		["'Lorem ipsum dolor sit amet.'"d, "Lorem ipsum dolor sit amet."d],
		["`Lorem ipsum dolor sit amet.`"d, "Lorem ipsum dolor sit amet."d],
	];

	foreach (test; utf32)
	{
		assert(unquote(test[0]) == test[1]);
	}
}
