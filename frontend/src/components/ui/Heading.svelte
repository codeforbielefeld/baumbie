<script lang="ts">
	export let level: number = 1;
	console.log("level: ",)
</script>

{#if level === 1}
	<h1 {...$$props} class={`${$$props.class} font-bold text-2xl pb-4`}><slot /></h1>
{:else if level === 2}
	<h2 {...$$props} class={`${$$props.class} font-bold pb-2`}><slot /></h2>
{:else if level === 3}
	<h3 {...$$props} class={`${$$props.class} font-bold pb-2`}><slot /></h3>
{:else if level === 4}
	<h4 {...$$props} class={`${$$props.class} font-bold pb-2`}><slot /></h4>
{:else if level === 5}
	<h5 {...$$props} class={`${$$props.class} font-bold pb-2`}><slot /></h5>
{:else if level === 6}
	<h6 {...$$props} class={`${$$props.class} font-bold pb-2`}><slot /></h6>
{/if}
