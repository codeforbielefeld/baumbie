<script>
    import Slide from './Slide.svelte';
    let {slides = []} = $props();
    $inspect(slides);
</script>

<div class="flex flex-col gap-4 overflow-x-auto py-4">
    {#each slides as slide}
        SLIDE:
        <Slide {slide} />
    {/each}
</div>
