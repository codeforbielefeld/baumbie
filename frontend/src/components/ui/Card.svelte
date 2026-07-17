<script lang="ts">
    import { fly } from 'svelte/transition';
    import Navbar from './CardElements/Navbar.svelte';
    import Carousel from './CardElements/Carousel.svelte';
    import { Chat } from '$components/chat';

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
    let selectedCategory = $state('');
    let currentSlides = $derived(categories[selectedCategory]?.slides || []);
    let isChatOpen = $state(false);

    function handleCategorySelect(event: {category: string, label: string}) {
        selectedCategoryLabel = event.label;
        selectedCategory = event.category;
    }

    function openChat() {
        isChatOpen = true;
    }

    function closeChat() {
        isChatOpen = false;
    }

    function toggleChat() {
        isChatOpen = !isChatOpen;
    }

</script>

<div class="fixed bottom-[calc(var(--navbar-height,0px))] left-1/2 -translate-x-1/2
            z-[8]
            h-[calc(90vh-var(--navbar-height,0px))]
            max-w-[950px]
            w-full
            flex
            flex-col
            bg-white
            rounded-lg
            shadow-[0_-4px_16px_rgba(0,0,0,0.15)]">

    <!-- Header +Navbar -->
    <div class="flex flex-col gap-2 pt-2 bg-gray-150">
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
    <div class="relative flex flex-col flex-1 overflow-hidden p-4">
        <Carousel slides={currentSlides} />

        <button
            type="button"
            class="absolute bottom-4 right-4 z-[40] flex h-14 w-14 items-center justify-center rounded-full bg-green-600 text-white shadow-lg transition hover:bg-green-700"
            aria-label={isChatOpen ? 'Chatbot schließen' : 'Chatbot öffnen'}
            onclick={toggleChat}
        >
            <svg class="h-7 w-7" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                <path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z" />
            </svg>
        </button>

        {#if isChatOpen}
            <div
                transition:fly={{ x: 180, y: 180, duration: 260 }}
                class="absolute inset-0 z-[30] flex items-stretch justify-stretch rounded-lg bg-white/90 backdrop-blur-[1px]"
            >
                <div class="flex h-full w-full flex-col overflow-hidden rounded-2xl bg-white shadow-2xl">
                    <div class="flex items-center justify-between border-b border-gray-200 px-4 py-3">
                        <h2 class="text-lg font-semibold">Chat mit {title}</h2>
                        <button
                            type="button"
                            class="rounded-full p-2 hover:bg-gray-100"
                            aria-label="Chat schließen"
                            onclick={closeChat}
                        >
                            <svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
                            </svg>
                        </button>
                    </div>
                    <div class="min-h-0 flex-1 p-3">
                        <Chat treeId={data.uuid || ''} />
                    </div>
                </div>
            </div>
        {/if}
    </div>


</div>
