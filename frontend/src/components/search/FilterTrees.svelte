<script lang="ts">
	import { Button } from '$components/ui';
	import { selectedTreeFilters, loadTopSpecies } from '$lib/trees';
	import { onMount } from 'svelte';
	import {Notice} from '$components/ui';

	let topSpecies: { label: string; count: number }[] = $state([]);

	onMount(async () => {
		topSpecies = await loadTopSpecies();
	});

	function toggleSpecies(species: string) {
		const currentSpecies = $selectedTreeFilters.species ?? [];
		const updated = currentSpecies.includes(species)
			? currentSpecies.filter((s) => s !== species)
			: [...currentSpecies, species];

		selectedTreeFilters.set({ species: updated });
	}

	let current = $derived($selectedTreeFilters.species ?? []);
</script>

<div class="w-full max-w-screen-lg mx-auto space-y-10 pt-2">
	<!-- Beschreibung -->
	<div class="space-y-2 text-lg text-gray-800 leading-relaxed">
		<Notice tone="info">
			Hier kannst du gezielt nach bestimmten Baumarten filtern.
			Zur Auswahl stehen die <strong>30 häufigsten</strong> Arten in Bielefeld, die gemeinsam rund
			<strong>85 % aller Stadtbäume</strong> ausmachen.
			Wähle eine oder mehrere Arten aus – die Karte zeigt anschließend nur diese an.
		</Notice>

	</div>

	<!-- Graue Box -->
	<div class="bg-gray-50 border border-gray-200 rounded-2xl px-6 py-6 space-y-6 w-full">
		<!-- Baumarten-Buttons -->
		<div class="flex flex-wrap gap-x-4 gap-y-3">
			{#each topSpecies as species}
				<Button
					onClick={() => toggleSpecies(species.label)}
					variant={current.includes(species.label) ? 'primary' : 'default'}
				>
					<strong>{species.label}</strong>&nbsp;({species.count})
				</Button>
			{/each}
		</div>

		<!-- 🔁 Alle anzeigen unten -->
		<div>
			<Button
				variant={current.length === 0 ? 'primary' : 'default'}
				onClick={() => selectedTreeFilters.set({ species: [] })}
				className="w-full justify-center"
			>
				<strong>Alle Baumarten anzeigen</strong>
			</Button>
		</div>
	</div>
</div>
