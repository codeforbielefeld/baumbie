<script lang="ts">
	import { run } from 'svelte/legacy';

	import type { Message } from '../../types/chat';
	import parseMarkdown from '$lib/utils/parseMarkdown';


	// console.log('BotMessage received:', message);

	

	interface Props {
		message: Message;
		/*
	DEBUG: Testnachricht mit eingebautem <script>-Tag zur Prüfung von Markdown-Parsing und XSS-Schutz.
	Das <script>-Tag ist bewusst aufgetrennt, damit der Svelte-Compiler es nicht als echtes Tag interpretiert.
	Kann verwendet werden, um parseMarkdown() + DOMPurify live im UI zu verifizieren.
	
	const debugMessage: Message = {
		text: '**Hallo**\n_Baum_<script' + '>alert("xss")<' + '/script>',
		type: 'text',
		ai: true,
	};
	
	message = debugMessage; // zum Aktivieren auskommentieren
	*/
		sendMessage: (text: string) => void;
	}

	let { message, sendMessage }: Props = $props();

	let htmlText: string | null = $state(null);
	let lastMessageText = $state('');
	let selectedLabel: string | null = $state(null);

	run(() => {
		if (message?.text && message.text !== lastMessageText) {
			const current = message.text;
			lastMessageText = current;

			parseMarkdown(current).then((result) => {
				if (message.text === current) htmlText = result;
			});
		}
	});

	function handleClick(label: string) {
		if (selectedLabel !== null || message.type !== 'choice') return;
		selectedLabel = label;
		sendMessage(label);
	}
</script>

<div class="flex gap-1.5 flex-row w-full bot-message">
	<div class="pt-2">
		<img
			src={message.ai ? '/chat/tree-ai.svg' : '/icons/tree.svg'}
			alt="Bot"
			class="min-w-8 min-h-8"
		/>
	</div>
	<div class="w-full flex flex-row">
		{#if htmlText}
			<div
				class="shrink box-border p-3 text-black rounded-xl bg-message-bot max-w-[80%] md:max-w-[70%]"
			>
				{@html htmlText}
				<!--
					Debug-Ausgabe: zeigt das generierte HTML aus parseMarkdown()
					<pre class="mt-4 text-xs text-gray-500">{htmlText}</pre>
				-->
				{#if message.ai}
					<span class="inline-block float-right mt-2 text-xs text-gray-400">KI-generiert</span>
					<div class="clear-both"></div>
				{/if}
			</div>
		{:else if message.buttons}
			<div class="flex flex-col gap-2 mt-1">
				{#each message.buttons ?? [] as button}
					<button
						class="box-border px-3 py-5 text-black rounded-xl text-left transition-all duration-200"
						class:bg-green-500={selectedLabel === button.label}
						class:bg-gray-300={selectedLabel !== button.label}
						class:opacity-50={selectedLabel !== null && selectedLabel !== button.label}
						class:hover:bg-green-400={selectedLabel === null}
						disabled={selectedLabel !== null}
						onclick={() => handleClick(button.label)}
					>
						{button.label}
					</button>
				{/each}
			</div>
		{/if}
	</div>
</div>
