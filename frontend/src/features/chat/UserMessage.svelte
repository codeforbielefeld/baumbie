<script lang="ts">
	import type { Message as MessageType } from '$shared/types/chat';

	export let message: MessageType;
</script>

<div class="flex gap-1.5 flex-row w-full flex-end">
	<div class="flex w-full justify-end">
		<div class="p-3 text-black rounded-xl bg-message-user box-border max-w-[80%] md:max-w-[70%]">
			{message.text}
		</div>
	</div>
	<div class="pt-2">
		<img src="/chat/user.svg" alt="Bot" class="min-w-8 min-h-8" />	
	</div>
</div>