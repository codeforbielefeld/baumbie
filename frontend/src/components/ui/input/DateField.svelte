<script lang="ts">
    import { run } from 'svelte/legacy';

    import { Notice } from '$components/ui';
    import type { HTMLInputTypeAttribute } from 'svelte/elements';


    interface Props {
        id?: string | undefined;
        label?: string | undefined;
        value?: string; // Default: aktuelles Datum im Format YYYY-MM-DD
        placeholder?: string;
        errorMessage?: string | null;
        error?: boolean;
        type?: HTMLInputTypeAttribute;
        inputClass?: string | undefined;
    }

    let {
        id = undefined,
        label = undefined,
        value = $bindable(new Date().toISOString().slice(0, 10)),
        placeholder = '',
        errorMessage = null,
        error = $bindable(false),
        type = 'date',
        inputClass = undefined
    }: Props = $props();

    run(() => {
        error = !value;
    }); // Fehler, wenn kein Datum gesetzt ist
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
        />
        {#if error && errorMessage}
            <Notice tone="warning">
                {errorMessage}
            </Notice>
        {/if}
    </label>
{:else}
    <input
        {id}
        {...{ type }}
        class={`${inputClass} rounded-lg border ${error ? 'border-red-500' : 'border-gray-500'} p-2`}
        {placeholder}
        bind:value
    />
    {#if error && errorMessage}
        <p class="text-sm text-red-500">{errorMessage}</p>
    {/if}
{/if}
