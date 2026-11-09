// Journal leak test (PRD §7.5): writes an entry containing a random canary through the real UI,
// then proves the plaintext never left the browser. Run against the dev stack: `make canary`.
//
// Checks: no request body contains the canary or the passphrase; the entry decrypts again after
// a reload + unlock; locking removes it from the page. The caller (bin/journal-canary) then
// greps a pg_dump, the Rails log and storage for the canary.
import { chromium } from 'playwright-core'

const [base, email, password, canary] = process.argv.slice(2)
const passphrase = `canary passphrase ${canary.slice(-6)}`
const fail = (message) => { console.error(`✗ ${message}`); process.exitCode = 1 }

const browser = await chromium.launch({ channel: 'chrome' })
const page = await browser.newPage()
const bodies = []
page.on('request', (r) => r.postData() && bodies.push(r.postData()))

try {
  await page.goto(`${base}/login`)
  await page.fill('input[type=email]', email)
  await page.fill('input[type=password]', password)
  await page.click('button[type=submit]')
  await page.waitForURL(`${base}/`)

  await page.goto(`${base}/journal`)
  const setup = page.locator('#journal-passphrase')
  const unlock = page.locator('#unlock-passphrase')
  await setup.or(unlock).waitFor()
  if (await setup.isVisible()) {
    await setup.fill(passphrase)
    await page.fill('#journal-passphrase-confirm', passphrase)
    await page.getByRole('button', { name: 'Create my journal' }).click()
    await page.getByLabel(/stored my recovery key/).check()
    await page.getByRole('button', { name: 'Continue to my journal' }).click()
  } else {
    console.log('A journal already exists; set JOURNAL_PASSPHRASE to reuse it, or reset the dev database.')
    await unlock.fill(process.env.JOURNAL_PASSPHRASE ?? '')
    await page.getByRole('button', { name: 'Unlock' }).click()
  }

  // In-app navigation: a full page load would (rightly) drop the in-memory key and lock.
  await page.getByRole('button', { name: 'Write today' }).first().click()
  await page.getByLabel('Entry title').fill(`Title ${canary}`)
  await page.locator('.lumen-prose').click()
  await page.keyboard.type(`Body ${canary}`)
  await page.getByText('Encrypted · saved').waitFor({ timeout: 15_000 })
  const url = page.url()

  await page.reload()
  await page.locator('#unlock-passphrase').fill(process.env.JOURNAL_PASSPHRASE ?? passphrase)
  await page.getByRole('button', { name: 'Unlock' }).click()
  await page.waitForFunction((c) => document.querySelector('[aria-label="Entry title"]')?.value?.includes(c), canary)
  console.log('✓ entry decrypts after reload + unlock')

  await page.keyboard.press('ControlOrMeta+Shift+L')
  await page.getByText('Journal locked').waitFor()
  if ((await page.content()).includes(canary)) fail('canary still in the page after locking')
  else console.log('✓ locking wipes the decrypted entry from the page')

  const leaks = bodies.filter((b) => b.includes(canary) || b.includes(passphrase))
  if (leaks.length) fail(`${leaks.length} request(s) carried plaintext or the passphrase`)
  else console.log(`✓ ${bodies.length} requests sent, none with plaintext or the passphrase`)
  console.log(`entry: ${url}`)
} catch (error) {
  fail(error.message.split('\n')[0])
  await page.screenshot({ path: 'tmp/journal-canary-failure.png' }).catch(() => {})
  console.error(`  page: ${page.url()} (screenshot: tmp/journal-canary-failure.png)`)
} finally {
  await browser.close()
}
