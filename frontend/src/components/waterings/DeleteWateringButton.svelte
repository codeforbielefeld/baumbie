<script lang="ts">
	import { Button, Notice } from '$components/ui';
	import ConfirmDeleteWatering from './ConfirmDeleteWatering.svelte';
	import { deleteWatering as deleteWateringFromDB } from '$lib/supabase';
	import type { Watering } from '$types/watering';
	import { createEventDispatcher } from 'svelte';

	interface Props {
		watering: Watering;
	}

	let { watering }: Props = $props();

	const dispatch = createEventDispatcher();
	let error: string | null = $state(null);
	let showConfirm = $state(false);

	async function handleConfirmedDelete() {
		error = null;
		showConfirm = false;

		try {
			await deleteWateringFromDB(watering.uuid);
			dispatch('reload');
		} catch (err) {
			console.error('Fehler beim Löschen der Gießung:', err);
			error = 'Fehler beim Löschen der Gießung.';
		}
	}
</script>

{#if error}
	<Notice tone="warning">{error}</Notice>
{/if}

{#if showConfirm}
	<ConfirmDeleteWatering
		{watering}
		onCancel={() => (showConfirm = false)}
		onConfirm={handleConfirmedDelete}
	/>
{/if}

<Button variant="danger" className="text-sm h-7 px-3 py-1" onClick={() => (showConfirm = true)}>
	Entfernen
</Button>
