import { defineConfig } from 'vite'
import wasm from 'vite-plugin-wasm'

export default defineConfig({
	plugins: [wasm()],
	server: {
		host: true
	},
	build: {
		outDir: 'dist',
		emptyOutDir: true
	}
})