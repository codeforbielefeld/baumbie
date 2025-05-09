<script lang="ts">
	import type { HTMLInputTypeAttribute } from 'svelte/elements';

	export let id: string | undefined = undefined;
	export let label: string | undefined = undefined;
	export let value: string = '';
	export let placeholder: string = '';
	export let error: string = '';

	export let type: HTMLInputTypeAttribute;
	export let inputClass: string | undefined = undefined;

	$: value, type, error;
</script>

{#if id && label}
	<label class="block" for={id}>
		<div class="block mb-1">{label}</div>
		<input
			{id}
			{...{ type }}
			class={`${inputClass} rounded-lg border ${error ? 'border-red-500' : 'border-gray-500'} p-2`}
			{placeholder}
			bind:value
			on:input={() => (error = '')}
		/>
		{#if error}
			<p class="text-sm text-red-500">{error}</p>
		{/if}
	</label>
{:else}
	<input
		{...{ type }}
		class={`${inputClass} rounded-lg border ${error ? 'border-red-500' : 'border-gray-500'} p-2`}
		{placeholder}
		bind:value
		on:input={() => (error = '')}
	/>
	{#if error}
		<p class="text-sm text-red-500">{error}</p>
	{/if}
{/if}
