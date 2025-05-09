<script>
	import { Accordion, AccordionItem } from 'svelte-collapsible';
	// import WaterAlert from "svelte-material-icons/WaterAlert.svelte";
	// import Water from "svelte-material-icons/Water.svelte";
	// import WaterPlusOutline from "svelte-material-icons/WaterPlusOutline.svelte";
	import WaterAlertOutline from 'svelte-material-icons/WaterAlertOutline.svelte';
	import { goto } from '$app/navigation';

	export let tree_id;
	export let tree_type;
	export let tree_name;
	export let tree_age;
	export let tree_description;

	export let rain_30_days;
	export let water_requirement_30_days;
	export let watering_30_days;

	// let additional_water_required;

	let water_total = 0.0;
	$: water_total = rain_30_days + watering_30_days;

	let additional_water_required = 0.0;
	$: additional_water_required = water_requirement_30_days - water_total;

	const water_tree = () => {
		let url = 'http://localhost:5173/tree/' + tree_id + '/watering';
		goto(url);
	};

	const adopt_tree = () => {
		let url = 'http://localhost:5173/tree/' + tree_id + '/adoption';
		goto(url);
	};
</script>

<div class="card">
	<h1>
		Bauminformation
		<br />
		{tree_name}
	</h1>

	<Accordion>
		<AccordionItem key="baumart">
			<h2 slot="header">
				{tree_type}
			</h2>
			<div slot="body">
				{tree_description}
			</div>
		</AccordionItem>
		<hr />
		<AccordionItem key="chat">
			<h2 slot="header">Chat</h2>
			<div slot="body">Hier kommt was zum Chat rein ...</div>
		</AccordionItem>
		<hr />
		<AccordionItem key="alter">
			<h2 slot="header">Standalter</h2>
			<div slot="body">
				Wurde hier vor {tree_age} Jahren eingepflanzt.
			</div>
		</AccordionItem>
		<hr />
		<AccordionItem key="wasserbedarf">
			<h2 slot="header">Wasserbedarf</h2>
			<div slot="body">
				{tree_name} braucht im Monat {water_requirement_30_days} l Wasser.
			</div>
		</AccordionItem>
		<hr />
		<AccordionItem key="wassermenge">
			<div slot="header" style="text-align: left;">
				<h2>Wassermenge</h2>
				<p>der letzten 30 Tage</p>
				<p>Gießungen: {watering_30_days}</p>
				<p>Regen: {rain_30_days}</p>
			</div>
			<div slot="body">
				<p>{tree_name} hat diesen Monat insgesamt {water_total} l Wasser bekommen.</p>
				<p>
					Davon gehen {rain_30_days} l Wasser gehen auf Regen und {watering_30_days} auf Gießungen zurück.
				</p>
				{#if water_total >= water_requirement_30_days}
					<p>{tree_name} hat mehr als genug Wasser bekommen.</p>
				{:else}
					<p>
						<WaterAlertOutline />
						{tree_name} braucht noch {additional_water_required} l Wasser. Bitte gieß {tree_name}!
						<WaterAlertOutline />
					</p>
				{/if}
			</div>
		</AccordionItem>
	</Accordion>

	<hr />

	<div class="flex-container" style="text-align: center; align-items: center">
		<button on:click={water_tree}>Ich habe gegossen!</button>

		<button on:click={adopt_tree}>Baum adoptieren</button>

		<a href="https://codefor.de/bielefeld/">Wie kann ich mitmachen?</a>
	</div>
</div>

<style>
	h1 {
		font-size: 32px;
	}

	h2 {
		font-size: 24px;
	}

	.card {
		box-shadow: rgba(0, 0, 0, 0.24) 0px 3px 8px;
		background-color: white;
		color: black;
		padding: 10px;
		margin: 10px;
	}

	.flex-container {
		display: flex;
		flex-direction: column;
	}
</style>
