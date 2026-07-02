<script lang="ts">
	import { goto } from '$app/navigation';
	import { Modal } from '$components/overlay';
	import { Button, Notice } from '$components/ui';
	import { deleteCurrentUser } from '$lib/supabase';

	let loading = $state(false);
	let error: string | null = $state(null);

	const handleCancel = () => goto('/account');

	const handleConfirm = async () => {
		loading = true;
		error = null;

		const result = await deleteCurrentUser();

		if (result.ok) {
			goto('/');
		} else {
			error = result.error ?? 'Unbekannter Fehler';
			loading = false;
		}
	};
</script>

<Modal title="Account unwiderruflich löschen?">
	<p class="mb-4 text-sm">
		Dieser Vorgang löscht deinen Account bei unserem Auth-Dienstleister <strong>supabase.com</strong
		>.
		<br />
		Alle deine gespeicherten Wässerungsdaten werden einem anonymen Benutzer zugeordnet.
	</p>

	{#if loading}
		<Notice tone="info">Account wird gelöscht …</Notice>
	{:else if error}
		<Notice tone="warning">{error}</Notice>
	{/if}

	<div class="flex gap-2 justify-end mt-4">
		<Button variant="secondary" onClick={handleCancel} disabled={loading}>Abbrechen</Button>
		<Button variant="danger" onClick={handleConfirm} disabled={loading}>Ja, Account löschen</Button>
	</div>
</Modal>
