import adapter from '@sveltejs/adapter-static';
import { sveltekit } from '@sveltejs/kit/vite';
import { vitePreprocess } from '@sveltejs/vite-plugin-svelte';
import { defineConfig } from 'vite';

export default defineConfig({
	plugins: [
		sveltekit({
			preprocess: vitePreprocess(),
			// Static SPA (ssr is off); the server falls back to index.html.
			adapter: adapter({ fallback: 'index.html' }),
			env: {
				dir: '..'
			},
			alias: {
				$components: 'src/components',
				$lib: 'src/lib',
				$types: 'src/types'
			}
		})
	],
	// .env lives in the repo root; read by import.meta.env (Vite) and $env (kit above).
	envDir: '..',
	test: {
		include: ['src/**/*.{test,spec}.{js,ts}']
	}
});
