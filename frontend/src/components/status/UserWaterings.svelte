<script lang="ts">
	import { onMount } from 'svelte';
	import { getWateringsForUser } from '$lib/supabase';
	import { WateringHistory } from '$components/waterings';
	import { Notice } from '$components/ui';
	import { loadSpeciesMap } from '$lib/supabase/trees';

	// Types
	import type { User } from '@supabase/supabase-js';
	import type { Watering } from '$types/watering';

	// Props
	export let currentUser: User | null = null;

	// State
	let labelsByTreeId: Map<string, string> = new Map();
	let currentUserId: string | null = null;
	let loggedIn = false;
	let loading = true;
	let error: string | null = null;
	let waterings: Watering[] = [];

	// Lifecycle
	onMount(async () => {
		if (!currentUser) {
			loading = false;
			return;
		}
		await loadWaterings();
	});

	// Load Function
	async function loadWaterings() {
		try {
			loading = true;
			error = null;

			if (!loggedIn) return;

			waterings = await getWateringsForUser(currentUserId!);
			const treeIds = [...new Set(waterings.map((w) => w.tree_uuid))];
			labelsByTreeId = await loadSpeciesMap(treeIds);
		} catch (err) {
			error = 'Fehler beim Laden deiner Gießungen.';
			console.error(err);
		} finally {
			loading = false;
		}
	}
</script>

{#if error}
	<Notice tone="warning">{error}</Notice>
{:else if loading}
	<Notice tone="info">Wird geladen…</Notice>
{:else if waterings.length > 0}
	<WateringHistory
		{waterings}
		{currentUserId}
		{labelsByTreeId}
		mode="user"
		on:reload={loadWaterings}
	/>
{:else}
	<Notice tone="info">
		Bisher hast du noch keine Gießungen eingetragen.
		{#if !loggedIn}
			<a href="/login" class="text-green-600 underline">Jetzt einloggen</a> und loslegen!
		{/if}
	</Notice>
{/if}
