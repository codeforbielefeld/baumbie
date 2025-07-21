<script lang="ts">
	import TreeMetric from './TreeMetric.svelte';
	import { isMobile } from '$lib/utils/media';

	export let height: number;
	export let crown_diameter: number;
	export let trunk_diameter: number;
</script>

{#if $isMobile}
	<!-- 📱 Mobile: Carousel -->
	<div class="relative">
		<div
			class="flex gap-4 overflow-x-auto scroll-smooth snap-x snap-mandatory px-1 pb-2"
			style="scrollbar-width: thin;"
		>
			<TreeMetric label="Höhe" value={height} unit="m" max={39} position="right" />
			<TreeMetric
				label="Kronendurchmesser"
				value={crown_diameter}
				unit="m"
				max={29}
				position="top"
			/>
			<TreeMetric
				label="Stammdurchmesser"
				value={trunk_diameter}
				unit="cm"
				max={297}
				position="bottom"
			/>
		</div>
	</div>
{:else}
	<!-- 💻 Desktop: 3-Spalten-Grid -->
	<div class="grid grid-cols-3 gap-4 text-sm text-gray-800">
		<TreeMetric label="Höhe" value={height} unit="m" max={39} position="right" />
		<TreeMetric label="Kronendurchmesser" value={crown_diameter} unit="m" max={29} position="top" />
		<TreeMetric
			label="Stammdurchmesser"
			value={trunk_diameter}
			unit="cm"
			max={297}
			position="bottom"
		/>
	</div>
{/if}
