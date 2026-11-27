import { describe, expect, it } from 'vitest';
import { formatNumber } from './formatNumber';

describe('formatNumber', () => {
	it.each([
		[0, '0'],
		[999, '999'],
		[1000, '1.000'],
		[1234567, '1.234.567'],
		[-1234, '-1.234'],
		[1234.56789, '1.234,56789']
	])('formats %s as %s', (value, expected) => {
		expect(formatNumber(value)).toBe(expected);
	});
});
