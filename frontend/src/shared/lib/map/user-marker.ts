import L from 'leaflet';

// Animiertes SVG für den User-Standort-Marker
// Besteht aus:
// - zwei sich überlagernden Ripple-Wellen (sanft, versetzt animiert)
// - einem weichen blauen Kreis (Ortungsradius)
// - einem weißen Ring (Kontrastrahmen)
// - einem blauen Punkt (genauer Standort)
export const userMarkerHtml = `
<svg xmlns="http://www.w3.org/2000/svg" width="220" height="220" viewBox="0 0 220 220">
	<!-- Erste Ripple-Welle: startet sofort -->
	<circle cx="110" cy="110" r="0" fill="rgba(59, 130, 246, 0.4)">
		<animate attributeName="r" from="0" to="100" dur="6s" begin="0s" repeatCount="indefinite" />
		<animate attributeName="opacity" from="0.4" to="0" dur="6s" begin="0s" repeatCount="indefinite" />
	</circle>

	<!-- Zweite Ripple-Welle: startet nach 1.75s, für flüssigen Effekt -->
	<circle cx="110" cy="110" r="0" fill="rgba(59, 130, 246, 0.4)">
		<animate attributeName="r" from="0" to="100" dur="6s" begin="3s" repeatCount="indefinite" />
		<animate attributeName="opacity" from="0.4" to="0" dur="6s" begin="3s" repeatCount="indefinite" />
	</circle>

	<!-- Hintergrundkreis: symbolisiert Ortungsgenauigkeit -->
	<circle cx="110" cy="110" r="100" fill="rgba(59, 130, 246, 0.15)" />

	<!-- Weißer Kontrastring -->
	<circle cx="110" cy="110" r="10" fill="white" />

	<!-- Blauer Mittelpunkt: eigentliche Position -->
	<circle cx="110" cy="110" r="7" fill="#3B82F6" />
</svg>
`;

// Leaflet-Icon, das das SVG als HTML verwendet
// zentriert auf der Position (iconAnchor = Mitte)
export const userMarkerIcon = () =>
	L.divIcon({
		html: userMarkerHtml,
		className: '', // neutraler Stil, kein zusätzliches CSS
		iconSize: [220, 220], // SVG-Größe
		iconAnchor: [110, 110] // zentriert auf LatLng
	});