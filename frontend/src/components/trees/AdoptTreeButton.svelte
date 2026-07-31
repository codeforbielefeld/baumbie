<script lang="ts">
	import { onMount } from 'svelte';
	import { Button, Notice } from '$components/ui';
	import { getCurrentUser, isTreeAdopted, toggleTreeAdoption } from '$lib/supabase';
	import type { TreeData } from '$types/tree';

	interface Props {
		tree: TreeData;
	}

	let { tree }: Props = $props();

	let adopted = $state(false);
	let authorized = $state(false);
	let message: string | null = $state(null);
	let messageTone: 'success' | 'warning' | 'info' | undefined = $state(undefined);

	let label = $derived(adopted ? 'Adoption aufheben' : 'Adoptiere diesen Baum');

	onMount(async () => {
		const user = await getCurrentUser();
		if (!user) return;

		authorized = true;

		adopted = await isTreeAdopted(tree.uuid, user.id);
	});

	const handleAdoptTree = async () => {
		const user = await getCurrentUser();
		if (!user) return;

		authorized = true;

		if (!user) {
			authorized = false;
			message = null;
			return;
		}
		authorized = true;
		try {
			const result = await toggleTreeAdoption(tree.uuid, user.id);
			adopted = result === 'adopted';
			message = adopted
				? 'Du hast diesen Baum erfolgreich adoptiert!'
				: 'Die Adoption wurde aufgehoben.';
			messageTone = 'success';
		} catch (err) {
			message =
				'Beim Adoptieren des Baumes ist ein Fehler aufgetreten. Hast du ihn vielleicht bereits adoptiert?';
			messageTone = 'warning';
		}
	};
</script>

{#if tree}
	<div class="flex flex-col gap-2">
		<Button
			variant={!authorized ? 'default' : adopted ? 'secondary' : 'primary'}
			disabled={!authorized}
			onClick={handleAdoptTree}
		>
			{label}
		</Button>

		{#if !authorized}
			<Notice tone="warning">Bitte einloggen, um diese Funktion zu nutzen.</Notice>
		{:else if message}
			<Notice tone={messageTone}>{message}</Notice>
		{/if}


		<Notice tone="info">
			Wenn du diesen Baum adoptierst, wird er in deinem Profil gespeichert und du findest ihn jederzeit wieder.
			Aktuell ist das nur eine symbolische Geste, es ist keine Verpflichtung damit verbunden. Wir arbeiten an weiteren Features. 
		</Notice>
	</div>
{/if}
