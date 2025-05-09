<script>
	import BaseButton from './BaseButton.svelte';
</script>

<BaseButton
	{...$$props}
	{...$$restProps}
	on:click
	class={`${$$props.class} border-2 border-green-500 text-black`}
	label={$$props.label}
/>
