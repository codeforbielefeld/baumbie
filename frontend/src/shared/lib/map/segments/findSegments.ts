type ViewportType = {
	minX: number;
	maxX: number;
	minY: number;
	maxY: number;
};

type MapDataSegmentType = ViewportType & {
	fileName: string;
};

type MapDataType = MapDataSegmentType[];

let mapData: MapDataType = [];

/**
 * Überprüft, ob sich zwei geographische Bereiche überschneiden.
 *
 * @param {Object} segment - Ein Objekt, das die Grenzen eines Segments repräsentiert.
 * @param {Object} viewport - Ein Objekt, das die Grenzen eines Bildausschnitts repräsentiert.
 * @returns {boolean} - Gibt true zurück, wenn sich die Bereiche überschneiden, sonst false.
 */
function intersects(segment: MapDataSegmentType, viewport: ViewportType) {
	return (
		segment.minX <= viewport.maxX &&
		segment.maxX >= viewport.minX &&
		segment.minY <= viewport.maxY &&
		segment.maxY >= viewport.minY
	);
}

/**
 * Nimmt die Koordinaten eines Bildausschnitts entgegen und gibt die Dateinamen der Segmente zurück,
 * die sich mit diesem Bildausschnitt überschneiden.
 *
 * @param {number} minX - Die minimale X-Koordinate des Bildausschnitts.
 * @param {number} maxX - Die maximale X-Koordinate des Bildausschnitts.
 * @param {number} minY - Die minimale Y-Koordinate des Bildausschnitts.
 * @param {number} maxY - Die maximale Y-Koordinate des Bildausschnitts.
 * @returns {Array} - Ein Array von Dateinamen der Segmente, die sich mit dem Bildausschnitt überschneiden.
 */
async function findMatchingSegments(minX: number, maxX: number, minY: number, maxY: number) {
	// Synchrones Einlesen der map.json, um die Liste der Segmente zu erhalten.
	if (mapData.length === 0) {
		await fetch('/segments/segments_index.json')
			.then((response) => response.json())
			.then((data) => (mapData = data));
	}

	// Definiere den Bildausschnitt als Objekt mit den gegebenen Koordinaten.
	const viewport = { minX, maxX, minY, maxY };

	// Filtere die Segmente heraus, die sich mit dem Bildausschnitt überschneiden.
	const matchingSegments = mapData.filter((segment) => intersects(segment, viewport));

	// Extrahiere die Dateinamen der überschneidenden Segmente und gib sie zurück.
	return matchingSegments.filter((segment) => segment.fileName).map((segment) => segment.fileName);
}

export default findMatchingSegments;
