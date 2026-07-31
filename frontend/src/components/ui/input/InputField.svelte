<script lang="ts">
	import { run } from 'svelte/legacy';

	import type { HTMLInputTypeAttribute } from 'svelte/elements';


	interface Props {
		id?: string | undefined;
		label?: string | undefined;
		value?: string;
		placeholder?: string;
		error?: string;
		type: HTMLInputTypeAttribute;
		inputClass?: string | undefined;
	}

	let {
		id = undefined,
		label = undefined,
		value = $bindable(''),
		placeholder = '',
		error = $bindable(''),
		type,
		inputClass = undefined
	}: Props = $props();

	run(() => {
		value, type, error;
	});
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
			oninput={() => (error = '')}
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
		oninput={() => (error = '')}
	/>
	{#if error}
		<p class="text-sm text-red-500">{error}</p>
	{/if}
{/if}
