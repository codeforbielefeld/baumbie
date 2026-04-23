<script lang="ts">
	import { get } from 'svelte/store';
	import { mapStore, focusTreeById } from '$lib/map';
	import { selectedTreeFilters } from '$lib/trees';
	import { Button } from '$components/ui';
	import { onMount, createEventDispatcher } from 'svelte';
	import { fetchSpecies } from '$lib/supabase/trees';

	interface Props {
		treeId: string;
		label?: string | null;
	}

	let { treeId, label = null }: Props = $props();

	let species: string | null = $state(null);

	const dispatch = createEventDispatcher();

	function handleClick() {
		const map = get(mapStore);
		if (!map) return;

		const speciesFilter = get(selectedTreeFilters).species ?? [];

		// Falls die Baumart gefiltert ist → Warnung an übergeordnete Komponente senden
		if (species && speciesFilter.length > 0 && !speciesFilter.includes(species)) {
			dispatch('warning', {
				message: `${label} ist durch deinen Filter ausgeblendet und kann daher gerade nicht angesteuert werden.`
			});
			return;
		}

		// Fokus auf Baum setzen
		focusTreeById(map, treeId);
	}

	onMount(async () => {
		species = await fetchSpecies(treeId);
	});
</script>

<div class="flex items-center gap-1">
	<Button onClick={handleClick} className="gap-1 text-sm" variant="secondary">
		{label ?? species ?? 'Baum'}
		<img src="/icons/tree.svg" alt="Baum" class="w-4 h-4" />
		<span>→</span>
	</Button>
</div>
