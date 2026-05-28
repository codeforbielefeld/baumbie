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

</script>

{#await loadTree(treeId)}
	<p>Lädt...</p>
{:then tree}
	{#if tree}
		<Card type="tree" data={tree} onClose={handleCardClose} />
	{/if}
{:catch error}
	<p>Fehler beim Laden: {error.message}</p>
{/await}