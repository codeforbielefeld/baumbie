/** @type {import('tailwindcss').Config} */
export default {
	content: ['./src/**/*.{html,js,svelte,ts}'],
	theme: {
		extend: {
			spacing: {
				128: '32rem',
				'3/4': '75vh'
			},
			colors: {


				green: {

					50: '#F4FFFB',
					
					100: '#D3FFEE',
					
					200: '#B2FFE2',
					
					300: '#92FFD5',
					
					400: '#7DE9C0',
					
					500: '#66CCA5',
					
					600: '#51AF8B',
					
					700: '#3E9272',
					
					800: '#2E7559',
					
					900: '#1F5842',
					
					950: '#0E3727'
					
					},
				gray: {
					150: '#efefef'
				}
			}
		}
	},
	plugins: []
};
