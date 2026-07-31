<script lang="ts">
	import { goto } from '$app/navigation';
	import { onMount } from 'svelte';
	import { Button } from '$components/ui';
	import { DialogPanel } from '$components/overlay';
	import { logout, getCurrentUser } from '$lib/supabase';

	let user: { email?: string } | null = $state(null);

	onMount(async () => {
		user = await getCurrentUser();
	});

	const handleLogout = async () => {
		await logout();
		goto('/login');
	};
</script>

<DialogPanel title={'Mein Benutzerkonto'} open={true}>
	<div>
		{#if user}
			<p>
				<strong>Nutzer</strong> <br />
				{user.email}
			</p>

			<!--
			<p class="mt-4">
				Benutzername oder E-Mail <button class="underline">bearbeiten</button>?
			</p>
			<p>
				Passwort <button class="underline">ändern</button>?
			</p>
			-->

			<Button variant="secondary" className="mt-4 w-full justify-center" onClick={handleLogout}>
				Ausloggen
			</Button>

			<p class="mt-4">
				Möchtest du deinen Account löschen? <br />
				Damit werden alle von dir generierten Wässerungsdaten einem anonymen Benutzer zugeordnet. Dein
				Benutzer bei unserem Authentifizierungsdienst supabase.com wird sofort und unwiderruflich gelöscht.
			</p>
			<Button
				variant="danger"
				className="justify-center w-full mt-4"
				onClick={() => goto('/account/delete')}
			>
				Account löschen
			</Button>
		{:else}
			<p>Logge dich ein, um BaumBie mit allen Funktionen nutzen zu können.</p>
			<Button
				variant="primary"
				className="justify-center w-full mt-4"
				onClick={() => goto('/login')}
			>
				Einloggen
			</Button>
		{/if}

		<p class="mt-8">
			<a class="underline" href="/imprint">Impressum</a> |
			<a class="underline" href="/data">Datenschutz</a> |
			<a class="underline" href="/baumbie">Über BaumBie</a> |
			<a class="underline" href="https://codefor.de/bielefeld/">Code for Bielefeld</a>
		</p>
	</div>
</DialogPanel>
