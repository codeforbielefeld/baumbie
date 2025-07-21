<script lang="ts">
	import { onMount, onDestroy, tick, createEventDispatcher } from 'svelte';

	export let open = false;
	const dispatch = createEventDispatcher();

	let detailsEl: HTMLDivElement;
	let contentEl: HTMLDivElement;
	let contentHeight = 0;

	let resizeObserver: ResizeObserver;

	const handleClick = () => (open = !open);

	const updateHeight = async () => {
		if (contentEl) {
			await tick();
			contentHeight = contentEl.scrollHeight;
			dispatch('heightchange', { height: contentHeight });
		}
	};

	onMount(() => {
		updateHeight();

		if (contentEl) {
			resizeObserver = new ResizeObserver(() => {
				updateHeight();
			});
			resizeObserver.observe(contentEl);
		}
	});

	onDestroy(() => {
		resizeObserver?.disconnect();
	});

	$: if (open) {
		updateHeight();
	}

	export function updateHeightExternally() {
		updateHeight();
	}
</script>

<div class="accordion">
	<div class="header">
		<div class="text">
			<slot name="head" />
		</div>
		<button on:click={handleClick} class="toggle-button" aria-label="Abschnitt umschalten">
			<img
				src={open ? '/trees/accordion-close.svg' : '/trees/accordion-open.svg'}
				alt={open ? 'Schließen' : 'Öffnen'}
				class="w-4 h-4 m-4"
			/>
		</button>
	</div>

	<!-- Immer im DOM, aber Höhe wird animiert -->
	<div
		class="details-wrapper"
		bind:this={detailsEl}
		style="height: {open ? contentHeight + 'px' : '0px'}; transition: height 300ms ease;"
		aria-hidden={!open}
	>
		<div class="details-content" bind:this={contentEl}>
			<slot name="details" />
		</div>
	</div>
</div>

<style>
	.accordion {
		margin: 1rem 0;
	}

	.header {
		display: flex;
		align-items: center;
		width: 100%;
	}

	.text {
		flex: 1;
	}

	.toggle-button {
		background: none;
		border: none;
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
		padding-right: 0.75rem;
		padding-left: 0.75rem;
		padding-bottom: 0.2rem;
		padding-top: 0.2rem;
		margin-left: auto;
	}

	.details-wrapper {
		overflow: hidden;
		transition: height 300ms ease;
		will-change: height;
	}

	.details-content {
		padding: 0.5rem 0;
	}
</style>
