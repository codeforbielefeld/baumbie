<script lang="ts">
	import { Heading } from '$components/ui';
	interface Props {
		title?: string | null;
		level?: 1 | 2 | 3 | 4 | 5 | 6;
		className?: string;
		children?: import('svelte').Snippet;
	}

	let {
		title = null,
		level = 2,
		className = '',
		children
	}: Props = $props();
</script>

<div class={`p-4 bg-gray-50 border border-gray-200 rounded-lg space-y-3 ${className}`.trim()}>
	{#if title}
		<Heading {level}>{title}</Heading>
	{/if}
	{@render children?.()}
</div>
