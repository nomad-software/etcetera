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
import etcetera.encoding.tobytes;

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
public size_t hash(T)(T value, size_t seed = 0) pure nothrow @nogc
{
	auto buffer = value.toBytes();
	return bytesHash(buffer.ptr, buffer.length, seed);
}
