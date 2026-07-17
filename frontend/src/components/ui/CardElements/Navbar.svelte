<script type="ts">
    let {
        categories = {},
        onCategorySelect = () => {},
    } = $props();

    const categoryKeys = $derived(Object.keys(categories));
    let activeCategory = $state('');
    let buttonRefs = $state({});

    const selectCategory = (key) => {
        activeCategory = key;
        onCategorySelect({
            category: key,
            label: categories[key].label
        });
        
        // Auto-scroll den aktiven Button in den sichtbaren Bereich
        if (buttonRefs[key]) {
            setTimeout(() => {
                buttonRefs[key]?.scrollIntoView({ behavior: 'smooth', block: 'nearest', inline: 'center' });
            }, 0);
        }
    }

    // Initialize with first category
    $effect(() => {
        if (categoryKeys.length > 0 && !activeCategory) {
            selectCategory(categoryKeys[0]);
        }
    });
</script>

<div class="flex flex-row w-full overflow-x-auto">
    {#each categoryKeys as category}
        <button 
            bind:this={buttonRefs[category]}
            onclick={() => selectCategory(category)}
            class="flex items-center px-4 py-3
                    sm:w-32 md:w-40 lg:w-48
                    flex-shrink-0
                    cursor-pointer
                    rounded-tl-lg rounded-tr-lg
                    transition-colors text-center"
            class:hover:bg-gray-200={activeCategory !== category}
            class:text-green-600={activeCategory === category}
            class:bg-white={activeCategory === category}
            class:text-gray-700={activeCategory !== category}>
            <div class="w-4 h-4 rounded-full flex-shrink-0 mr-2"
                 class:bg-green-600={activeCategory === category}
                 class:bg-gray-300={activeCategory !== category}></div>
            <span class="text-sm font-medium">{categories[category].label}</span>
        </button>
    {/each}
</div>

<style>
    ::-webkit-scrollbar { 
        display: none; 
        }
</style>