<script lang="ts">
	import { goto } from '$app/navigation';
	import { onMount } from 'svelte';
	import PrimaryButton from '$components/ui/button/PrimaryButton.svelte';
	import { supabase } from '$shared/api/supabase';

	let loggedIn = false;

	$: loggedIn;

	onMount(async () => {
		return supabase.auth.onAuthStateChange((state, data) => {
			console.log(state, data?.user);
			if (state === 'SIGNED_IN') {
				loggedIn = true;
			}
		});
	});
</script>

<div class="z-[1100] m-8">
	{#if loggedIn}
		<div class="flex flex-row items-center space-x-4 group">
			<img
				class="w-12 h-12 border-2 border-green-500 rounded-full"
				src="https://gravatar.com/avatar/f01f7e9c657f966821e915bb022df497?s=400"
			/>
			<div
				class="w-0 overflow-hidden text-xl transition-[width] ease-in-out duration-500 delay-50 group-hover:w-48"
			>
				<div class="width-48 whitespace-nowrap">Daniel Baron</div>
			</div>
		</div>
	{:else}
		<PrimaryButton label="Anmelden" onClick={() => goto('/login')} />
	{/if}
</div>
