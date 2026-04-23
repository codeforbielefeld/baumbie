<script lang="ts">
	import { run } from 'svelte/legacy';

	import { Notice } from '$components/ui';
	import type { HTMLInputTypeAttribute } from 'svelte/elements';


	interface Props {
		id?: string | undefined;
		label?: string | undefined;
		value?: number;
		placeholder?: string;
		errorMessage?: string | null;
		error?: boolean;
		type: HTMLInputTypeAttribute;
		inputClass?: string | undefined;
	}

	let {
		id = undefined,
		label = undefined,
		value = $bindable(0),
		placeholder = '',
		errorMessage = null,
		error = $bindable(false),
		type,
		inputClass = undefined
	}: Props = $props();

	run(() => {
		value, type;
	});

	run(() => {
		error = value <= 0 || value > 100;
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
            min="0"
            max="100"
		/>
		{#if error && errorMessage}
			<Notice tone="warning">
				{errorMessage}
			</Notice>
		{/if}
	</label>
{:else}
	<input
		{...{ type }}
		class={`${inputClass} rounded-lg border ${error ? 'border-red-500' : 'border-gray-500'} p-2`}
		{placeholder}
		bind:value
        min="0"
        max="100"
	/>
	{#if error && errorMessage}
		<p class="text-sm text-red-500">{errorMessage}</p>
	{/if}
{/if}
