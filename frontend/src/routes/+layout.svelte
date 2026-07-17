<script lang="ts">
	import '../app.css';
	import { onMount } from 'svelte';
	import Map from '$components/map/Map.svelte';
	import { Navbar } from '$components/overlay';
	interface Props {
		children?: import('svelte').Snippet;
	}

	let { children }: Props = $props();
	let navbarHeight = $state(0);

</script>

<svelte:head>
	<title>Gieß Bielefeld</title>
</svelte:head>

<div class="flex flex-col min-h-screen min-w-screen" style={`--navbar-height: ${navbarHeight}px`}>
	<div class="flex flex-col justify-end grow">
		<Map />
		<div class="flex flex-col justify-end grow">
			<div class="z-[1100]">
				{@render children?.()}
			</div>
		</div>
	</div>
	<div class="z-[1100] shrink">
		<Navbar bind:height={navbarHeight}/>
	</div>
</div>
