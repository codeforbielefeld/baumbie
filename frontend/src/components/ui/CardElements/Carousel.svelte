<script lang="ts">
    import Slide from './Slide.svelte';

    type SlideItem = {
        title?: string;
        content?: string;
    };

    let { slides = [] as SlideItem[] } = $props();

    let currentIndex = $state(0);
    let dragStartX = $state(0);
    let dragOffsetX = $state(0);
    let isDragging = $state(false);

    const goToSlide = (index: number) => {
        if (!slides.length) return;

        currentIndex = Math.max(0, Math.min(index, slides.length - 1));
        dragOffsetX = 0;
        isDragging = false;
    };

    const handlePointerDown = (event: PointerEvent) => {
        if (!slides.length) return;

        dragStartX = event.clientX;
        dragOffsetX = 0;
        isDragging = true;
    };

    const handlePointerMove = (event: PointerEvent) => {
        if (!isDragging) return;

        dragOffsetX = event.clientX - dragStartX;
    };

    const handlePointerUp = () => {
        if (!isDragging) return;

        const swipeThreshold = 70;

        if (dragOffsetX <= -swipeThreshold) {
            goToSlide(currentIndex + 1);
        } else if (dragOffsetX >= swipeThreshold) {
            goToSlide(currentIndex - 1);
        } else {
            dragOffsetX = 0;
            isDragging = false;
        }
    };

    const trackStyle = $derived(
        `transform: translateX(
            calc(${-currentIndex * 100}% + ${dragOffsetX}px));
            transition: ${isDragging ? 'none' : 'transform 0.25s ease'};`
    );
</script>

<svelte:window onpointerup={handlePointerUp} onpointercancel={handlePointerUp} />

{#if slides.length}
    <div class="flex h-full min-h-[360px] flex-col gap-3" role="region" aria-label="Story Slides">
        <div class="flex gap-1.5">
            {#each slides as _, index}
                <button
                    type="button"
                    class={`h-1 flex-1 rounded-full transition-colors ${index === currentIndex ? 'bg-green-600' : 'bg-gray-300'}`}
                    aria-label={`Zu Slide ${index + 1} springen`}
                    onclick={() => goToSlide(index)}
                ></button>
            {/each}
        </div>

        <div
            class="relative flex-1 overflow-hidden rounded-xl  shadow-sm"
            onpointerdown={handlePointerDown}
            onpointermove={handlePointerMove}
            role="region"
            aria-label="Story Inhalt"
            style="touch-action: pan-y;"
        >
            <div class="absolute inset-0 flex h-full" style={trackStyle}>
                {#each slides as slide}
                    <div class="min-w-full h-full shrink-0">
                        <Slide {slide} />
                    </div>
                {/each}
            </div>
        </div>
    </div>
{:else}
    <div class="flex h-full min-h-[240px] items-center justify-center rounded-xl bg-gray-100 text-sm text-gray-500">
        Zu diesem Baum fehlen dazu die Informationen.
    </div>
{/if}
