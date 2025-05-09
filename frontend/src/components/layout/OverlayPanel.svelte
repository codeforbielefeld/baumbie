<!-- components/layout/OverlayPanel.svelte -->
<script lang="ts">
	import ModalFrame from '$components/ui/ModalFrame.svelte';
	import Heading from '$components/ui/Heading.svelte';
	import { createEventDispatcher } from 'svelte';

	export let title: string = '';
	export let open: boolean = true;
	export let closeable: boolean = true;

	const dispatch = createEventDispatcher();
	const handleClose = () => dispatch('close');
</script>

<ModalFrame bind:open on:close={handleClose}>
	<div
		class="fixed bottom-[64px] top-[80px] left-0 right-0 z-[1200] flex justify-center"
	>
		<div class="bg-white px-4 pt-4 rounded-t-xl shadow-xl flex flex-col w-full max-w-5xl mx-auto h-full overflow-hidden">
			<!-- Header -->
			<header class="flex flex-row items-center justify-between shrink-0">
				<Heading level={1}>{title}</Heading>
				{#if closeable}
					<button on:click={handleClose}>
						<img src="/card/cross.svg" alt="close" />
					</button>
				{/if}
			</header>

			<slot name="navigation" />

			<div class="grow min-h-0 flex flex-col">
				<div class="overflow-y-auto grow min-h-0">
					<slot />
				</div>
			</div>
		</div>
	</div>
</ModalFrame>
