<script lang="ts">
	// Svelte & Stores
	import { get } from 'svelte/store';

	// UI-Komponenten
	import { Button, Notice } from '$components/ui';
	import { FlyToTreeButton } from '$components/actions';

	// Bäume
	import type { TreeNearby } from '$types/tree';
	import { findNearbyTrees, selectedTreeFilters } from '$lib/trees';

	let treesNearby: TreeNearby[] = $state([]);
	let errorMessage: string | null = $state(null);

	let isFiltered = $derived(($selectedTreeFilters.species?.length ?? 0) > 0);
	let selectedSpecies = $derived($selectedTreeFilters.species ?? []);

	async function findTreesNearby() {
		treesNearby = [];
		errorMessage = null;
		let filter = get(selectedTreeFilters);

		try {
			treesNearby = await findNearbyTrees(filter.species ?? []);
			if (treesNearby.length === 0) {
				errorMessage = 'Keine Bäume in deiner Nähe gefunden.';
			}
		} catch (error) {
			errorMessage = 'Dein Standort konnte nicht ermittelt werden.';
		}
	}
</script>

<Button variant="primary" onClick={findTreesNearby}>Jetzt Bäume finden</Button>

{#if errorMessage}
	<Notice tone="warning">{errorMessage}</Notice>
{/if}

{#if isFiltered}
	<Notice tone="info">
		Hinweis: Es werden nur Bäume der ausgewählten Arten berücksichtigt.<br />
		<small>Ausgewählt: {selectedSpecies.join(', ')}</small>
	</Notice>
{/if}

{#if treesNearby.length}
	<ul class="mt-4 divide-y divide-gray-200 text-sm">
		{#each treesNearby as tree}
			<li class="flex items-center justify-between py-2">
				<span class="text-gray-600">{tree.distance.toFixed(1)} m</span>
				<FlyToTreeButton treeId={tree.id} />
			</li>
		{/each}
	</ul>
{/if}
