/**
 * Numeric module.
 *
 * License:
 *     MIT. See LICENSE for full details.
 */
module etcetera.numeric.rational;

/**
 * Imports.
 */
import std.stdio;
import std.string;

/**
 * A struct representing a rational number.
 */
struct Rational
{
	public immutable(long) numerator;
	public immutable(long) denominator;

	/**
	 * Construct and if possible simplify a rational number.
	 *
	 * Params:
	 *     n = The numerator.
	 *     d = The denominator.
	 */
	public this(long n, long d) nothrow
	{
		auto div         = this.greatestCommonDivisor(n, d);
		this.numerator   = n / div;
		this.denominator = d / div;
	}

	/**
	 * Overload various operators.
	 *
	 * Returns:
	 *     The result from various operations.
	 */
	public Rational opBinary(string op)(Rational other) const nothrow
	{
		static if (op == "+" || op == "-")
		{
			auto lcm = this.leastCommonMultiple(this.denominator, other.denominator);

			static if (op == "+")
			{
				auto numerator = (this.numerator * (lcm / this.denominator)) + (other.numerator * (lcm / other.denominator));
			}
			else static if (op == "-")
			{
				auto numerator = (this.numerator * (lcm / this.denominator)) - (other.numerator * (lcm / other.denominator));
			}

			return this.reduce(numerator, lcm);
		}
		else static if (op == "*")
		{
			return this.reduce(this.numerator * other.numerator, this.denominator * other.denominator);
		}
		else static if (op == "/")
		{
			return this.reduce(this.numerator * other.denominator, this.denominator * other.numerator);
		}
		else
		{
			static assert(0, "Operator '" ~ op ~ "' not implemented");
		}
	}

	/**
	 * Return a string representation.
	 *
	 * Returns:
	 *     The string representation.
	 */
	public string toString() const
	{
		return format("%s/%s", this.numerator, this.denominator);
	}

	/**
	 * Calculate the greatest common divisor using Euclid's algorithm.
	 *
	 * Params:
	 *     a = The first number.
	 *     b = The second number.
	 *
	 * Returns:
	 *     The greatest common divisor.
	 *
	 * See_Also:
	 *     $(LINK https://en.wikipedia.org/wiki/Euclidean_algorithm)
	 */
	private long greatestCommonDivisor(long a, long b) const nothrow
	{
		if (b == 0)
		{
			return a;
		}
		return greatestCommonDivisor(b, a % b);
	}

	/**
	 * Calculate the least common multiple.
	 *
	 * Params:
	 *     a = The first number.
	 *     b = The second number.
	 *
	 * Returns:
	 *     The least common multiple.
	 *
	 * See_Also:
	 *     $(LINK https://stackoverflow.com/q/3154454/13227)
	 */
	private long leastCommonMultiple(long a, long b) const nothrow
	{
		if (a > b)
		{
			return (a / this.greatestCommonDivisor(a, b)) * b;
		}

		return (b / this.greatestCommonDivisor(a, b)) * a;
	}

	/**
	 * Reduce a rational number into a simpler one.
	 *
	 * Params:
	 *     n = The numerator.
	 *     d = The denominator.
	 *
	 * Returns:
	 *     A rational number.
	 */
	private Rational reduce(long n, long d) const nothrow
	{
		auto div = this.greatestCommonDivisor(n, d);

		return Rational(n / div, d / div);
	}
}

///
unittest
{
	auto foo = Rational(1, 3);
	auto bar = Rational(1, 5);

	assert(format("%s", foo) == "1/3");
	assert(format("%s", bar) == "1/5");

	assert(foo + bar == Rational(8, 15));
	assert(foo - bar == Rational(2, 15));
	assert(foo * bar == Rational(1, 15));
	assert(foo / bar == Rational(5, 3));
}
