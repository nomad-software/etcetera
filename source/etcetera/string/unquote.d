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
import std.traits : isSomeString;

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
public T unquote(T)(T text) @nogc @safe nothrow pure if (isSomeString!(T))
{
	if (text.length)
	{
		if ((text[0] == '"' || text[0] == '\'' || text[0] == '`') && text[0] == text[text.length - 1])
		{
			return text[1 .. $-1];
		}
	}
	return text;
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
		[`""`, ""],
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
	string[][] utf8 = [
		[`"日本語"`, "日本語"],
		["'日本語'", "日本語"],
		["`日本語`", "日本語"],
	];

	foreach (test; utf8)
	{
		assert(unquote(test[0]) == test[1]);
	}
}

unittest
{
	wstring[][] utf16 = [
		[`"日本語"`w, "日本語"w],
		["'日本語'"w, "日本語"w],
		["`日本語`"w, "日本語"w],
	];

	foreach (test; utf16)
	{
		assert(unquote(test[0]) == test[1]);
	}
}

unittest
{
	dstring[][] utf32 = [
		[`"日本語"`d, "日本語"d],
		["'日本語'"d, "日本語"d],
		["`日本語`"d, "日本語"d],
	];

	foreach (test; utf32)
	{
		assert(unquote(test[0]) == test[1]);
	}
}
