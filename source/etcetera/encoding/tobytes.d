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
public ubyte[] toBytes(T)(ref T value) pure nothrow @nogc if (isNumeric!(T))
{
	return cast(ubyte[]) (&value)[0 .. 1];
}

unittest
{
	import std.random;

	byte foo        = random!(byte);
	ubyte[1] result = [
		cast(ubyte) foo & 0x00FF,
	];
	assert(toBytes(foo) == result);
}

unittest
{
	import std.random;

	short foo       = random!(short);
	ubyte[2] result = [
		cast(ubyte) foo & 0x00FF,
		cast(ubyte) (foo >> 8) & 0xFF,
	];
	assert(toBytes(foo) == result);
}

unittest
{
	import std.random;

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
	import std.random;

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
	import std.random;

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
	import std.random;

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

version(unittest)
{
	import std.random;

	/**
	 * Convenience function for generating random numbers.
	 *
	 * Returns:
	 *     A random number within the correct range for the specified type.
	 */
	private T random(T)() if (isIntegral!(T))
	{
		auto gen = Random(unpredictableSeed);
		return uniform!(T)(gen);
	}

	// Ditto
	private T random(T)() if (isFloatingPoint!(T))
	{
		auto gen = Random(unpredictableSeed);
		return uniform(0.0, 1.0, gen);
	}
}
