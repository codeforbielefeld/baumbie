<script lang="ts">
	import '../app.css';
	import Map from '$components/map/Map.svelte';
	import { Navbar } from '$components/overlay';
	interface Props {
		children?: import('svelte').Snippet;
	}

	let { children }: Props = $props();
</script>

<svelte:head>
	<title>Gieß Bielefeld</title>
</svelte:head>

<div class="flex flex-col min-h-screen min-w-screen">
	<div class="flex flex-col justify-end grow">
		<Map />
		<div class="flex flex-col justify-end grow">
			<div class="z-[1100]">
				{@render children?.()}
			</div>
		</div>
	</div>
	<div class="z-[1100] shrink">
		<Navbar />
	</div>
</div>
