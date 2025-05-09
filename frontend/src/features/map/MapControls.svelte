<script lang="ts">
	import L from 'leaflet';
	import { userMarkerIcon } from '$shared/lib/map/user-marker';

	export let map: L.Map;

	let userMarker: L.Marker | null = null;

	function zoomIn() {
		map?.zoomIn();
	}

	function zoomOut() {
		map?.zoomOut();
	}

	function centerOnUser() {
		if (!map) return;

		if (userMarker) {
			map.removeLayer(userMarker);
			userMarker = null;
			return
		}

		map.off('locationfound');
		map.off('locationerror');
		map.locate({ enableHighAccuracy: true });

		map.once('locationfound', (e) => {
			map.flyTo(e.latlng, 20, {
				animate: true,
				duration: 1.5
			});

			userMarker = L.marker(e.latlng, { icon: userMarkerIcon() }).addTo(map);
		});

		map.once('locationerror', () => {
			alert('Standort konnte nicht ermittelt werden.');
		});
	}
</script>

<!-- UI für Zoom + Standort -->
<div class="fixed bottom-[90px] right-4 flex flex-col gap-2 z-[1000]">
	<!-- 📍 Standort zentrieren -->
	<button
		on:click={centerOnUser}
		class="w-12 h-12 bg-white rounded-full shadow flex items-center justify-center hover:bg-gray-100 transition"
		aria-label="Standort zentrieren"
	>
		<img src="/map/controls/locate.svg" alt="Standort zentrieren" class="w-7 h-7" />
	</button>

	<!-- ➕ Zoom In -->
	<button
		on:click={zoomIn}
		class="w-12 h-12 bg-white rounded-full shadow flex items-center justify-center hover:bg-gray-100 transition"
		aria-label="Zoom in"
	>
		<img src="/map/controls/zoom-in.svg" alt="Zoom in" class="w-8 h-8" />
	</button>

	<!-- ➖ Zoom Out -->
	<button
		on:click={zoomOut}
		class="w-12 h-12 bg-white rounded-full shadow flex items-center justify-center hover:bg-gray-100 transition"
		aria-label="Zoom out"
	>
		<img src="/map/controls/zoom-out.svg" alt="Zoom out" class="w-8 h-8" />
	</button>
</div>