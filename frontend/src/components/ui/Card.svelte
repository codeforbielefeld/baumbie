<script lang="ts">
    import Navbar from './CardElements/Navbar.svelte';
    import Carousel from './CardElements/Carousel.svelte';
    let {type = "tree",
        data = {},
        onClose = () => {},
        categories = {}
    } = $props();

    function closeCard() {
        onClose();
    }

    let title = $derived(type === "tree" ?
        data.tree_type_german || "Unbekannter Baum"
        : "Unbekannter Datentyp");

    let selectedCategoryLabel = $state('');

    function handleCategorySelect(event: {category: string, label: string}) {
        selectedCategoryLabel = event.label;
    }

</script>

<div class="fixed bottom-0 left-1/2 -translate-x-1/2
            z-[8]
            h-[90vh]
            max-w-[950px]
            w-full
            flex
            flex-col
            bg-white
            rounded-lg
            shadow-[0_-4px_16px_rgba(0,0,0,0.15)]">

    <!-- Header +Navbar -->
    <div class="bg-gray-150">
        <!-- Header mit Titel und Schließen-Button -->
        <div class="flex justify-center items-center p-4">
            <h1 class="text-2xl font-bold">
                {title}
            </h1>
            
            <button
                onclick={closeCard}
                class="absolute right-4 rounded-lg p-2 transition-colors hover:bg-gray-100"
                aria-label="Card schließen">
                <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
                </svg>
            </button>
        </div>

        <!-- Navbar mit Tab-Navigation -->
        <Navbar {categories} onCategorySelect={handleCategorySelect} />
    </div>
    <!--Content-->    
    <div class="flex flex-col flex-1 overflow-auto p-4">
        {#if selectedCategoryLabel}
            <h2 class="text-xl font-semibold mb-4">{selectedCategoryLabel}</h2>
        {/if}
        <Carousel/>
        Hello TreeCard!<br>
        Children: <br>
        CardNavBar<br>
        Carousel<br>
        Chat
    </div>
</div>

