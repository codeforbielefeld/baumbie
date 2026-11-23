<script lang="ts">
	interface Props {
		tone?: 'info' | 'warning' | 'success'; // Ton bestimmt Farbe
		fontSize?: 'sm' | 'base' | 'lg'; // Schriftgröße
		children?: import('svelte').Snippet;
	}

	let { tone = 'info', fontSize = 'sm', children }: Props = $props();
</script>

<p
	class={`text-${fontSize} whitespace-normal ${
		tone === 'info' ? 'text-gray-700' : tone === 'warning' ? 'text-yellow-600' : 'text-green-600'
	}`}
>
	{@render children?.()}
</p>

<style>
	p :global(a) {
		text-decoration: underline;
	}
</style>
