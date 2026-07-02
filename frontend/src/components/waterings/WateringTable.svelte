<script lang="ts">
	// Types
	import type { Watering } from '$types/watering';

	// Libs & Helpers
	import { formatDate } from '$lib/utils/formatDate';
	import { waterEmoji } from '$lib/waterings';

	// UI
	import { Notice } from '$components/ui';

	// Lifecycle
	import { onDestroy } from 'svelte';

	
	interface Props {
		// Props
		waterings?: Watering[];
		currentUserId?: string | null;
		mode?: 'tree' | 'user';
		treeButton?: import('svelte').Snippet<[any]>;
		deleteButton?: import('svelte').Snippet<[any]>;
	}

	let {
		waterings = [],
		currentUserId = null,
		mode = 'tree',
		treeButton,
		deleteButton
	}: Props = $props();

	// Warning logic
	let warningMessage: string | null = $state(null);
	let activeWarningId: string | null = $state(null);
	let warningTimeout: ReturnType<typeof setTimeout> | null = null;

	function setWarning(msg: string, id: string) {
		warningMessage = msg;
		activeWarningId = id;

		if (warningTimeout) clearTimeout(warningTimeout);
		warningTimeout = setTimeout(() => {
			warningMessage = null;
			activeWarningId = null;
			warningTimeout = null;
		}, 5000);
	}

	onDestroy(() => {
		if (warningTimeout) clearTimeout(warningTimeout);
	});
</script>

<table class="w-full text-sm text-left border-separate border-spacing-y-1 mt-3 hidden md:table">
	<thead class="text-gray-500 text-xs tracking-wide font-medium">
		<tr>
			<th class="px-3 py-2">🗓️ Datum</th>
			<th class="px-3 py-2">🚰 Liter</th>
			<th class="px-3 py-2">🚿 Gießkraft</th>
			{#if mode === 'tree'}
				<th class="px-3 py-2">👤 Durch</th>
			{:else}
				<th class="px-3 py-2">🌳 Baum</th>
			{/if}
			<th class="px-3 py-2">⚙ Aktion</th>
		</tr>
	</thead>

	<tbody>
		{#each waterings as w}
			<tr
				class="bg-white shadow-sm rounded-md transition duration-300 ease-in-out hover:bg-gray-50"
			>
				<td class="px-3 py-2">{formatDate(w.watered_at)}</td>
				<td class="px-3 py-2">{w.amount_liters}</td>
				<td class="px-3 py-2">{waterEmoji(w.amount_liters)}</td>

				<td class="px-3 py-2">
					{#if mode === 'tree'}
						<em>{currentUserId && w.user_uuid === currentUserId ? 'Du' : 'anonym'}</em>
					{:else}
						{@render treeButton?.({ watering: w, setWarning, })}
					{/if}
				</td>

				<td class="px-3 py-2">
					{#if currentUserId && w.user_uuid === currentUserId}
						{@render deleteButton?.({ watering: w, })}
					{:else}
						<em>-</em>
					{/if}
				</td>
			</tr>
			{#if w.uuid === activeWarningId && warningMessage}
				<tr>
					<td colspan="5" class="px-3 py-2">
						<Notice tone="warning">{warningMessage}</Notice>
					</td>
				</tr>
			{/if}
		{/each}
	</tbody>
</table>
