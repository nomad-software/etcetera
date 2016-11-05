/**
 * Encoding module.
 *
 * License:
 *     MIT. See LICENSE for full details.
 */
module etcetera.encoding.hash;

/**
 * Imports.
 */
import core.internal.hash;
import etcetera.encoding.tobytes;
import std.traits;

/**
 * Return a hash of any value.
 *
 * Params:
 *     value = The value to hash.
 *     seed = An optional seed for the hash.
 *
 * Returns:
 *     A numeric hash.
 */
public size_t hash(T)(T value, size_t seed = 0) nothrow @nogc
if (isNumeric!(T) || isBoolean!(T) || isSomeString!(T) || is(T == struct) || is(T == union) || is(T == class))
{
	auto buffer = value.toBytes();
	return bytesHash(buffer.ptr, buffer.length, seed);
}

///
unittest
{
	assert(hash(1337) == 3412859167);
	assert(hash("foo") == 4138058784);
}
