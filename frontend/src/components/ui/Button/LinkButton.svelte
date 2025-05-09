<script>
	import BaseButton from './BaseButton.svelte';
</script>


<a href={$$props.hres}>
<BaseButton
	on:click
	{...$$props}
	{...$$restProps}
	class={` border-2 border-green-500 text-black text-center ${$$props.class}` }
	label={$$props.label}
/>
</a>