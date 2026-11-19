<script lang="ts">
	type SearchItem = string | object;

	interface Props {
		id?: string;
		items?: SearchItem[];
		labelKey?: string;
		valueKey?: string;
		getLabel?: (item: SearchItem) => string;
		getValue?: (item: SearchItem) => string;
		value?: string;
		placeholder?: string;
		clearOnSelect?: boolean;
		showSuggestions?: boolean;
		maxResults?: number;
		itemHeight?: number;
		listHeight?: number;
		suggestionsLabel?: string;
		noResultsText?: string;
		onFocus?: () => void;
		onInput?: (value: string) => void;
		onSelect?: (item: SearchItem) => void;
		onEnter?: (event: KeyboardEvent) => void;
	}

	let {
		id = 'searchfield-input',
		items = [],
		labelKey = 'label',
		valueKey = 'value',
		getLabel: getLabelProp,
		getValue: getValueProp,
		value = $bindable(''),
		placeholder = 'Suchen ...',
		clearOnSelect = true,
		showSuggestions = true,
		maxResults = 1000,
		itemHeight = 44,
		listHeight = 264,
		suggestionsLabel = 'Suchvorschläge',
		noResultsText = 'Keine passenden Vorschläge',
		onFocus = () => {},
		onInput = () => {},
		onSelect = () => {},
		onEnter = () => {}
	}: Props = $props();

	let isOpen = $state(false);
	let highlightedIndex = $state(0);
	let scrollTop = $state(0);
	let listElement = $state<HTMLDivElement>();

	const filteredItems = $derived(
		items
			.filter((item) => getItemLabel(item).toLocaleLowerCase().includes(value.trim().toLocaleLowerCase()))
			.slice(0, maxResults)
	);
	const visibleCount = $derived(Math.ceil(listHeight / itemHeight) + 2);
	const startIndex = $derived(Math.max(0, Math.floor(scrollTop / itemHeight) - 1));
	const visibleItems = $derived(filteredItems.slice(startIndex, startIndex + visibleCount));
	const contentHeight = $derived(filteredItems.length * itemHeight);

	function getItemLabel(item: SearchItem): string {
		if (getLabelProp) return getLabelProp(item);
		if (typeof item === 'string') return item;
		const objectItem = item as Record<string, unknown>;
		return String(objectItem[labelKey] ?? objectItem[valueKey] ?? '');
	}

	function getItemValue(item: SearchItem): string {
		if (getValueProp) return getValueProp(item);
		if (typeof item === 'string') return item;
		const objectItem = item as Record<string, unknown>;
		return String(objectItem[valueKey] ?? getItemLabel(item));
	}

	function selectItem(item: SearchItem) {
		onSelect(item);
		if (clearOnSelect) value = '';
		isOpen = false;
		highlightedIndex = 0;
	}

	function moveHighlight(direction: 1 | -1) {
		if (!filteredItems.length) return;
		highlightedIndex =
			(highlightedIndex + direction + filteredItems.length) % filteredItems.length;
		ensureHighlightedItemVisible();
	}

	function ensureHighlightedItemVisible() {
		if (!listElement) return;
		const top = highlightedIndex * itemHeight;
		const bottom = top + itemHeight;
		if (top < listElement.scrollTop) listElement.scrollTop = top;
		if (bottom > listElement.scrollTop + listHeight) {
			listElement.scrollTop = bottom - listHeight;
		}
	}

	function handleKeydown(event: KeyboardEvent) {
		if (!showSuggestions) {
			if (event.key === 'Enter' && !event.isComposing && !event.repeat) onEnter(event);
			return;
		}

		if (event.key === 'ArrowDown') {
			event.preventDefault();
			isOpen = true;
			moveHighlight(1);
		} else if (event.key === 'ArrowUp') {
			event.preventDefault();
			isOpen = true;
			moveHighlight(-1);
		} else if (event.key === 'Enter' && isOpen && filteredItems[highlightedIndex]) {
			event.preventDefault();
			selectItem(filteredItems[highlightedIndex]);
		} else if (event.key === 'Escape') {
			isOpen = false;
		}
	}

	function handleInput() {
		onInput(value);
		isOpen = showSuggestions;
		highlightedIndex = 0;
		scrollTop = 0;
		if (listElement) listElement.scrollTop = 0;
	}
</script>

<div class="relative w-full">
	<label class="sr-only" for={id}>{placeholder}</label>
	<input
		{id}
		class="w-full rounded-lg border border-gray-400 bg-white px-4 py-3 text-gray-900 shadow-sm outline-none transition focus:border-green-700 focus:ring-2 focus:ring-green-200"
		{placeholder}
		autocomplete="off"
		role="combobox"
		aria-expanded={showSuggestions && isOpen}
		aria-controls="searchfield-listbox"
		aria-autocomplete="list"
		bind:value
		onfocus={() => {
			onFocus();
			isOpen = showSuggestions;
		}}
		oninput={handleInput}
		onkeydown={handleKeydown}
	/>

	{#if showSuggestions && isOpen && filteredItems.length > 0}
		<div
			id="searchfield-listbox"
			class="absolute z-20 mt-1 w-full overflow-hidden rounded-lg border border-gray-300 bg-white shadow-lg"
			role="listbox"
			aria-label={suggestionsLabel}
		>
			<div
				bind:this={listElement}
				class="overflow-y-auto"
				style={`height: ${listHeight}px`}
				onscroll={(event) => (scrollTop = (event.currentTarget as HTMLDivElement).scrollTop)}
			>
				<div style={`height: ${contentHeight}px; position: relative`}>
					{#each visibleItems as item, visibleIndex (getItemValue(item))}
						{@const itemIndex = startIndex + visibleIndex}
						<button
							type="button"
							class={`absolute left-0 w-full px-4 text-left text-sm ${
								itemIndex === highlightedIndex ? 'bg-green-50 text-green-900' : 'bg-white text-gray-800'
							}`}
							style={`top: ${itemIndex * itemHeight}px; height: ${itemHeight}px`}
							role="option"
							aria-selected={itemIndex === highlightedIndex}
							onmouseenter={() => (highlightedIndex = itemIndex)}
							onclick={() => selectItem(item)}
						>
							{getItemLabel(item)}
						</button>
					{/each}
				</div>
			</div>
		</div>
	{:else if showSuggestions && isOpen && value.trim()}
		<div class="absolute z-20 mt-1 w-full rounded-lg border border-gray-300 bg-white px-4 py-3 text-sm text-gray-500 shadow-lg">
			{noResultsText}
		</div>
	{/if}
</div>