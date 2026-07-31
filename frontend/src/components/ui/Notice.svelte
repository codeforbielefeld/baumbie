<script lang="ts">
	interface Props {
		tone?: 'info' | 'warning' | 'success'; // Ton bestimmt Farbe
		children?: import('svelte').Snippet;
	}

	let { tone = 'info', children }: Props = $props();
</script>

<p
	class={`text-sm whitespace-normal ${
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
