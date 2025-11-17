<script lang="ts">
	export let label: string;
	export let value: number;
	export let unit: string;
	export let max: number;
	export let position: 'top' | 'right' | 'bottom';

	$: percent = Math.min(100, Math.max(0, (value / max) * 100));
</script>

<div class="snap-center shrink-0 w-52 sm:w-56 md:w-auto">
	<div
		class="relative grid grid-cols-2 items-center gap-4 px-4 py-5 rounded-xl border border-zinc-200 bg-white text-left shadow-sm"
	>
		<!-- Linke Spalte: Icon + Balken -->
		<div class="relative flex justify-center items-center w-full h-14 text-green-600">
			<svg
				xmlns="http://www.w3.org/2000/svg"
				viewBox="0 0 24 24"
				fill="none"
				class="w-full h-full animate-pulse-slow"
				stroke="currentColor"
			>
				<path
					d="M12 22.25L12 15.25M12 10V14.25M12 15.25L14.5 12.75M12 15.25L12 14.25M12 14.25L9.75 12.5"
					stroke-width="2"
					stroke-linecap="round"
					stroke-linejoin="round"
				/>
				<path
					d="M17.9653 6.50909V6.53612L17.9667 6.56312C18.1359 9.68991 17.6603 12.6963 16.5425 14.8368C15.4492 16.9303 13.8005 18.1265 11.4806 17.9893C10.9592 17.9584 10.3515 17.6981 9.69557 17.1696C9.04588 16.6462 8.4103 15.9076 7.84918 15.0444C6.71093 13.2934 6 11.2225 6 9.76145C6 8.30523 6.70627 6.30887 7.83436 4.65928C8.3906 3.84589 9.01891 3.16298 9.65873 2.69222C10.3021 2.21888 10.9002 2 11.4215 2C12.8361 2 14.5348 2.46694 15.857 3.3114C17.1826 4.15805 17.9653 5.26409 17.9653 6.50909Z"
					stroke-width="2"
					stroke-linecap="round"
					stroke-linejoin="round"
				/>
			</svg>

			<!-- Fortschrittsbalken je nach Position -->
			{#if position === 'right'}
				<div class="absolute top-0 bottom-0 right-[10px] w-[5px] h-14 bg-gray-200 rounded">
					<div
						class="absolute bottom-0 left-0 w-full bg-green-600 rounded"
						style="height: {percent}%;"
					/>
				</div>
			{:else if position === 'top'}
				<div
					class="absolute top-[-10px] left-1/2 transform -translate-x-1/2 h-[5px] w-14 bg-gray-200 rounded"
				>
					<div
						class="absolute top-0 left-0 h-full bg-green-600 rounded"
						style="width: {percent}%; left: {50 - percent / 2}%;"
					/>
				</div>
			{:else if position === 'bottom'}
				<div
					class="absolute bottom-[-10px] left-1/2 transform -translate-x-1/2 h-[5px] w-14 bg-gray-200 rounded"
				>
					<div
						class="absolute top-0 left-0 h-full bg-green-600 rounded"
						style="width: {percent}%; left: {50 - percent / 2}%;"
					/>
				</div>
			{/if}
		</div>

		<!-- Rechte Spalte: Text -->
		<div class="flex flex-col items-center justify-center text-center w-full">
			<p class="text-xs text-gray-500 leading-tight">
				{#if label === 'Kronendurchmesser'}
					Kronen-<br />durchmesser
				{:else if label === 'Stammdurchmesser'}
					Stamm-<br />durchmesser
				{:else}
					{label}
				{/if}
			</p>
			<p class="text-sm font-semibold text-gray-800 mt-1">
				{value}
				{unit}
			</p>
		</div>
	</div>
</div>

<style>
	@keyframes pulseSlow {
		0%,
		100% {
			transform: scale(1);
			opacity: 1;
		}
		50% {
			transform: scale(1.06);
			opacity: 0.85;
		}
	}
	.animate-pulse-slow {
		animation: pulseSlow 3s ease-in-out infinite;
	}
</style>
