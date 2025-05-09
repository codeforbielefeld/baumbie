<script lang="ts">
	import DefaultButton from "$components/ui/button/DefaultButton.svelte";
	import OverlayPanel from "$components/layout/OverlayPanel.svelte";
	import Heading from '$components/ui/Heading.svelte';

	import { onMount } from "svelte";
	import { supabase } from "$shared/api/supabase";
	import { goto } from '$app/navigation';

	let open = true;
	let adopted_trees = null;

	async function getUserData() {
		const user = await supabase.auth.getUser();
		return user;
	}

	onMount(async () => {
		const user = await getUserData();
		const user_id = user.data.user.id;

		const { data, error } = await supabase
			.from('adoptions')
			.select()
			.eq('user_uuid', user_id);

		if (error) {
			console.error(error);
			return;
		}

		adopted_trees = await Promise.all(
			data?.map(async (tree) => {
				const { data: treeData, error: treeError } = await supabase
					.from('trees')
					.select()
					.eq('uuid', tree.tree_uuid)
					.maybeSingle();

				if (treeError) {
					console.error(treeError);
					return null;
				}

				return {
					id: tree.tree_uuid,
					name: treeData?.tree_type_german || "Unknown Tree"
				};
			}) || []
		);
	});
</script>

<OverlayPanel title="Dein Status" bind:open={open} closeable>
	<Heading level={1}>Dein Status</Heading>

	<div>
		<Heading level={2}>Dein Gießfortschritt</Heading>
	</div>

	<div>
		<Heading level={2}>Deine adoptierten Bäume</Heading>
		<div class="flex flex-row gap-2 flex-wrap">
			{#if adopted_trees}
				{#each adopted_trees as tree (tree.id)}
					<DefaultButton
						label={tree.name}
						icon_src="/icons/tree.svg"
						icon_alt="Baum"
						on:click={() => goto(`/trees/${tree.id}`)}
					/>
				{/each}
			{/if}
		</div>
	</div>

	<div>
		<Heading level={2}>Bäume in deiner Nähe</Heading>
	</div>
</OverlayPanel>