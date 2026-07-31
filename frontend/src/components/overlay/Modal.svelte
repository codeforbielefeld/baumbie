<script lang="ts">
	import { createBubbler, stopPropagation } from 'svelte/legacy';

	const bubble = createBubbler();
	import Heading from '$components/ui/Heading.svelte';
	import { goto } from '$app/navigation';

	interface Props {
		title?: string;
		children?: import('svelte').Snippet;
	}

	let { title = '', children }: Props = $props();

	const onClickBackdrop = () => {
		goto('/');
	};
</script>

<!-- Backdrop START -->
<!-- svelte-ignore a11y_click_events_have_key_events, a11y_no_static_element_interactions -->
<div
	class="fixed top-0 left-0 w-full h-full z-[1100] bg-gray-700 bg-opacity-50"
	onclick={onClickBackdrop}
>
	<div class="z-[1200] flex flex-row items-center justify-center w-full h-full">
		<!-- Box START -->
		<div class="px-8 py-4 bg-white w-96 rounded-xl" onclick={stopPropagation(bubble('click'))}>
			<Heading level={1}>{title}</Heading>
			{@render children?.()}
		</div>
		<!-- Box END -->
	</div>
</div>
<!-- Backdrop END -->
