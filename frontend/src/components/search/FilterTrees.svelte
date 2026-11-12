<script lang="ts">
//to do: x weiter weg vom Label im Button, wenn viele Buttons,dann sollte man durch sliden können
//to do: animation weg, wenn man geklickt
//Tabelleninhalt sollte nicht moven, sondern je nach token tabelle filtern
//bei sehr wenigen: weniger als 0,1%

	import { Searchfield } from '$components/ui';
	import { selectedTreeFilters, loadTopSpecies, getSpeciesStats } from '$lib/trees';
	import type { TopSpecies } from '$lib/trees';
	import type { SpeciesStats } from '$lib/trees';
	import { onMount } from 'svelte';
	import { Notice } from '$components/ui';

	let topSpecies: TopSpecies[] = $state([]);
	let speciesStats: SpeciesStats = $state({ totalTrees: 0, distinctSpecies: 0 });
	let searchQuery = $state('');
	let sortKey: 'label' | 'count' = $state('count');
	let sortDirection: 'asc' | 'desc' = $state('desc');
	let tableElement = $state<HTMLDivElement>();
	let hasInteracted = $state(false);
	let animatedSpeciesIndex = $state<number | null>(null);

	onMount(async () => {
		topSpecies = await loadTopSpecies(Infinity);
		const res = await fetch('/data/species-count.json');
		const data: Record<string, number> = await res.json();
		speciesStats = getSpeciesStats(data);
	});

	function toggleSpecies(species: string) {
		stopTableAnimation();
		const currentSpecies = $selectedTreeFilters.species ?? [];
		const updated = currentSpecies.includes(species)
			? currentSpecies.filter((s) => s !== species)
			: [...currentSpecies, species];

		selectedTreeFilters.set({ species: updated });
	}

	function handleSearchInput(query: string) {
		stopTableAnimation();
		searchQuery = query;
		if (query.trim()) {
			sortKey = 'label';
			sortDirection = 'asc';
		}
	}

	function stopTableAnimation() {
		hasInteracted = true;
		animatedSpeciesIndex = null;
	}

	let current = $derived($selectedTreeFilters.species ?? []);
	let visibleSpecies = $derived(
		topSpecies
			.toSorted((left, right) => {
				const comparison =
					sortKey === 'label'
						? left.label.localeCompare(right.label, 'de')
						: left.count - right.count;
				return sortDirection === 'asc' ? comparison : -comparison;
			})
	);

	function changeSort(key: 'label' | 'count') {
		stopTableAnimation();
		if (sortKey === key) {
			sortDirection = sortDirection === 'asc' ? 'desc' : 'asc';
		} else {
			sortKey = key;
			sortDirection = key === 'count' ? 'desc' : 'asc';
		}
	}

	onMount(() => {
		const interval = window.setInterval(() => {
			if (hasInteracted || visibleSpecies.length === 0) return;

			const numberOfCandidates = Math.min(5, visibleSpecies.length);
			let nextIndex = Math.floor(Math.random() * numberOfCandidates);
			if (numberOfCandidates > 1 && nextIndex === animatedSpeciesIndex) {
				nextIndex = (nextIndex + 1) % numberOfCandidates;
			}
			animatedSpeciesIndex = nextIndex;
		}, 1200);

		return () => window.clearInterval(interval);
	});

	$effect(() => {
		const query = searchQuery.trim().toLocaleLowerCase();
		if (!query || !tableElement) return;

		const matchingIndex = visibleSpecies.findIndex((species) =>
			species.label.toLocaleLowerCase().includes(query)
		);
		if (matchingIndex >= 0) {
			tableElement.scrollTo({ top: matchingIndex * 48, behavior: 'smooth' });
		}
	});
</script>

<div class="w-full max-w-screen-lg mx-auto space-y-7 pt-2">
	<!-- Beschreibung -->
	<div class="space-y-2 text-lg text-gray-800 leading-relaxed">
		<Notice tone="info">
			Es gibt <strong>{speciesStats.totalTrees} Stadtbäume</strong> in Bielefeld, darunter
			<strong>{speciesStats.distinctSpecies} verschiedene Arten</strong>.<br>
			Wähle hier, welche Arten du in der Karte sehen willst.
		</Notice>
	</div>
	
	<Searchfield
		items={topSpecies}
		labelKey="label"
		valueKey="label"
		placeholder="Baumart suchen ..."
		bind:value={searchQuery}
		showSuggestions={false}
		onFocus={stopTableAnimation}
		onInput={handleSearchInput}
	/>


	<div class="overflow-hidden rounded-lg border border-gray-200 bg-white">
		<div class="grid grid-cols-[minmax(0,1fr)_minmax(10rem,max-content)] border-b
				border-gray-200 bg-gray-100
				text-left text-sm font-semibold text-gray-700">
			<button
				type="button"
				class="flex items-center justify-between px-4 py-3 text-left hover:bg-gray-200"
				onclick={() => changeSort('label')}
			>
				Baumart
				{#if sortKey === 'label'}<span aria-hidden="true">{sortDirection === 'asc' ? '↑' : '↓'}</span>{/if}
			</button>
			<button
				type="button"
				class="flex items-center justify-end gap-2 whitespace-nowrap border-l border-gray-200 px-4 py-3 text-right hover:bg-gray-200"
				onclick={() => changeSort('count')}
			>
				Häufigkeit
				{#if sortKey === 'count'}
					<span
						aria-hidden="true"
						class="inline-flex size-4 items-center justify-center text-xl font-bold leading-none"
					>
						{sortDirection === 'asc' ? '↑' : '↓'}
					</span>
				{/if}
			</button>
		</div>

		<div bind:this={tableElement} class="max-h-96 divide-y divide-gray-100 overflow-y-auto">
			{#each visibleSpecies as species (species.label)}
				<button
					type="button"
					class={`grid h-12 w-full grid-cols-[minmax(0,1fr)_minmax(10rem,max-content)] text-left transition ${current.includes(species.label) ? 'bg-green-300 hover:!bg-green-300' : animatedSpeciesIndex === visibleSpecies.indexOf(species) ? 'bg-green-100' : 'bg-white hover:bg-green-100'}`}
					onmouseenter={stopTableAnimation}
					onclick={() => toggleSpecies(species.label)}
				>
					<span class="truncate px-4 py-3 font-medium text-gray-900">{species.label}</span>
					<span class="whitespace-nowrap border-l border-gray-100 px-4 py-3 text-right text-gray-700">
						{species.count} ({species.share.toLocaleString('de-DE', { minimumFractionDigits: 1, maximumFractionDigits: 1 })} %)
					</span>
				</button>
			{:else}
				<p class="px-4 py-5 text-sm text-gray-500">Keine Baumart gefunden</p>
			{/each}
		</div>

	</div>
</div>
