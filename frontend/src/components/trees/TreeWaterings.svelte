<script lang="ts">
	import { onMount } from 'svelte';
	import { getWateringsForTree, getCurrentUser } from '$lib/supabase';
	import { WateringHistory } from '$components/waterings';
	import { Notice } from '$components/ui';
	import type { Watering } from '$types/watering';

	export let treeId: string;

	let currentUserId: string | null = null;
	let waterings: Watering[] = [];
	let loading = true;
	let error: string | null = null;

	async function loadWaterings() {
		try {
			loading = true;
			error = null;
			waterings = await getWateringsForTree(treeId);
		} catch (err) {
			console.error('Fehler beim Laden der Gießungen:', err);
			error = 'Fehler beim Laden der Gießungen.';
		} finally {
			loading = false;
		}
	}

	onMount(async () => {
		const user = await getCurrentUser();
		currentUserId = user?.id ?? null;
		await loadWaterings();
	});
</script>

{#if error}
	<Notice tone="warning">{error}</Notice>
{:else if loading}
	<Notice tone="info">Wird geladen...</Notice>
{:else}
	<WateringHistory {waterings} {currentUserId} on:reload={loadWaterings} />
{/if}
