<script lang="ts">
	import { onMount } from 'svelte';
	import { getCurrentUser } from '$lib/supabase';

	let userEmail: string | undefined = $state('');

	onMount(async () => {
		const urlParams = new URLSearchParams(window.location.search);
		const emailFromParam = urlParams.get('email');

		const user = await getCurrentUser();
		userEmail = user?.email ?? emailFromParam ?? 'Unbekannt';
	});
</script>

<p>
	Wir haben über unseren Authentifizierungsdienst <strong>Supabase</strong> eine Bestätigungsmail an
	<strong>{userEmail}</strong>
	gesendet. <br />
	Bitte klicke auf den Link darin, um dein Benutzerkonto zu aktivieren.
</p>
