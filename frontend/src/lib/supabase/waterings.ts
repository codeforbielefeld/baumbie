import { supabase } from './client';
import type { Watering, WateringInput } from '$types/watering';


/**
 * Fügt einen neuen Gießvorgang in die Tabelle `waterings` ein.
 */
export async function createWatering(input: WateringInput): Promise<void> {
	const { error } = await supabase.from('waterings').insert({
		tree_uuid: input.tree_uuid,
		amount_liters: input.amount_liters,
		watered_at: input.watered_at,
		user_uuid: input.user_uuid ?? null
	});

	if (error) {
		throw new Error(`Supabase insert failed: ${error.message}`);
	}
}

export async function getWateringsForTree(tree_uuid: string): Promise<Watering[]> {
	const { data, error } = await supabase
		.from('waterings')
		.select('uuid, watered_at, amount_liters, user_uuid, created_at')
		.eq('tree_uuid', tree_uuid)
		.order('created_at', { ascending: false });

	if (error) {
		throw new Error(`Fehler beim Abrufen der Gießungen: ${error.message}`);
	}

	return data ?? [];
}

export async function loadWateringsForTree(tree_uuid: string): Promise<{ data: Watering[]; error: string | null }> {
	try {
		const waterings = await getWateringsForTree(tree_uuid);
		return { data: waterings, error: null };
	} catch (err) {
		console.error('Fehler beim Abrufen der Gießungen:', err);
		return { data: [], error: 'Fehler beim Laden der Gießungen.' };
	}
}

export async function getWateringsForUser(user_uuid: string): Promise<Watering[]> {
	const { data, error } = await supabase
		.from('waterings')
		.select('uuid, watered_at, amount_liters, user_uuid, created_at, tree_uuid')
		.eq('user_uuid', user_uuid)
		.order('created_at', { ascending: false });

	if (error) {
		throw new Error(`Fehler beim Abrufen der Gießungen für User: ${error.message}`);
	}

	return data ?? [];
}



export async function deleteWatering(uuid: string): Promise<void> {
	const { error } = await supabase.from('waterings').delete().eq('uuid', uuid);

	if (error) {
		throw new Error(`Fehler beim Löschen: ${error.message}`);
	}
}


