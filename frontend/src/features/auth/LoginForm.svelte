<script lang="ts">
	import { onMount } from 'svelte';
	import LinkButton from '$components/ui/button/LinkButton.svelte';
	import PrimaryButton from '$components/ui/button/PrimaryButton.svelte';
	import EmailField from '$components/ui/input/EmailField.svelte';
	import PasswordField from '$components/ui/input/PasswordField.svelte';
	import { supabase } from '$shared/api/supabase';
	import { goto } from '$app/navigation';

	let email: string = '';
	let password: string = '';
	let errorCode: string | undefined = undefined;
	$: email, password, errorCode;

	let loading: boolean = false;

	onMount(() => {
		const { data } = supabase.auth.onAuthStateChange((event, session) => {
			if (event === 'INITIAL_SESSION') {
				// handle initial session
			} else if (event === 'SIGNED_IN') {
				// handle sign in event
			} else if (event === 'SIGNED_OUT') {
				// handle sign out event
			} else if (event === 'PASSWORD_RECOVERY') {
				// handle password recovery event
			} else if (event === 'TOKEN_REFRESHED') {
				// handle token refreshed event
			} else if (event === 'USER_UPDATED') {
				// handle user updated event
			}
		});

		// call unsubscribe to remove the callback
		data.subscription.unsubscribe();
	});

	const handleLogin = async (e: any) => {
		e.preventDefault();

		loading = true;
		const { data, error } = await supabase.auth.signInWithPassword({
			email,
			password
		});
		if (!data?.user) {
			errorCode = 'Die Anmeldung mit diesen Zugangsdaten ist fehlgeschlagen!';
			return;
		}
		goto('/authenticated');
	};
</script>

<form class="flex flex-col gap-y-4">
	<div class="flex flex-col gap-y-2">
		<EmailField
			id="email"
			label="E-Mail:"
			inputClass="w-full"
			placeholder="jdoe@example.com"
			error={errorCode}
			bind:value={email}
		/>
		<PasswordField
			id="password"
			label="Passwort:"
			inputClass="w-full"
			placeholder="Passwort"
			error={errorCode}
			bind:value={password}
		/>
	</div>
	<div class="flex flex-col gap-y-2">
		<PrimaryButton type="submit" label="Anmelden" on:click={handleLogin} class="w-full" />
		<LinkButton href="/register" label="Registrieren" class="w-full" />
	</div>
</form>
