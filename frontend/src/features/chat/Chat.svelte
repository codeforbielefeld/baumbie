<script lang="ts">
	// === Imports ===
	import { onMount } from 'svelte';
	import { supabase } from '$shared/api/supabase';
	import Message from './Message.svelte';
	import type { Message as MessageType, RawMessage } from '$shared/types/chat';

	// === Props ===
	export let treeId: string = '';
	$: treeId;
	console.log('Chat got Tree ID: ', treeId);
	
	// === State ===
	let sessionId: string = '';
	let messages: MessageType[] = [];
	let newMessage: string = '';
	let chatAvailable: boolean = true;
	

	let endRef: HTMLDivElement;


	// === Lifecycle ===
	onMount(() => {
		if (!treeId) {
			console.error('No treeId provided');
			return;
		}
		supabase.functions
			.invoke('chat', {
				body: {
					treeId
				}
			})
			.then(handleNewChatMessages);
	});

	// === Helpers ===
	const handleNewChatMessages = (response: unknown) => {
		// console.log("📦 RAW Voiceflow Response:", JSON.stringify(response, null, 2));
		if (
			typeof response !== 'object' ||
			response === null ||
			!('data' in response) ||
			!('error' in response)
		) {
			console.error('Invalid response structure:', response);
			return;
		}

		const { data, error } = response as { data: any; error: any };

		if (error !== null) {
			console.error('Error fetching chat messages:', error);
			return;
		}

		sessionId = data.sessionId;
		messages = [
			...messages,
			...data.messages
				.filter((msg: RawMessage) => !['no-reply', 'path'].includes(msg.type))
				.map((msg: RawMessage): MessageType => {
					const buttons = Array.isArray(msg.payload?.buttons)
						? msg.payload!.buttons!.map((btn: { name: string; request: any }) => ({
								label: btn.name,
								request: btn.request
							}))
						: [];

					return {
						text: msg.payload?.message ?? '',
						label: '',
						type: msg.payload?.type ?? msg.type,
						sender: 'bot',
						buttons,
						ai: msg.payload?.ai === true
					};
				})
		];
	};

	function sendMessage(text: string) {
		if (text === '') {
			return;
		}
		const newUserMessage: MessageType = {
			text,
			label: '',
			type: 'text',
			sender: 'user'
		};

		messages = [...messages, newUserMessage];

		supabase.functions
			.invoke('chat', {
				body: {
					sessionId,
					text
				}
			})
			.then(handleNewChatMessages);

		newMessage = '';
	}

	function handleKeydown(event: KeyboardEvent) {
		if (event.key === 'Enter' && newMessage !== '') {
			sendMessage(newMessage);
		}
	}

	$: {
		if (endRef && messages.length > 0) {
			queueMicrotask(() => {
				endRef.scrollIntoView({ behavior: 'smooth' });
			});
		}
	}


	$: console.log('↪ newMessage:', JSON.stringify(newMessage));
</script>

<!-- Chat innerhalb der Card -->
<div id="chat-container" class="flex flex-col h-full min-h-0">
	 <!--
	TODO für später: transparenten Verlauf umsetzen
	<div class="sticky top-0 min-h-12 h-12 w-100 bg-gradient-to-b from-red-800 z-[9999999]"></div>
	-->
	<!-- Nachrichtenbereich -->
	
	<div class="flex flex-col grow overflow-y-auto gap-y-1 min-h-0">
		{#each messages as message}
			<Message {message} {sendMessage} />
		{/each}
		<div bind:this={endRef} class="min-h-3"></div>
	</div>

	<!-- Eingabe -->
	<div class="sticky bottom-0 bg-white p-3 border-t z-[10] border-t-gray-500">
		<div class="flex flex-row gap-2">
			<input
				type="text"
				bind:value={newMessage}
				class="px-3 py-1 bg-green-500 rounded-full grow placeholder:text-neutral-500 placeholder:italic"
				placeholder={chatAvailable ? '' : 'Chat beendet.'}
				on:keyup={handleKeydown}
				disabled={!chatAvailable}
			/>
			<button
				class="shrink"
				on:click={() => newMessage && sendMessage(newMessage)}
				disabled={!chatAvailable}
			>
				<img src="/chat/send.svg" class="w-8 h-8" alt="senden" />
			</button>
		</div>
	</div>
</div>
