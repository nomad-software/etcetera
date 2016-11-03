/**
 * Encoding module.
 *
 * License:
 *     MIT. See LICENSE for full details.
 */
module etcetera.encoding.tobytes;

/**
 * Imports.
 */
import std.traits;

/**
 * Encode any value to an array of bytes.
 *
 * Params:
 *     value = The value to encode.
 *
 * Returns:
 *     An array of bytes.
 */
public ubyte[] toBytes(T)(ref T value) nothrow @nogc if (isNumeric!(T) || isBoolean!(T) || is(T == struct) || is(T == union))
{
	return cast(ubyte[]) (&value)[0 .. 1];
}

unittest
{
	byte foo        = random!(byte);
	ubyte[1] result = [
		cast(ubyte) foo & 0x00FF,
	];
	assert(toBytes(foo) == result);
}

unittest
{
	short foo       = random!(short);
	ubyte[2] result = [
		cast(ubyte) foo & 0x00FF,
		cast(ubyte) (foo >> 8) & 0xFF,
	];
	assert(toBytes(foo) == result);
}

unittest
{
	int foo         = random!(int);
	ubyte[4] result = [
		cast(ubyte) foo & 0x00FF,
		cast(ubyte) (foo >> 8) & 0xFF,
		cast(ubyte) (foo >> 16) & 0xFF,
		cast(ubyte) (foo >> 24) & 0xFF,
	];
	assert(toBytes(foo) == result);
}

unittest
{
	long foo        = random!(long);
	ubyte[8] result = [
		cast(ubyte) foo & 0x00FF,
		cast(ubyte) (foo >> 8) & 0xFF,
		cast(ubyte) (foo >> 16) & 0xFF,
		cast(ubyte) (foo >> 24) & 0xFF,
		cast(ubyte) (foo >> 32) & 0xFF,
		cast(ubyte) (foo >> 40) & 0xFF,
		cast(ubyte) (foo >> 48) & 0xFF,
		cast(ubyte) (foo >> 56) & 0xFF,
	];
	assert(toBytes(foo) == result);
}

unittest
{
	float foo       = random!(float);
	int repr        = *(cast(int*)(&foo));
	ubyte[4] result = [
		cast(ubyte) repr & 0x00FF,
		cast(ubyte) (repr >> 8) & 0xFF,
		cast(ubyte) (repr >> 16) & 0xFF,
		cast(ubyte) (repr >> 24) & 0xFF,
	];
	assert(toBytes(foo) == result);
}

unittest
{
	double foo      = random!(double);
	long repr       = *(cast(long*)(&foo));
	ubyte[8] result = [
		cast(ubyte) repr & 0x00FF,
		cast(ubyte) (repr >> 8) & 0xFF,
		cast(ubyte) (repr >> 16) & 0xFF,
		cast(ubyte) (repr >> 24) & 0xFF,
		cast(ubyte) (repr >> 32) & 0xFF,
		cast(ubyte) (repr >> 40) & 0xFF,
		cast(ubyte) (repr >> 48) & 0xFF,
		cast(ubyte) (repr >> 56) & 0xFF,
	];
	assert(toBytes(foo) == result);
}

unittest
{
	import std.random;

	byte foo        = random!(bool);
	ubyte[1] result = [
		cast(ubyte) foo & 0x00FF,
	];
	assert(toBytes(foo) == result);
}

unittest
{
	struct Foo
	{
		byte  foo;
		short bar;
		int   baz;
		long  qux;
	}

	auto foo = Foo(0x01, 0x0202, 0x03030303, 0x0404040404040404);
	assert(toBytes(foo) == [1, 0, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 4, 4, 4, 4]);
}

unittest
{
	union Foo
	{
		long  qux;
		int   baz;
		short bar;
		byte  foo;
	}

	auto foo = Foo(0x0102030304040404);
	assert(toBytes(foo) == [4, 4, 4, 4, 3, 3, 2, 1]);
}

// Ditto
public ubyte[] toBytes(T)(ref T value) nothrow @nogc if (isSomeString!(T))
{
	return cast(ubyte[]) value;
}

unittest
{
	string foo = "England";
	assert(toBytes(foo) == [69, 110, 103, 108, 97, 110, 100]);
}

unittest
{
	wstring foo = "Росси́я"w;
	assert(toBytes(foo) == [32, 4, 62, 4, 65, 4, 65, 4, 56, 4, 1, 3, 79, 4]);
}

unittest
{
	dstring foo = "中华人民共和国"d;
	assert(toBytes(foo) == [45, 78, 0, 0, 78, 83, 0, 0, 186, 78, 0, 0, 17, 108, 0, 0, 113, 81, 0, 0, 140, 84, 0, 0, 253, 86, 0, 0]);
}

// Ditto
public ubyte[] toBytes(T)(ref T value) nothrow @nogc if (is(T == class))
{
	return *(cast(ubyte[__traits(classInstanceSize, T)]*)(value));
}

unittest
{
	class Foo
	{
		byte  foo;
		short bar;
		int   baz;
		long  qux;

		this(byte foo, short bar, int baz, long qux)
		{
			this.foo = foo;
			this.bar = bar;
			this.baz = baz;
			this.qux = qux;
		}
	}

	auto foo = new Foo(1, 2, 3, 4);
	auto bar = foo;

	assert(toBytes(foo) == toBytes(bar));
}

version(unittest)
{
	import std.random;

	/**
	 * Convenience function for generating random values of a specific type.
	 *
	 * Returns:
	 *     A random value range for the specified type.
	 */
	private T random(T)() if (isIntegral!(T))
	{
		return uniform!(T);
	}

	// Ditto
	private T random(T)() if (isFloatingPoint!(T))
	{
		return uniform(0.0, 1.0);
	}

	// Ditto
	private bool random(T : bool)()
	{
		return cast(bool) (random!(byte) & 1);
	}
}
