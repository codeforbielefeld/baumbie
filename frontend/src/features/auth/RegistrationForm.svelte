<script lang="ts">
	import { onMount } from 'svelte';
	import { supabase } from '$shared/api/supabase';
	import Dialog from '$components/layout/OverlayPanel.svelte';
	import EmailField from '$components/ui/input/EmailField.svelte';
	import PasswordField from '$components/ui/input/PasswordField.svelte';
	import PrimaryButton from '$components/ui/button/PrimaryButton.svelte';
	import LinkButton from '$components/ui/button/LinkButton.svelte';

	let email: string = '';
	let password: string = '';
	let passwordConfirmation: string = '';
	let emailErrorCode: string = '';
	let passwordErrorCode: string = '';
	$: email, password, passwordConfirmation, emailErrorCode, passwordErrorCode;

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

	const handleRegistration = async (e: any) => {
		e.preventDefault();

		if (password !== passwordConfirmation) {
			passwordErrorCode = 'Die Passwörter stimmen nicht überein!';
			return;
		}

		loading = true;
		supabase.auth
			.signUp({
				email,
				password
			})
			.then(({ data, error }) => {
				if (error) {
					switch (error.code) {
						case 'user_already_exists':
							emailErrorCode = 'Es ist ein Fehler bei der Registrierung aufgetreten.';
							break;
						case 'validation_failed':
							emailErrorCode = 'Die eingegebene E-Mail-Adresse ist ungültig.';
							break;
						case 'weak_password':
							passwordErrorCode = 'Das Passwort ist zu schwach.';
							break;
						default:
							emailErrorCode = error.code || 'unknown error';
							break;
					}
				} else {
					goto('/authenticated');
				}
			});
	};
</script>

<Dialog title="Registrierung">
	<form class="flex flex-col gap-y-4">
		<div class="flex flex-col gap-y-2">
			<EmailField
				id="email"
				label="E-Mail:"
				inputClass="w-full"
				placeholder="jdoe@example.com"
				error={emailErrorCode}
				bind:value={email}
			/>
			<PasswordField
				id="password"
				label="Passwort:"
				inputClass="w-full"
				placeholder="Passwort"
				error={passwordErrorCode}
				bind:value={password}
			/>
			<PasswordField
				id="password_confirmation"
				label="Passwort (Wiederholung):"
				inputClass="w-full"
				placeholder="Passwort"
				error={passwordErrorCode}
				bind:value={passwordConfirmation}
			/>
		</div>
		<div class="flex flex-col gap-y-2">
			<PrimaryButton
				type="submit"
				label="Registrieren"
				class="w-full"
				on:click={handleRegistration}
			/>
			<LinkButton href="/login" label="Anmelden" class="w-full" />
		</div>
	</form>
</Dialog>
