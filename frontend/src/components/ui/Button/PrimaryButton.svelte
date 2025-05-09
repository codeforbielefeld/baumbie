<script>
	import BaseButton from './BaseButton.svelte';
</script>

<BaseButton
	on:click
	{...$$props}
	{...$$restProps}
	class={`bg-green-600 hover:bg-green-800 hover:text-white text-black ${$$props.class}` }
	label={$$props.label}
/>
