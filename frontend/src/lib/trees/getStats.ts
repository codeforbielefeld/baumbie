export interface SpeciesStats {
	totalTrees: number;
	distinctSpecies: number;
}

export function getSpeciesStats(data: Record<string, number>): SpeciesStats {
	return {
		totalTrees: Object.values(data).reduce((total, count) => total + count, 0),
		distinctSpecies: Object.keys(data).length
	};
}

export function getSpeciesShare(count: number, totalCount: number): number {
	if (totalCount <= 0) return 0;
	return Math.round((count / totalCount) * 1000) / 10;
}