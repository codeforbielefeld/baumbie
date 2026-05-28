<script lang="ts">
	import { page } from '$app/state';
	import { goto } from '$app/navigation';
	import { supabase } from '$lib/supabase';
	import type { TreeData } from '$types/tree';
	import Card from '$components/ui/Card.svelte';

	let treeId: string | undefined = $derived(page.params.treeId);

	async function loadTree(id: string | undefined): Promise<TreeData | undefined> {
		if (!id) return undefined;
		const { data } = await supabase
			.from('trees')
			.select()
			.eq('uuid', id)
			.maybeSingle();
		return data;
	}

	function handleCardClose() {
		goto('/');
	}

    let categories = {
        "Baum": {"label": "Steckbrief", "icon": "tree"},
        "Pflanze": {"label": "Insekten", "icon": "leaf"},
        "Tier": {"label": "Wasserbedarf", "icon": "paw"},
		"Vergleich": {"label": "Vergleich", "icon": "balance-scale"},
		"Geschichte": {"label": "Geschichte", "icon": "history"},
				"Test": {"label": "Test", "icon": "history"},
				"test2": {"label": "Test 2", "icon": "history"}
    }


</script>

{#await loadTree(treeId)}
	<p>Lädt...</p>
{:then tree}
	{#if tree}
		<Card type="tree"
				data={tree}
				onClose={handleCardClose}
				categories={categories} />
	{/if}
{:catch error}
	<p>Fehler beim Laden: {error.message}</p>
{/await}