<script lang="ts">
	import { Button } from '$components/ui';
	import { selectedTreeFilters } from '$lib/trees';
	import { fade } from 'svelte/transition';

	let current = $derived($selectedTreeFilters.species ?? []);
	let scrollArea = $state<HTMLDivElement>();
	let scrollContent = $state<HTMLDivElement>();
	let canScrollLeft = $state(false);
	let canScrollRight = $state(false);

	function updateScrollIndicators() {
		if (!scrollArea) return;
		canScrollLeft = scrollArea.scrollLeft > 1;
		canScrollRight = scrollArea.scrollLeft + scrollArea.clientWidth < scrollArea.scrollWidth - 1;
	}

	$effect(() => {
		if (!scrollArea || !scrollContent) return;

		const observer = new ResizeObserver(updateScrollIndicators);
		observer.observe(scrollArea);
		observer.observe(scrollContent);
		updateScrollIndicators();

		return () => observer.disconnect();
	});

	function toggleSpecies(species: string) {
		const updated = current.includes(species)
			? current.filter((selectedSpecies) => selectedSpecies !== species)
			: [...current, species];

		selectedTreeFilters.set({ species: updated });
	}
</script>

{#if current.length > 0}
	<div
		class="fixed left-0 right-0 top-0 z-[1001] flex min-w-0 items-center gap-2 px-1 py-3"
		transition:fade={{ duration: 150 }}
	>
		<Button
			variant="secondary"
			onClick={() => selectedTreeFilters.set({ species: [] })}
			className="shrink-0 whitespace-nowrap !border-gray-300 !bg-white/95 !px-3 !py-1 !text-sm !text-gray-600 shadow-md hover:!bg-gray-100"
		>
			Alle Baumarten anzeigen
		</Button>
		<div class="relative min-w-0 flex-1">
			<div
				bind:this={scrollArea}
				onscroll={updateScrollIndicators}
				role="region"
				aria-label="Ausgewählte Baumarten"
				tabindex="0"
				class="filter-scroll-area overflow-x-auto"
			>
				<div bind:this={scrollContent} class="flex w-max min-w-full items-center gap-2">
					{#each current as species (species)}
						<Button
							variant="secondary"
							className="shrink-0 whitespace-nowrap gap-2 !border-green-600 !bg-green-300 !px-3 !py-1 !text-sm !text-green-900 shadow-md hover:!bg-green-300"
							onClick={() => toggleSpecies(species)}
							ariaLabel={`${species} abwählen`}
						>
							<span>{species}</span>
							<span aria-hidden="true" class="text-base leading-none">×</span>
						</Button>
					{/each}
				</div>
			</div>
			{#if canScrollLeft}
				<div
					class="scroll-edge scroll-edge--left"
					aria-hidden="true"
					transition:fade={{ duration: 250 }}
				></div>
			{/if}
			{#if canScrollRight}
				<div
					class="scroll-edge scroll-edge--right"
					aria-hidden="true"
					transition:fade={{ duration: 250 }}
				></div>
			{/if}
		</div>
	</div>
{/if}

<style>
	.filter-scroll-area {
		scrollbar-width: none;
		-ms-overflow-style: none;
	}

	.filter-scroll-area::-webkit-scrollbar {
		display: none;
	}

	.scroll-edge {
		position: absolute;
		top: 0;
		bottom: 0;
		width: clamp(1.5rem, 5vw, 8rem);
		z-index: 1;
		pointer-events: none;
		background: rgba(255, 255, 255, 0.18);
		-webkit-backdrop-filter: blur(12px) saturate(150%);
		backdrop-filter: blur(12px) saturate(150%);
	}

	.scroll-edge--left {
		left: 0;
		-webkit-mask-image: radial-gradient(ellipse 100% 50% at left center, black 50%, transparent);
		mask-image: radial-gradient(ellipse 100% 50% at left center, black 50%, transparent);
	}

	.scroll-edge--right {
		right: 0;
		-webkit-mask-image: radial-gradient(ellipse 100% 50% at right center, black 50%, transparent);
		mask-image: radial-gradient(ellipse 100% 50% at right center, black 50%, transparent);
	}
</style>