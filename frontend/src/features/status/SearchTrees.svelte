<script lang="ts">
	import Heading from '$components/typography/Heading.svelte';
	import { getCurrentPosition, getBoundingBox, extractTreeCandidates } from '$lib/geo';
	import { goto } from '$app/navigation';
	import findMatchingSegments from '../../businessLogic/findSegments';
	import Button from '$components/button/Button.svelte';

	let treesNearby: {
		id: string;
		name: string;
		distance: number;
		lat: number;
		lng: number;
		crown?: number;
	}[] = [];

	let errorMessage: string | null = null;

	async function findTreesNearby() {
		treesNearby = [];
		errorMessage = null;

		try {
			const coords = await getCurrentPosition();

			const radiusDeg = 0.0015;
			const { minX, maxX, minY, maxY } = getBoundingBox(
				coords.latitude,
				coords.longitude,
				radiusDeg
			);

			const segmentFiles = await findMatchingSegments(minX, maxX, minY, maxY);

			const candidates = await extractTreeCandidates(
				segmentFiles,
				minX,
				maxX,
				minY,
				maxY,
				coords.latitude,
				coords.longitude
			);

			treesNearby = candidates.sort((a, b) => a.distance - b.distance).slice(0, 5);

			if (treesNearby.length === 0) {
				errorMessage = '❌ Keine Bäume in deiner Nähe gefunden.';
			}
		} catch (error) {
			errorMessage = '❌ Dein Standort konnte nicht ermittelt werden.';
		}
	}
</script>

<div class="p-4 bg-gray-50 border border-gray-200 rounded-lg space-y-3">
	<Heading level={2}>Bäume in meiner Nähe</Heading>

	<Button variant="primary" onClick={findTreesNearby}>Jetzt Bäume finden</Button>

	{#if errorMessage}
		<p class="text-sm text-red-600">{errorMessage}</p>
	{/if}

	{#if treesNearby.length}
		<ul class="mt-4 divide-y divide-gray-200 text-sm">
			{#each treesNearby as tree}
				<li class="flex items-center justify-between py-2">
					<div class="flex items-center gap-2">
						<span>{tree.name}</span>
						<img src="/icons/tree.svg" alt="Baum" class="w-4 h-4" />
					</div>

					<Button onClick={() => goto(`/trees/${tree.id}`)}>
						{tree.distance.toFixed(1)} m →
					</Button>
				</li>
			{/each}
		</ul>
	{/if}
</div>
