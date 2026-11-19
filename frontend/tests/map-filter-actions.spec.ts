import { expect, test } from '@playwright/test';

test('selected species stay in one scrollable row with overflow indicators', async ({ page }) => {
	await page.setViewportSize({ width: 375, height: 800 });
	const species = ['Ahorn', 'Birke', 'Eiche', 'Esche', 'Kastanie', 'Linde', 'Pappel', 'Platane'];
	await page.route('**/data/species-count.json', (route) =>
		route.fulfill({
			json: Object.fromEntries(species.map((name, index) => [name, 100 - index]))
		})
	);
	await page.goto('http://localhost:4173/search');

	const dialog = page.getByRole('dialog');
	const row = page.getByRole('region', { name: 'Ausgewählte Baumarten' });
	const leftIndicator = page.locator('.scroll-edge--left');
	const rightIndicator = page.locator('.scroll-edge--right');

	await dialog.getByRole('button', { name: /^Ahorn / }).click();
	await expect(row.getByRole('button', { name: 'Ahorn abwählen' })).toBeVisible();
	await expect(leftIndicator).toHaveCount(0);
	await expect(rightIndicator).toHaveCount(0);

	for (const name of species.slice(1)) {
		await dialog.getByRole('button', { name: new RegExp(`^${name} `) }).click();
	}

	await expect(row.getByRole('button')).toHaveCount(species.length + 1);
	await expect(rightIndicator).toHaveCount(1);
	await expect(leftIndicator).toHaveCount(0);
	await expect(rightIndicator).toHaveCSS('backdrop-filter', 'blur(3px)');
	await expect(rightIndicator).toHaveCSS('mask-image', /radial-gradient/);
	await expect(rightIndicator).toHaveCSS('width', '24px');
	await expect(row).toHaveCSS('scrollbar-width', 'none');
	const geometry = await row.evaluate((element) => {
		const buttons = [...element.querySelectorAll('button')];
		const bounds = element.getBoundingClientRect();
		return {
			overflows: element.scrollWidth > element.clientWidth,
			left: bounds.left,
			right: bounds.right,
			viewportWidth: window.innerWidth,
			tops: buttons.map((button) => button.getBoundingClientRect().top)
		};
	});
	expect(geometry.overflows).toBe(true);
	expect(geometry.left).toBe(0);
	expect(geometry.right).toBe(geometry.viewportWidth);
	expect(new Set(geometry.tops).size).toBe(1);

	await page.setViewportSize({ width: 600, height: 800 });
	await expect(rightIndicator).toHaveCSS('width', '30px');

	await row.evaluate((element) => {
		element.scrollLeft = (element.scrollWidth - element.clientWidth) / 2;
	});
	await expect(leftIndicator).toHaveCount(1);
	await expect(rightIndicator).toHaveCount(1);
	await expect(leftIndicator).toHaveCSS('mask-image', /radial-gradient/);

	await row.evaluate((element) => {
		element.scrollLeft = element.scrollWidth;
	});
	await expect(leftIndicator).toHaveCount(1);
	await expect(rightIndicator).toHaveCount(0);

	await page.setViewportSize({ width: 1600, height: 800 });
	await expect(leftIndicator).toHaveCount(0);
	await expect(rightIndicator).toHaveCount(0);

	await dialog.getByRole('button', { name: 'close' }).click();
	await row.getByRole('button', { name: 'Ahorn abwählen' }).click();
	await expect(row.getByRole('button', { name: 'Ahorn abwählen' })).toHaveCount(0);
	await row.getByRole('button', { name: 'Alle Baumarten anzeigen' }).click();
	await expect(row).toHaveCount(0);
});
