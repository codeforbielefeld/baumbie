export interface TopSpecies {
	label: string;
	count: number;
	share: number;
}

import { getSpeciesShare, getSpeciesStats } from './getStats';

export async function loadTopSpecies(limit = 30): Promise<TopSpecies[]> {
	const res = await fetch('/data/species-count.json');
	const data: Record<string, number> = await res.json();
	const { totalTrees } = getSpeciesStats(data);

	return Object.entries(data)
		.slice(0, limit)
		.map(([label, count]) => ({ label, count, share: getSpeciesShare(count, totalTrees) }));
}
