import { sveltekit } from '@sveltejs/kit/vite';
import { defineConfig } from 'vitest/config';
import path from 'path';

export default defineConfig({
	plugins: [sveltekit()],
	test: {
		include: ['src/**/*.{test,spec}.{js,ts}']
	},
	envDir: '..',
	resolve: {
		alias: {
			$lib: path.resolve('./src/lib'),
			$components: path.resolve(__dirname, 'src/components'),
			$types: path.resolve(__dirname, 'src/types')
		}
	},
	server: {
		allowedHosts: true
	}
});
