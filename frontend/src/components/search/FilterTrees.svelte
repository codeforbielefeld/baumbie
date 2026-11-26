<script lang="ts">
//to do: animation weg, wenn man geklickt

	import { Button, Searchfield } from '$components/ui';
	import { selectedTreeFilters, loadTopSpecies, getSpeciesStats } from '$lib/trees';
	import { formatNumber } from '$lib/utils/formatNumber';
	import type { TopSpecies } from '$lib/trees';
	import type { SpeciesStats } from '$lib/trees';
	import { onMount } from 'svelte';
	import { Notice } from '$components/ui';

	let topSpecies: TopSpecies[] = $state([]);
	let speciesStats: SpeciesStats = $state({ totalTrees: 0, distinctSpecies: 0 });
	let searchQuery = $state('');
	//let sortKey: 'label' | 'count' = $state('count');
	let sortKey = $state('count');
	let sortDirection: 'asc' | 'desc' = $state('desc');
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

	function selectFirstSearchResult(event: KeyboardEvent) {
		const firstSpecies = visibleSpecies[0];
		if (!searchQuery.trim() || !firstSpecies) return;

		event.preventDefault();
		if (!current.includes(firstSpecies.label)) {
			toggleSpecies(firstSpecies.label);
		}
	}

	let current = $derived($selectedTreeFilters.species ?? []);
	let visibleSpecies = $derived(
		topSpecies
			.filter((species) =>
				species.label.toLocaleLowerCase().includes(searchQuery.trim().toLocaleLowerCase())
			)
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

	// onMount(() => {
	// 	const interval = window.setInterval(() => {
	// 		if (hasInteracted || visibleSpecies.length === 0) return;

	// 		const numberOfCandidates = Math.min(5, visibleSpecies.length);
	// 		let nextIndex = Math.floor(Math.random() * numberOfCandidates);
	// 		if (numberOfCandidates > 1 && nextIndex === animatedSpeciesIndex) {
	// 			nextIndex = (nextIndex + 1) % numberOfCandidates;
	// 		}
	// 		animatedSpeciesIndex = nextIndex;
	// 	}, 1200);

	// 	return () => window.clearInterval(interval);
	// });

</script>

<div class="mx-auto flex h-full min-h-0 w-full p-1 max-w-screen-lg flex-col gap-7 pt-2">
	<!-- Beschreibung -->
	<div class="shrink-0 space-y-2 text-2xl text-gray-800 leading-relaxed">
		<Notice tone="info" fontSize="base">
			Es gibt <strong>{formatNumber(speciesStats.totalTrees)} Stadtbäume</strong> in Bielefeld, darunter
			<strong>{formatNumber(speciesStats.distinctSpecies)} verschiedene Arten</strong>.<br>
			<br>
			<span class="inline-flex items-start gap-1.5">
				<span>Tippe in der Tabelle auf die Baumarten, die du in der Karte sehen willst. Oder such nach einer Baumart.</span>
			</span>
		</Notice>
	</div>
	
	<div class="shrink-0">
		<Searchfield
			items={topSpecies}
			labelKey="label"
			valueKey="label"
			placeholder="Baumart suchen ..."
			bind:value={searchQuery}
			showSuggestions={false}
			onFocus={stopTableAnimation}
			onInput={handleSearchInput}
			onEnter={selectFirstSearchResult}
		/>
	</div>


	<div class="flex min-h-0 flex-1 flex-col overflow-hidden rounded-lg border border-gray-200 bg-white">
		<div class="grid shrink-0 grid-cols-[minmax(0,1fr)_minmax(10rem,max-content)] overflow-hidden [scrollbar-gutter:stable] border-b
				border-gray-200 bg-gray-100
				text-left text-sm font-semibold text-gray-700">
			<!-- <button
				type="button"
				class="flex items-center justify-between px-4 py-3 text-left hover:bg-gray-200"
				onclick={() => changeSort('label')}
			> -->
				<div class="flex items-center justify-between px-4 py-3 text-left">
					Baumart
				</div>
				<!-- {#if sortKey === 'label'}<span aria-hidden="true">{sortDirection === 'asc' ? '↑' : '↓'}</span>{/if} -->
			<!-- </button> -->
			<button
				type="button"
				class="flex items-center justify-end gap-2 whitespace-nowrap border-l border-gray-200 px-4 py-3 text-right"
				onclick={() => changeSort('count')}
			>
				Häufigkeit
				{#if sortKey === 'count'}
					<svg
						aria-hidden="true"
						class={`h-4 w-4 shrink-0 ${sortDirection === 'desc' ? 'rotate-180' : ''}`}
						viewBox="0 0 24 24"
						fill="none"
						stroke="currentColor"
						stroke-width="2.5"
						stroke-linecap="round"
						stroke-linejoin="round"
					>
						<path d="M12 21V3M6 9l6-6 6 6" />
					</svg>
				{/if}
			</button>
		</div>

		<div class="min-h-0
				flex-1
				divide-y divide-gray-100
				overflow-y-auto [scrollbar-gutter:stable]">
			{#each visibleSpecies as species, index (species.label)}
				<Button
					variant="unstyled"
					ariaPressed={current.includes(species.label)}
					className={`grid h-12 w-full grid-cols-[minmax(0,1fr)_minmax(10rem,max-content)] text-left transition ${current.includes(species.label) ? 'bg-green-300 hover:!bg-green-300' : (searchQuery.trim() && index === 0) || animatedSpeciesIndex === index ? 'bg-green-100' : 'bg-white hover:bg-green-100'}`}
					onMouseEnter={stopTableAnimation}
					onClick={() => toggleSpecies(species.label)}
				>
					<span class="flex min-w-0 items-center gap-2 px-4 py-3 font-medium text-gray-900">
						<svg aria-hidden="true" class="h-4 w-4 shrink-0" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round">
							<path d="M5 12h14" />
							{#if !current.includes(species.label)}
								<path d="M12 5v14" />
							{/if}
						</svg>
						<span class="truncate">{species.label}</span>
					</span>
					<span class="whitespace-nowrap border-l border-gray-100 px-4 py-3 text-right text-gray-700">
						{formatNumber(species.count)}
						({ species.share >= 0.1 ?
							species.share.toLocaleString(
							'de-DE', { minimumFractionDigits: 1, maximumFractionDigits: 1 }
						) : '<\u20090.1' }&thinsp;%)
					</span>
				</Button>
			{:else}
				<p class="px-4 py-5 text-sm text-gray-500">Keine Baumart gefunden</p>
			{/each}
		</div>

	</div>
</div>
