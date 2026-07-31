<script lang="ts">
	import { goto } from '$app/navigation';
	import { registerWithEmailPassword } from '$lib/supabase';
	import { EmailField, PasswordField, Button, Notice } from '$components/ui';

	let email = $state('');
	let password = $state('');
	let passwordConfirmation = $state('');
	let errorMessage: string | null = $state(null);
	let isSubmitting = $state(false);
	let errorTimeout: ReturnType<typeof setTimeout> | null = null;

	const handleRegistration = async (e: SubmitEvent) => {
		e.preventDefault();

		// 🔍 Früher Exit bei Client-Validierung
		if (password !== passwordConfirmation) {
			errorMessage = 'Die Passwörter stimmen nicht überein!';
			resetErrorAfterDelay();
			return;
		}

		isSubmitting = true;
		errorMessage = null;

		try {
			const result = await registerWithEmailPassword(email, password);

			if (result.emailConfirmationRequired) {
				await new Promise((r) => setTimeout(r, 3000));
			}

			goto('/confirm-registration?email=' + encodeURIComponent(email));
		} catch (err) {
			if (err instanceof Error) {
				errorMessage = err.message;

				// Spezieller Fall: "bereits registriert"
				if (err.message.includes('bereits registriert')) {
					setTimeout(() => {
						errorMessage = null;
						goto('/login');
					}, 3000);
					return;
				}
			} else {
				errorMessage = 'Unbekannter Fehler bei der Registrierung.';
			}

			resetErrorAfterDelay();
		} finally {
			isSubmitting = false;
		}
	};

	function resetErrorAfterDelay() {
		if (errorTimeout) clearTimeout(errorTimeout);
		errorTimeout = setTimeout(() => {
			errorMessage = null;
			errorTimeout = null;
		}, 5000);
	}
</script>

<form onsubmit={handleRegistration} class="flex flex-col gap-y-4">
	<div class="flex flex-col gap-y-2">
		<EmailField
			id="email"
			label="E-Mail:"
			inputClass="w-full"
			placeholder="lebensbaum@baumbie.de"
			bind:value={email}
		/>
		<PasswordField
			id="password"
			label="Passwort:"
			inputClass="w-full"
			placeholder="Passwort"
			bind:value={password}
		/>
		<PasswordField
			id="password_confirmation"
			label="Passwort (Wiederholung):"
			inputClass="w-full"
			placeholder="Passwort"
			bind:value={passwordConfirmation}
		/>
	</div>

	{#if errorMessage}
		<Notice tone="warning">{errorMessage}</Notice>
	{/if}

	<div class="flex flex-col gap-y-2">
		<Button variant="primary" type="submit" disabled={isSubmitting} className="w-full">
			{isSubmitting ? 'Wird gesendet...' : 'Registrieren'}
		</Button>
		<Button variant="secondary" type="button" onClick={() => goto('/login')} className="w-full">
			Anmelden
		</Button>
	</div>
</form>
