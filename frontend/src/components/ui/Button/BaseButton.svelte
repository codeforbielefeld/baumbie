
<button {...$$props} {...$$restProps} class={`rounded-full px-4 py-2 flex items-center ${$$props.class}`} on:click>
	{$$props.label}
	{#if $$props.icon_src && $$props.icon_alt}
	  <img src={$$props.icon_src} alt={$$props.icon_alt}/>	
	{/if}
</button>