<script lang="ts">
	// ——————————————————————————————————————————————————————————
	// 🌐 Externe Bibliotheken
	// ——————————————————————————————————————————————————————————
	import L from 'leaflet';
	import 'leaflet/dist/leaflet.css';
	import { MarkerClusterGroup } from '@tronscanteam/leaflet.markercluster/dist/leaflet.markercluster-src';
	import '@tronscanteam/leaflet.markercluster/dist/MarkerCluster.css';

	// ——————————————————————————————————————————————————————————
	// 🧱 Svelte & App-Framework
	// ——————————————————————————————————————————————————————————
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';

	// ——————————————————————————————————————————————————————————
	// 🧭 Kartenlogik
	// ——————————————————————————————————————————————————————————
	import { mapStore, renderSegmentFile } from '$lib/map';
	import { unregisterTreeMarker } from '$lib/map/markers/treeMarkerRegistry';

	// ——————————————————————————————————————————————————————————
	// 🌳 Baumspezifisch
	// ——————————————————————————————————————————————————————————
	import { selectedTreeFilters } from '$lib/trees';
	import type { TreeFilter } from '$types/tree';

	import { findMatchingSegments } from '$lib/geo';

	// ——————————————————————————————————————————————————————————
	// 🧩 Komponenten & Styles
	// ——————————————————————————————————————————————————————————
	import MapControls from './MapControls.svelte';
	import './Map.css';

	// ——————————————————————————————————————————————————————————
	// ⚙️ Initialisierung & Status
	// ——————————————————————————————————————————————————————————
	const id = 'map-' + Math.random().toString(36).substring(2, 9);
	const markerGroupRegistry = new Map<MarkerClusterGroup, string[]>();
	let map: L.Map;
	let loadedSegmentFiles = new Set<string>();
	let allMarkerGroups: MarkerClusterGroup[] = [];
	let lastFilter: TreeFilter = { species: [] };

	const loadDelayMs = 50;

	// ——————————————————————————————————————————————————————————
	// 🔄 Reaktion auf Filteränderung
	// ——————————————————————————————————————————————————————————
	$: if (map && JSON.stringify($selectedTreeFilters) !== JSON.stringify(lastFilter)) {
		lastFilter = structuredClone($selectedTreeFilters);

		allMarkerGroups.forEach((group) => {
			group.remove();
			const ids = markerGroupRegistry.get(group);
			if (ids) {
				for (const id of ids) {
					unregisterTreeMarker(id);
				}
				markerGroupRegistry.delete(group);
			}
		});

		allMarkerGroups = [];
		loadedSegmentFiles.clear();
		onMove();
	}

	// ——————————————————————————————————————————————————————————
	// 📍 Sichtbare Segmente laden & Marker anzeigen
	// ——————————————————————————————————————————————————————————
	const onMove = async () => {
		setTimeout(async () => {
			const bounds = map.getBounds();
			const ne = bounds.getNorthEast();
			const sw = bounds.getSouthWest();

			const segmentFiles = await findMatchingSegments(sw.lng, ne.lng, sw.lat, ne.lat);

			for (const file of segmentFiles.filter((f) => !loadedSegmentFiles.has(f))) {
				await renderSegmentFile(
					file,
					map,
					$selectedTreeFilters,
					loadedSegmentFiles,
					markerGroupRegistry,
					allMarkerGroups
				);
			}
		}, loadDelayMs);
	};

	// ——————————————————————————————————————————————————————————
	// 🗺️ Karteninitialisierung
	// ——————————————————————————————————————————————————————————
	onMount(() => {
		const tileURL =
			'https://cartodb-basemaps-{s}.global.ssl.fastly.net/rastertiles/light_all/{z}/{x}/{y}.png';

		const layer = L.tileLayer(tileURL, {
			attribution:
				'&copy; <a href="http://www.openstreetmap.org/copyright">OpenStreetMap</a>, &copy; <a href="https://carto.com/attributions">CARTO</a>',
			subdomains: 'abcd',
			maxZoom: 20,
			minZoom: 0
		});

		map = L.map(id, {
			center: [52.0192873, 8.5301909],
			zoom: 16,
			zoomControl: false
		})
			.addLayer(layer)
			.on('moveend', onMove);

		mapStore.set(map);

		onMove();

		document.getElementById(id)?.addEventListener('click', (e: MouseEvent) => {
			if (e.target instanceof HTMLElement && !e.target.className.includes('leaflet-marker-icon')) {
				goto('/');
			}
		});
	});
</script>

<!-- 🗺️ Karte -->
<div {id} class="fixed top-0 left-0 min-w-full min-h-full" />

<!-- 🧭 Custom Controls -->
<MapControls {map} />
