<script lang="ts">
	type ButtonVariant = 'default' | 'primary' | 'secondary' | 'danger';
	type ButtonType = 'submit' | 'button' | 'reset';

	export let variant: ButtonVariant = 'default';
	export let className: string = '';
	export let type: ButtonType = 'button';
	export let disabled: boolean = false;

	export let onClick: (e: MouseEvent) => void = () => {};

	const variantClasses: Record<ButtonVariant, string> = {
		default: 'border-black text-black hover:bg-green-800 hover:text-white',
		primary: 'border-green-600 bg-green-600 text-white hover:bg-green-800',
		secondary: 'border-green-500 text-black hover:bg-green-100',
		danger: 'border-red-600 text-black hover:bg-red-800 hover:text-white',
	};
</script>

<button
	{type}
	{disabled}
	class={`border-2 rounded-full px-4 py-2 flex items-center justify-center transition duration-150 ease-in-out
		${variantClasses[variant]}
		${disabled ? 'opacity-50 cursor-not-allowed' : ''}
		${className}`}
	on:click={!disabled ? onClick : undefined}
>
	<slot />
</button>
