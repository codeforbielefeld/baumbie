<script lang="ts">
	import { DialogPanel } from '$components/overlay';
	import { FilterTrees } from '$components/search';
</script>

<DialogPanel title={'Baumarten finden'} open={true}>
	<div class="h-full min-h-[24rem] pt-2 pb-6">
		<FilterTrees />
	</div>
</DialogPanel>
