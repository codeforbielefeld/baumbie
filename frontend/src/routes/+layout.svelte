<script lang="ts">
	import '../app.css';
	import Map from '$features/map/Map.svelte';
	import Navbar from '$components/layout/Navbar.svelte';
</script>

<svelte:head>
	<title>Gieß Bielefeld</title>
</svelte:head>

<div class="flex flex-col min-h-screen min-w-screen">
	<div class="flex flex-col justify-end grow">
		<Map />
		<div class="flex flex-col justify-end grow">
			<div class="z-[1100]">
				<slot />
			</div>
		</div>
	</div>
	<div class="z-[1100] shrink">
		<Navbar />
	</div>
</div>
