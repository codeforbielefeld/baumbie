<script>
    let { slide = {} } = $props();
</script>

{#if slide.content}
    <div class="flex h-full flex-col gap-3 border border-gray-200 p-4">
        <h3 class="text-lg font-semibold">{slide.title}</h3>
        <p class="flex-1 overflow-auto text-gray-700">
            {slide.content}
        </p>
    </div>
{/if}
