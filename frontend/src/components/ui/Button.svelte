<script module lang="ts">
	export type ButtonVariant = 'default' | 'primary' | 'secondary' | 'danger' | 'watering';
</script>

<script lang="ts">
	type ButtonType = 'submit' | 'button' | 'reset';


	interface Props {
		variant?: ButtonVariant;
		className?: string;
		type?: ButtonType;
		disabled?: boolean;
		onClick?: (e: MouseEvent) => void;
		children?: import('svelte').Snippet;
	}

	let {
		variant = 'default',
		className = '',
		type = 'button',
		disabled = false,
		onClick = () => {},
		children
	}: Props = $props();

	const variantClasses: Record<ButtonVariant, string> = {
		default:
			'border-black text-black bg-white active:bg-gray-200 active:text-black hover:bg-gray-100 hover:text-black supports-hover:hover:bg-green-800 supports-hover:hover:text-white',
		primary:
			'border-green-600 bg-green-600 text-white active:bg-green-700 supports-hover:hover:bg-green-800',
		secondary: 'border-green-500 text-black active:bg-green-50 supports-hover:hover:bg-green-100',
		danger:
			'border-red-600 text-black active:bg-red-700 active:text-white supports-hover:hover:bg-red-800 supports-hover:hover:text-white',
		watering:
			'border-[#7C98B2] bg-[#7C98B2] text-white active:brightness-90 supports-hover:hover:brightness-110'
	};
</script>

<button
	{type}
	{disabled}
	class={`border-2 rounded-full px-4 py-2 flex items-center justify-center transition duration-150 ease-in-out
		${variantClasses[variant]}
		${disabled ? 'opacity-50 cursor-not-allowed' : ''}
		${className}`}
	onclick={!disabled ? onClick : undefined}
>
	{@render children?.()}
</button>
