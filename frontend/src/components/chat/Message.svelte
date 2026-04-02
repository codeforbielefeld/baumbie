<script lang="ts">
	import BotMessage from './BotMessage.svelte';
	import UserMessage from './UserMessage.svelte';
	import type { Message as MessageType } from '../../types/chat';

	export let message: MessageType;
	export let sendMessage: (text: string) => void;
</script>

<div class="message flex flex-row w-full">
	{#if message.role === 'assistant'}
		<BotMessage {message} {sendMessage} />
	{:else if message.role === 'user'}
		<UserMessage {message} />
	{/if}
</div>
