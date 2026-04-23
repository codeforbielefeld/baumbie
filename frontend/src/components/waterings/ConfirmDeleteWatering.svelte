<script lang="ts">
	import type { Watering } from '$types/watering';
	import { Modal } from '$components/overlay';
	import { Button } from '$components/ui';
	import { formatDate } from '$lib/utils/formatDate';

	interface Props {
		watering: Watering;
		onCancel: () => void;
		onConfirm: () => void;
	}

	let { watering, onCancel, onConfirm }: Props = $props();

	const dateLabel = $derived(`📅\u2003${formatDate(watering.watered_at)}`);
	const amountLabel = $derived(`🚰\u2003${watering.amount_liters} Liter`);
</script>

<Modal title="Gießung wirklich löschen?">
	<p class="text-sm mb-3">Diese Gießung wird dauerhaft entfernt:</p>

	<!-- Highlight-Zeile -->
	<div
		class="bg-[#7C98B2] px-4 py-2 rounded-lg text-sm font-medium text-white flex flex-wrap items-center gap-x-4 gap-y-2"
	>
		<span>{dateLabel}</span>
		<span>{amountLabel}</span>
	</div>

	<div class="flex justify-end gap-2 mt-6">
		<Button variant="secondary" onClick={onCancel}>Abbrechen</Button>
		<Button variant="danger" onClick={onConfirm}>Löschen</Button>
	</div>
</Modal>
