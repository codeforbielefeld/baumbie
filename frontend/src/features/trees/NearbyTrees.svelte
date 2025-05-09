<script lang="ts">
	import { supabase } from '$shared/api/supabase';

	let trees;
	$: trees = [];

	let lat;
	$: lat = 51.967253570179;
	let long;
	$: long = 8.40436126403756;

	const getTrees = () => {
		supabase.rpc('nearby_trees', {
			lat,
			long,
		}).then(({ data, error }) => {
			if (error) {
				console.error(error);
			} else {
				trees = data;
			}
		});
	};
</script>

<div>
	<div class="flex row space-x-4">
		<div>
			<label for="lat-input" >Längengrad:</label>
			<input id="lat-input" type="number" bind:value={lat} class="border border-black rounded-sm" />
		</div>

		<div>
			<label for="long-input">Breitengrad:</label>
			<input id="long-input" type="number" bind:value={long} class="border border-black rounded-sm" />
		</div>

		<button on:click={()=>getTrees()}>Bäume laden</button>

	</div>

	<div>Bäume in der Nähe:</div>
	<ul class="list-disc max-h-48 overflow-y-scroll">
	{#each trees as tree}
		<li>
			{tree.tree_type_german} ({tree.dist_meters}m)
		</li>
	{/each}
	</ul>
</div>