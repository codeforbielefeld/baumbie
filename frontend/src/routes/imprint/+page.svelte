<script lang="ts">
	import OverlayPanel from '$components/layout/OverlayPanel.svelte';
	import { goto } from '$app/navigation';

	let open = true;
</script>

<OverlayPanel
	title="Impressum"
	bind:open={open}
	closeable
	on:close={() => goto('/')}
>
	<p class="mt-4">
		<strong>Vereinsadresse</strong><br />
		Code for Bielefeld e.V.<br />
		℅ codecentric AG<br />
		Dr. Meike Wocken<br />
		Obernstr. 2<br />
		33602 Bielefeld
	</p>

	<p class="mt-4">
		<strong>Vereinsregister</strong><br />
		Vereinsregister des Amtsgerichts Bielefeld, VR4790<br />
		Der Verein Code for Bielefeld e.V. betreibt die Webseite www.bodenfeuchte.org mit dazugehörigen Unterseiten.
	</p>

	<p class="mt-4">
		E-Mail: teuto.bodensensor@gmail.com<br />
		Telefon: +49 1577 7576 508
	</p>
</OverlayPanel>