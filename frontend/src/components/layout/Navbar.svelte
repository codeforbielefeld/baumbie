<script lang="ts">
	import { goto } from '$app/navigation';

	$: isOpen = false;

	async function handleButtonbarClick(buttonType: string): Promise<void> {
		let url = '';
		switch (buttonType) {
			case 'accountButton':
				url = '/account';
				break;
			case 'baumButton':
				url = '/status';
				break;
			case 'lupeButton':
				url = '/search';
				break;
		}
		if (isOpen) {
			if (window.location.pathname == url) {
				await goto('/');
				isOpen = !isOpen;
			} else {
				goto(url);
				isOpen = true;
			}
		} else {
			await goto(url);
			isOpen = true;
		}
	}
</script>

<footer class="fixed bottom-0 left-0 right-0 z-[700] bg-white flex justify-around items-center py-4 min-h-16">
	<button on:click={() => handleButtonbarClick('accountButton')}
	><img src="/navbar/settings.svg" class="w-8 h-8" alt="" /></button
	>
	<button on:click={() => handleButtonbarClick('baumButton')}
	><img src="/navbar/tree-status.svg" class="w-8 h-8" alt="" /></button
	>
	<button on:click={() => handleButtonbarClick('lupeButton')}
	><img src="/navbar/search.svg" class="w-8 h-8" alt="" />
	</button>
</footer>
