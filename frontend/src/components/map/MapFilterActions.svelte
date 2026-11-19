<script lang="ts">
	import { Button } from '$components/ui';
	import { selectedTreeFilters } from '$lib/trees';

	let current = $derived($selectedTreeFilters.species ?? []);

	function toggleSpecies(species: string) {
		const updated = current.includes(species)
			? current.filter((selectedSpecies) => selectedSpecies !== species)
			: [...current, species];

		selectedTreeFilters.set({ species: updated });
	}
</script>

<div class="fixed left-1/2 top-4 z-[1001] flex w-[90vw] max-w-[90vw] -translate-x-1/2 flex-wrap items-center justify-center gap-2">
	{#if current.length > 0}
		<Button
			variant="secondary"
			onClick={() => selectedTreeFilters.set({ species: [] })}
			className="!border-gray-300 !bg-white/95 !px-3 !py-1 !text-sm !text-gray-600 shadow-md hover:!bg-gray-100"
		>
			Alle Baumarten anzeigen
		</Button>
	{/if}

	{#each current as species (species)}
		<Button
			variant="secondary"
			className="gap-2 !border-green-600 !bg-green-300 !px-3 !py-1 !text-sm !text-green-900 shadow-md hover:!bg-green-300"
			onClick={() => toggleSpecies(species)}
			ariaLabel={`${species} abwählen`}
		>
			<span>{species}</span>
			<span aria-hidden="true" class="text-base leading-none">×</span>
		</Button>
	{/each}
</div>