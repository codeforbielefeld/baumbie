<script lang="ts">
	import InputField from './InputField.svelte';

	export let value: string = '';
	export let error: string = '';

	$: value, error;
</script>

<InputField {...$$props} type="email" bind:value {error} />
