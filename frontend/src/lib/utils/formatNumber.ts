const formatter = new Intl.NumberFormat('de-DE', { maximumFractionDigits: 20 });

export function formatNumber(value: number): string {
	return formatter.format(value);
}
