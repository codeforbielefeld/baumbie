<script lang="ts">
	// Imports
	import { onMount, onDestroy } from 'svelte';
	import { Notice } from '$components/ui';
	import { FlyToTreeButton } from '$components/actions';
	import { loadAdoptedTrees } from '$lib/trees';

	// Types
	import type { User } from '@supabase/supabase-js';
	import type { TreeMeta } from '$types/tree';

	// Props
	export let currentUser: User | null = null;

	// State
	let adoptedTrees: TreeMeta[] = [];
	let loading = true;
	let loggedIn = false;

	let warningMessage: string | null = null;
	let warningTimeout: ReturnType<typeof setTimeout> | null = null;

	// Lifecycle
	onMount(async () => {
		if (!currentUser) {
			loading = false;
			return;
		}
		try {
			adoptedTrees = await loadAdoptedTrees();
		} catch (err) {
			console.error(err);
		} finally {
			loading = false;
		}
	});

	onDestroy(() => {
		if (warningTimeout) {
			clearTimeout(warningTimeout);
		}
	});

	// Functions
	function showWarning(msg: string) {
		warningMessage = msg;

		if (warningTimeout) {
			clearTimeout(warningTimeout);
		}

		warningTimeout = setTimeout(() => {
			warningMessage = null;
			warningTimeout = null;
		}, 5000);
	}
</script>

{#if loading}
	<p class="text-sm text-gray-500">Bäume werden geladen …</p>
{:else if adoptedTrees.length > 0}
	<div class="flex flex-col gap-2 items-start">
		<div class="flex flex-wrap gap-2">
			{#each adoptedTrees as tree}
				<FlyToTreeButton treeId={tree.id} on:warning={(e) => showWarning(e.detail.message)} />
			{/each}
		</div>

		{#if warningMessage}
			<div class="text-xs text-left leading-snug w-full">
				<Notice tone="warning">
					{warningMessage}
				</Notice>
			</div>
		{/if}
	</div>
{:else}
	<Notice tone="info">
		Du hast noch keine Bäume adoptiert.
		{#if !loggedIn}
			<a href="/login" class="text-green-600 underline">Jetzt einloggen</a> und loslegen!
		{/if}
	</Notice>
{/if}
