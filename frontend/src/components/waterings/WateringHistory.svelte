<script lang="ts">
	// Svelte intern
	import { createEventDispatcher } from 'svelte';

	// UI-Komponenten
	import { Notice } from '$components/ui';
	import WateringCard from './WateringCard.svelte';
	import WateringTable from './WateringTable.svelte';
	import DeleteWateringButton from './DeleteWateringButton.svelte';
	import { FlyToTreeButton } from '$components/actions';

	// Utilities & Typen
	import { isMobile } from '$lib/utils/media';
	import type { Watering } from '$types/watering';

	

	

	// Optional: Map für benutzerdefinierte Labels je Baum-UUID.
	// Ermöglicht eine schnellere Anzeige, da der Button nicht selbst nachladen muss.
	// Diese Komponente benötigt sie nicht zwingend – sie zeigt Nutzer-Gießungen an –
	

	
	interface Props {
		// Liste der Gießvorgänge
		waterings?: Watering[];
		// ID des aktuell eingeloggten Nutzers (zur Rechteprüfung)
		currentUserId?: string | null;
		// aber die zusätzliche Prop kann zur Optimierung der Darstellung genutzt werden.
		labelsByTreeId?: Map<string, string>;
		// Modus zur Darstellung (z.B. zeigt in "user"-Modus den Baum statt den Gießer an)
		mode?: 'tree' | 'user';
	}

	let {
		waterings = [],
		currentUserId = null,
		labelsByTreeId = new Map(),
		mode = 'tree'
	}: Props = $props();

	const dispatch = createEventDispatcher();
</script>

{#if waterings.length === 0}
	<Notice tone="info">Bisher wurden noch keine Gießungen für diesen Baum eingetragen.</Notice>
{:else if $isMobile}
	<!-- 📱 Mobile Darstellung -->
	<div class="mt-3 space-y-3">
		{#each waterings as watering}
			<WateringCard {watering} {mode} {currentUserId}>
				{#snippet treeButton({ watering, setWarning })}
									
						<FlyToTreeButton
							treeId={watering.tree_uuid}
							label={labelsByTreeId.get(watering.tree_uuid)}
							on:warning={(e) => setWarning(e.detail.message)}
						/>
					
									{/snippet}

				{#snippet deleteButton({ watering })}
									
						<DeleteWateringButton {watering} on:reload={() => dispatch('reload')} />
					
									{/snippet}
			</WateringCard>
		{/each}
	</div>
{:else}
	<!-- 💻 Desktop/Tabletdarstellung -->
	<WateringTable {waterings} {currentUserId} {mode}>
		{#snippet treeButton({ watering, setWarning })}
					
				<FlyToTreeButton
					treeId={watering.tree_uuid}
					label={labelsByTreeId.get(watering.tree_uuid)}
					on:warning={(e) => setWarning?.(e.detail.message, watering.uuid)}
				/>
			
					{/snippet}

		{#snippet deleteButton({ watering })}
					
				<DeleteWateringButton {watering} on:reload={() => dispatch('reload')} />
			
					{/snippet}
	</WateringTable>
{/if}
