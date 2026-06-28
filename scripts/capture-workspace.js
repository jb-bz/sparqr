// /tmp/capture-workspace.js - Improved version
const path = require('path');
const playwrightDir = '/usr/local/lib/node_modules/playwright';
const { chromium } = require(playwrightDir);

const OUT = process.env.OUT_DIR || '/Users/jolonbankey/Documents/AAA-Agents/hermes/sparc-orchestration-2026-06/package/docs/screenshots/workspace';
const URL = process.env.URL || 'http://localhost:3000';

async function main() {
  const browser = await chromium.launch({
    headless: true,
    args: ['--no-sandbox', '--disable-dev-shm-usage'],
  });
  const context = await browser.newContext({
    viewport: { width: 1400, height: 900 },
  });
  const page = await context.newPage();

  page.on('pageerror', err => {
    console.error('PAGE EXCEPTION:', err.message);
  });

  console.log(`navigating to ${URL}...`);
  await page.goto(URL, { waitUntil: 'domcontentloaded', timeout: 15000 });

  // 1. Splash
  await page.waitForTimeout(2500);
  await page.screenshot({ path: path.join(OUT, '01-splash.png') });
  console.log('captured splash');

  // 2. Main UI (default page after splash)
  try {
    await page.waitForSelector('text=Hermes Workspace', { timeout: 15000 });
    await page.waitForTimeout(2500);
    await page.screenshot({ path: path.join(OUT, '02-main-ui.png') });
    console.log('captured main UI');
  } catch (e) {
    console.log('main UI selector failed, capturing current state');
    await page.screenshot({ path: path.join(OUT, '02-main-ui.png') });
  }

  // 3. Chat panel: click "Chat" in sidebar
  try {
    await page.click('text=Chat', { timeout: 5000 });
    await page.waitForTimeout(2500);
    await page.screenshot({ path: path.join(OUT, '03-chat-view.png') });
    console.log('captured chat view');
  } catch (e) {
    console.log(`chat click failed: ${e.message}`);
  }

  // 4. Files: click "Files"
  try {
    await page.click('text=Files', { timeout: 5000 });
    await page.waitForTimeout(2500);
    await page.screenshot({ path: path.join(OUT, '04-files-view.png') });
    console.log('captured files view');
  } catch (e) {
    console.log(`files click failed: ${e.message}`);
  }

  // 5. Tasks: click "Tasks"
  try {
    await page.click('text=Tasks', { timeout: 5000 });
    await page.waitForTimeout(2500);
    await page.screenshot({ path: path.join(OUT, '05-tasks-view.png') });
    console.log('captured tasks view');
  } catch (e) {
    console.log(`tasks click failed: ${e.message}`);
  }

  // 6. Memory: click "Memory"
  try {
    await page.click('text=Memory', { timeout: 5000 });
    await page.waitForTimeout(2500);
    await page.screenshot({ path: path.join(OUT, '06-memory-view.png') });
    console.log('captured memory view');
  } catch (e) {
    console.log(`memory click failed: ${e.message}`);
  }

  // 7. Skills: click "Skills"
  try {
    await page.click('text=Skills', { timeout: 5000 });
    await page.waitForTimeout(2500);
    await page.screenshot({ path: path.join(OUT, '07-skills-view.png') });
    console.log('captured skills view');
  } catch (e) {
    console.log(`skills click failed: ${e.message}`);
  }

  // 8. Dashboard: click "Dashboard"
  try {
    await page.click('text=Dashboard', { timeout: 5000 });
    await page.waitForTimeout(2500);
    await page.screenshot({ path: path.join(OUT, '08-dashboard-view.png') });
    console.log('captured dashboard view');
  } catch (e) {
    console.log(`dashboard click failed: ${e.message}`);
  }

  // 9. Profiles: click "Profiles"
  try {
    await page.click('text=Profiles', { timeout: 5000 });
    await page.waitForTimeout(2500);
    await page.screenshot({ path: path.join(OUT, '09-profiles-view.png') });
    console.log('captured profiles view');
  } catch (e) {
    console.log(`profiles click failed: ${e.message}`);
  }

  await browser.close();
  console.log('done');
}

main().catch(err => {
  console.error('FATAL:', err);
  process.exit(1);
});