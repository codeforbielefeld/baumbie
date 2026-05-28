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
        "Baum": {"label": "Steckbrief",
				"icon": "tree",
				"slides": [{"title": "Basics",
							"content": "Vorstellungstext, key facts"},
							{"title": "Bielefeld-vergleich",
							"content": "Wie oft in Bielefeld, Abweichung vom Durchschnitt etc"},
							{"title": "Standort",
							"content": "Wo in Bielefeld, Standortfaktoren etc"},
							{"title": "Besonderes",
							"content": "zB Baum des Jahres, Kultur oder so"}]},
        "Pflanze": {"label": "Insekten",
					"icon": "leaf",
					"slides": []
					},
        "Tier": {"label": "Wasserbedarf",
				"icon": "paw",
					"slides": []},
		"Vergleich": {"label": "Vergleich",
					"icon": "balance-scale",
					"slides": []},
		"Geschichte": {"label": "Geschichte",
						"icon": "history",
						"slides": []},
		"Test": {"label": "Test",
					"icon": "history",
					"slides": []},
		"test2": {"label": "Test 2",
				"icon": "history",
				"slides": []}
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