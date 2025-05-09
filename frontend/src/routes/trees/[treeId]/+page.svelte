<!--Seite für 1 individuellen Baum :) -->
<script lang="ts">
	import { Accordion, AccordionItem } from 'svelte-collapsible';
	import WaterColumn from '$components/WaterColumn.svelte';
	import Chat from '$features/chat/Chat.svelte';
	import OverlayPanel from '$components/layout/OverlayPanel.svelte';
	import AdoptTree from '$features/adoption/AdoptTree.svelte';
	import { supabase } from '$shared/api/supabase';
	import { onMount } from 'svelte';
	import { page } from '$app/stores';
	import type { Tree } from '$shared/types/tree';
	import TreeMetric from '$features/trees/TreeMetric.svelte';

	export let activeTabIndex: number = 0;

	function handleTabChange(tab: number) {
		activeTabIndex = tab;
	}

	$: showInfo = true;
	$: showChat = false;

	$: buttonLabels = ['Infos', 'Chat'];

	let tree: Tree;

	$: tree;

	onMount(async () => {
		const { data, error } = await supabase
			.from('trees')
			.select()
			.eq('uuid', $page.params.treeId)
			.maybeSingle();
		tree = data;
	});
</script>

{#if tree}
<OverlayPanel
	title={tree.tree_type_german}
	bind:open={showInfo}
	closeable
	on:close={() => history.back()}
	>
		<!-- svelte-ignore a11y-no-noninteractive-element-to-interactive-role -->

		<div slot="navigation">
			<nav
				id="single-tree-navigation"
				class="flex flex-col justify-center px-3 py-2 mb-4 text-base font-medium text-center bg-green-600 rounded-md shadow-sm bg-opacity-60 whitespace-nowrap"
				role="tablist"
				aria-label="Content sections"
			>
				<section class="relative flex items-center justify-between w-full">
					<div
						class={`absolute transition-transform ${activeTabIndex === 0 ? 'translate-x-0' : 'translate-x-full'} z-0 bg-white rounded h-[100%] shadow-[0px_1px_4px_rgba(0,0,0,0.15)] w-[50%]`}
					/>

					<button
						role="tab"
						aria-selected={activeTabIndex === 0}
						aria-controls="info-panel"
						class="flex-1 py-2 shrink gap-2.5 self-stretch my-auto ${showInfo
							? 'text-zinc-600'
							: 'text-neutral-500'} z-10"
						on:click={() => handleTabChange(0)}
						tabindex="0"
					>
						Infos
					</button>
					<button
						role="tab"
						aria-selected={activeTabIndex === 1}
						aria-controls="chat-panel"
						class="flex-1 py-2 shrink gap-2.5 self-stretch my-auto ${showChat
							? 'text-zinc-600'
							: 'text-neutral-500'} z-10"
						on:click={() => handleTabChange(1)}
						tabindex="0"
					>
						Chat
					</button>
				</section>
			</nav>
		</div>

		<div id="single-tree-content" class="flex flex-col h-full">
			<div class="flex flex-col gap-4 h-full">
				{#if activeTabIndex === 0}
					<Accordion>
						<div class="flex flex-col gap-4">
							<AccordionItem key="a">
								<div slot="header">
									<div class="inline-flex flex-row items-start gap-2.5">
										<p class="text-black font-cera-bielefeld text-base font-bold leading-normal">
											Über mich
										</p>
										<button class="translate-y-1.5">
											<img src="/trees/accordion-toggle.svg" alt="Toggle" />
										</button>
									</div>
								</div>
								<div
									slot="body"
									class="grid grid-cols-1 sm:grid-cols-3 gap-4 text-sm text-gray-800"
								>
									<TreeMetric label="Höhe" value={tree.height} unit="m" max={39} position="right" />
									<TreeMetric
										label="Kronendurchmesser"
										value={tree.crown_diameter}
										unit="m"
										max={29}
										position="top"
									/>
									<TreeMetric
										label="Stammdurchmesser"
										value={tree.trunk_diameter}
										unit="cm"
										max={297}
										position="bottom"
									/>
								</div>
							</AccordionItem>

							<AccordionItem key="b">
								<div slot="header">
									<div class="inline-flex flex-row items-start gap-2.5">
										<p class="text-black font-cera-bielefeld text-base font-bold leading-normal">
											Wasserbedarf
										</p>
										<button class="translate-y-1.5">
											<img src="/trees/accordion-toggle.svg" alt="Toggle" />
										</button>
									</div>
								</div>
								<p slot="body">
									Das ist eine Beispielansicht. Wir sind noch dabei, alle nötigen Date einzusammeln.
									<WaterColumn />
								</p>
							</AccordionItem>

							<AccordionItem key="c">
								<div slot="header">
									<div class="inline-flex flex-row items-start gap-2.5">
										<p class="text-black font-cera-bielefeld text-base font-bold leading-normal">
											Wer wann gegossen hat
										</p>
										<button class="translate-y-1.5">
											<img src="/trees/accordion-toggle.svg" alt="Plusbutton" />
										</button>
									</div>
								</div>
								<p slot="body">Hier werden die letzten 10 Gießungen angezeigt</p>
							</AccordionItem>
						</div>
					</Accordion>

					<AdoptTree {tree} />
				{:else}
					<Chat treeId={tree.uuid} />
				{/if}
			</div>
		</div>
	</OverlayPanel>
{/if}
