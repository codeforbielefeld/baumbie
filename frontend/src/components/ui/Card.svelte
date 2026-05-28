<script lang="ts">
    let {type = "tree",
        data = {},
        onClose = () => {}
    } = $props();

    function closeCard() {
        onClose();
    }
</script>

<div class="fixed bottom-0 left-1/2 -translate-x-1/2
            z-[8]
            h-[90vh]
            max-w-[950px]
            w-full
            flex
            justify-center
            bg-white
            rounded-lg
            shadow-[0_-4px_16px_rgba(0,0,0,0.15)]
            relative">
    <button
        onclick={closeCard}
        class="absolute top-4 right-4 p-2 hover:bg-gray-100 rounded-lg transition-colors"
        aria-label="Card schließen">
        <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
        </svg>
    </button>
    
    Hello TreeCard!<br>
    Children: <br>
    CardNavBar<br>
    Carousel<br>
    Chat
</div>

