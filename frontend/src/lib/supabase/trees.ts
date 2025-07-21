import { supabase } from './client';


/**
 * Holt den deutschen Baumtyp eines Baumes anhand seiner UUID.
 */
export async function fetchSpecies(tree_uuid: string): Promise<string | null> {
	const { data, error } = await supabase
		.from('trees')
		.select('tree_type_german')
		.eq('uuid', tree_uuid)
		.single();

	if (error) {
		console.error('Fehler beim Laden des Baumtyps:', error.message);
		return null;
	}

	return data?.tree_type_german ?? null;
}

/**
 * Holt die Baumarten für eine Liste von Tree-UUIDs und gibt eine Map zurück.
 * 
 * Diese Funktion wird aktuell nicht verwendet, kann aber nützlich sein,
 * z.B. wenn wir die Baumart als Prop an Komponenten wie `WateringHistory`
 * oder `FlyToTreeButton` durchreichen möchten. Daher bewusst noch nicht entfernt.
 */
export async function loadSpeciesMap(treeIds: string[]): Promise<Map<string, string>> {
	const speciesMap = new Map<string, string>();

	await Promise.all(
		treeIds.map(async (treeId) => {
			if (speciesMap.has(treeId)) return;
			const species = await fetchSpecies(treeId);
			speciesMap.set(treeId, species ?? 'Baum');
		})
	);

	return speciesMap;
}

export async function getTreeSpeciesDescription(treeTypeBotanic: string) {
	const field = Math.random() < 0.5 ? 'description_emotional' : 'description_neutral';


	const { data, error } = await supabase
		.from('tree_species')
		.select(field)
		.eq('tree_type_botanic', treeTypeBotanic)
		.maybeSingle();

	if (error) {
		console.error('Failed to load species description:', error.message);
		return null;
	}

	return (data as Record<string, string | null>)?.[field] ?? null;
}

/**
 * Holt alle Baumdaten für eine bestimmte UUID aus der trees-Tabelle.
 */
export async function getTreeById(treeId: string) {
	const { data, error } = await supabase
		.from('trees')
		.select()
		.eq('uuid', treeId)
		.maybeSingle();

	if (error) {
		console.error('Failed to load tree:', error.message);
		return null;
	}

	return data;
}