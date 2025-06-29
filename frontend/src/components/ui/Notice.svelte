<script lang="ts">
	export let tone: 'info' | 'warning' | 'success' = 'info'; // Ton bestimmt Farbe
</script>

<p
	class={`text-sm whitespace-pre-line ${
		tone === 'info' ? 'text-gray-700' : tone === 'warning' ? 'text-yellow-600' : 'text-green-600'
	}`}
>
	<slot />
</p>

<style>
	p :global(a) {
		text-decoration: underline;
	}
</style>
