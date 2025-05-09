<script lang="ts">
	import { createEventDispatcher } from 'svelte';

	export let open = true;
	const dispatch = createEventDispatcher();

	function onClickBackdrop() {
		dispatch('close');
	}
</script>

{#if open}
<div
	role="presentation"
	aria-hidden="true"
	class="fixed inset-0 z-[1100] bg-black/50 flex items-center justify-center"
	on:click={onClickBackdrop}
>
	<!-- svelte-ignore a11y-click-events-have-key-events a11y-no-noninteractive-element-interactions -->
	<div
		role="dialog"
		aria-modal="true"
		class="z-[1200]"
		on:click|stopPropagation
	>
		<slot />
	</div>
</div>
{/if}
