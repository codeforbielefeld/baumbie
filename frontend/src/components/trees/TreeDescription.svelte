<script lang="ts">
	import { Notice, PanelSection } from '$components/ui';
	import parseMarkdown from '$lib/utils/parseMarkdown';
	export let description: string | null = null;

	const defaultDescription =
		'**Wow – du hast einen von ganz wenigen entdeckt!**<br><br>Ich bin eine echte *Rarität* in Bielefeld. Aber wer mich einmal sieht, erinnert sich.<br><br>Vielleicht entdeckst du ja noch mehr meiner Art?';

	let renderedDescription = '';

	$: description,
		(async () => {
			renderedDescription = await parseMarkdown(description ?? defaultDescription);
		})();
</script>

<PanelSection>
	<Notice tone="info">
		{@html renderedDescription}
	</Notice>
</PanelSection>
