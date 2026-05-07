<script lang="ts">
	import InputField from './InputField.svelte';

	interface Props {
		id: string;
		label: string;
		placeholder?: string;
		inputClass?: string;
		value?: string;
		error?: string;
	}

	let {
		id,
		label,
		placeholder = '',
		inputClass = '',
		value = $bindable(''),
		error = ''
	}: Props = $props();
</script>

<InputField type="email" {id} {label} {placeholder} {inputClass} bind:value {error} />
