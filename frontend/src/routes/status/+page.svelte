<script lang="ts">
	import { onMount } from 'svelte';
	import { PanelSection, Notice } from '$components/ui';
	import { DialogPanel } from '$components/overlay';
	import { AdoptedTrees, NearbyTrees, UserWaterings } from '$components/status';
	import { getCurrentUser } from '$lib/supabase';

	import type { User } from '@supabase/supabase-js';

	let currentUser: User | null = null;
	let loadingUser = true;

	onMount(async () => {
		currentUser = await getCurrentUser();
		loadingUser = false;
	});
</script>

<DialogPanel title={'Mein Bereich'} open={true}>
	<div class="pt-6 pb-6 space-y-6">
		<PanelSection title="Bäume in meiner Nähe">
			<NearbyTrees />
		</PanelSection>
		{#if loadingUser}
			<Notice tone="info">Benutzer wird geladen …</Notice>
		{:else}
			<PanelSection title="Meine adoptierten Bäume">
				<AdoptedTrees {currentUser} />
			</PanelSection>

			<PanelSection title="Meine Gießfortschritte">
				<UserWaterings {currentUser} />
			</PanelSection>
		{/if}
	</div>
</DialogPanel>
