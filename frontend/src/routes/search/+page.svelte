<script lang="ts">
	import OverlayPanel from "$components/layout/OverlayPanel.svelte";
	import Heading from "$components/ui/Heading.svelte";
    import BaseButton from "$components/ui/button/BaseButton.svelte";
	import DefaultButton from "$components/ui/button/DefaultButton.svelte";
	import LinkButton from "$components/ui/button/LinkButton.svelte";
	import PrimaryButton from "$components/ui/button/PrimaryButton.svelte";
	import SecondaryButton from "$components/ui/button/SecondaryButton.svelte";

	let open = true;

</script>

<OverlayPanel title="Bäume filtern" bind:open={open} closeable>
	<Heading level={1}>Bäume filtern</Heading>

	<div>Standort filtern</div>
	<div>Nach Alter filtern</div>
	<div>Nach Wasserbedarf filtern</div>

	<div>
		<Heading level={2}>Deine adoptierten Bäume</Heading>
		<BaseButton label="Base" />
		<LinkButton label="Link" />
		<DefaultButton label="Default" icon_src="/icons/tree.svg" icon_alt="Baum" />
		<PrimaryButton label="Primary" />
		<SecondaryButton label="Secondary" />
	</div>
</OverlayPanel>