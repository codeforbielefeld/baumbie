import { expect, test } from '@playwright/test';

test('species buttons show a plus or minus for their selection state', async ({ page }) => {
	await page.route('**/data/species-count.json', (route) =>
		route.fulfill({ json: { Ahorn: 100 } })
	);
	await page.goto('http://localhost:4173/search');

	const species = page.getByRole('dialog').getByRole('button', { name: /^Ahorn / });
	const icon = species.locator('svg');
	await expect(species).toHaveAttribute('aria-pressed', 'false');
	await expect(icon.locator('path')).toHaveCount(2);
	await species.click();
	await expect(species).toHaveAttribute('aria-pressed', 'true');
	await expect(icon.locator('path')).toHaveCount(1);
	await species.click();
	await expect(species).toHaveAttribute('aria-pressed', 'false');
	await expect(icon.locator('path')).toHaveCount(2);
});

test('tree counts use German thousands separators', async ({ page }) => {
	await page.route('**/data/species-count.json', (route) =>
		route.fulfill({ json: { Ahorn: 1234, Eiche: 999 } })
	);
	await page.goto('http://localhost:4173/search');

	const dialog = page.getByRole('dialog');
	await expect(dialog.getByText('2.233 Stadtbäume')).toBeVisible();
	await expect(dialog.getByText('2 verschiedene Arten')).toBeVisible();
	await expect(dialog.getByRole('button', { name: /^Ahorn / })).toContainText('1.234');
	await expect(dialog.getByRole('button', { name: /^Eiche / })).toContainText('999');
});

test('search filters species without changing selected filters', async ({ page }) => {
	await page.route('**/data/species-count.json', (route) =>
		route.fulfill({
			json: { Bergahorn: 20, Feldahorn: 40, Linde: 60, Eiche: 80 }
		})
	);
	await page.goto('http://localhost:4173/search');

	const dialog = page.getByRole('dialog');
	const search = dialog.getByPlaceholder('Baumart suchen ...');
	const bergahorn = dialog.getByRole('button', { name: /^Bergahorn / });
	const feldahorn = dialog.getByRole('button', { name: /^Feldahorn / });
	const linde = dialog.getByRole('button', { name: /^Linde / });
	const eiche = dialog.getByRole('button', { name: /^Eiche / });

	await expect(eiche).toBeVisible();
	await linde.click();
	await search.fill('  AHORN  ');
	await expect(bergahorn).toBeVisible();
	await expect(feldahorn).toBeVisible();
	await expect(linde).toHaveCount(0);
	await expect(eiche).toHaveCount(0);
	await expect(page.getByRole('button', { name: 'Linde abwählen' })).toBeVisible();

	await dialog.getByRole('button', { name: /Baumart/ }).click();
	await dialog.getByRole('button', { name: /Häufigkeit/ }).click();
	await expect(dialog.getByRole('button', { name: /^(Bergahorn|Feldahorn) / })).toHaveText([
		/^Feldahorn /,
		/^Bergahorn /
	]);
	await search.fill('unbekannt');
	await expect(dialog.getByText('Keine Baumart gefunden')).toBeVisible();
	await expect(bergahorn).toHaveCount(0);

	await search.clear();
	await expect(dialog.getByText('Keine Baumart gefunden')).toHaveCount(0);
	await expect(bergahorn).toBeVisible();
	await expect(feldahorn).toBeVisible();
	await expect(linde).toBeVisible();
	await expect(eiche).toBeVisible();
	await expect(linde).toHaveClass(/bg-green-300/);
});

test('Enter selects the first highlighted search result', async ({ page }) => {
	await page.route('**/data/species-count.json', (route) =>
		route.fulfill({
			json: { Bergahorn: 20, Feldahorn: 40, Linde: 60 }
		})
	);
	await page.goto('http://localhost:4173/search');

	const dialog = page.getByRole('dialog');
	const search = dialog.getByPlaceholder('Baumart suchen ...');
	const bergahorn = dialog.getByRole('button', { name: /^Bergahorn / });
	const feldahorn = dialog.getByRole('button', { name: /^Feldahorn / });
	const selectedBergahorn = page.getByRole('button', { name: 'Bergahorn abwählen' });

	await expect(bergahorn).toBeVisible();
	await search.press('Enter');
	await expect(selectedBergahorn).toHaveCount(0);

	await search.fill('ahorn');
	await expect(bergahorn).toHaveClass(/bg-green-100/);
	await expect(feldahorn).not.toHaveClass(/bg-green-100/);
	await search.press('ArrowDown');
	await search.press('Enter');
	await expect(selectedBergahorn).toHaveCount(1);
	await expect(bergahorn).toHaveClass(/bg-green-300/);
	await expect(search).toHaveValue('ahorn');
	await search.press('Enter');
	await expect(selectedBergahorn).toHaveCount(1);

	await dialog.getByRole('button', { name: /Häufigkeit/ }).click();
	await expect(feldahorn).toHaveClass(/bg-green-100/);
	await search.focus();
	await search.press('Enter');
	await expect(page.getByRole('button', { name: 'Feldahorn abwählen' })).toHaveCount(1);

	await search.fill('unbekannt');
	await search.press('Enter');
	await expect(dialog.getByText('Keine Baumart gefunden')).toBeVisible();
	await expect(page.getByRole('button', { name: /abwählen$/ })).toHaveCount(2);
});

test('the species table fills the card and remains scrollable', async ({ page }) => {
	await page.setViewportSize({ width: 800, height: 1000 });
	await page.route('**/data/species-count.json', (route) =>
		route.fulfill({
			json: Object.fromEntries(
				Array.from({ length: 30 }, (_, index) => [`Baumart ${index + 1}`, 30 - index])
			)
		})
	);
	await page.goto('http://localhost:4173/search');

	const dialog = page.getByRole('dialog');
	const firstSpecies = dialog.getByRole('button', { name: /^Baumart 1 / });
	const lastSpecies = dialog.getByRole('button', { name: /^Baumart 30 / });
	await expect(firstSpecies).toBeVisible();
	const tableBody = firstSpecies.locator('..');
	const table = tableBody.locator('..');

	await expect.poll(async () => (await tableBody.boundingBox())?.height).toBeGreaterThan(384);
	const tableBox = await table.boundingBox();
	const dialogBox = await dialog.boundingBox();
	expect(tableBox).not.toBeNull();
	expect(dialogBox).not.toBeNull();
	expect(dialogBox!.y + dialogBox!.height - (tableBox!.y + tableBox!.height)).toBeCloseTo(24, 0);

	await page.setViewportSize({ width: 375, height: 450 });
	await lastSpecies.click();
	await expect(page.getByRole('button', { name: 'Baumart 30 abwählen' })).toBeVisible();
});
