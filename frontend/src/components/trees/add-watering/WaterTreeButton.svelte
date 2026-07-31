<script lang="ts">
	import type { TreeData } from '$types/tree';
	import { Button } from '$components/ui';
	import { goto } from '$app/navigation';

	interface Props {
		tree: TreeData;
	}

	let { tree }: Props = $props();
</script>

{#if tree}
	<div class="flex flex-col gap-2">
		<Button variant="watering" onClick={() => goto(`/trees/${tree.uuid}/water`)}>
			Gieße diesen Baum
		</Button>
	</div>
{/if}
