---
name: playwright-browser-test
description: >-
  Drive a real browser with the Playwright CLI to verify UI changes end-to-end:
  setup without a package.json, persistent login sessions, MFA/OTP injection,
  and common gotchas around test-id attributes and login-page detection. Use
  when asked to test, verify, or screenshot a browser-based app.
---

# Playwright browser test

Goal: exercise the running app through a browser so that visual rendering,
actions, and data flow are confirmed—not just that the code compiles.

## Setup — no package.json required

Install `@playwright/test` to a temp dir to avoid touching the project:

    npm install --prefix /tmp/pw-test playwright @playwright/test

Script skeleton (ESM, `@playwright/test` is a CJS module so unpack it):

```js
import pkg from "/tmp/pw-test/node_modules/@playwright/test/index.js";
const { chromium } = pkg;
import { mkdirSync } from "fs";

const SS = "/tmp/screenshots";
mkdirSync(SS, { recursive: true });

const browser = await chromium.launch({
  executablePath:
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
  headless: false,
  slowMo: 100,
});
const ctx = await browser.newContext({
  viewport: { width: 1920, height: 900 },
});
const page = await ctx.newPage();

// ... test logic ...

await browser.close();
```

Run with `node script.mjs`.

## Persistent context — reuse login sessions

`chromium.launchPersistentContext(dir, opts)` persists cookies to disk. After
one successful login, subsequent runs skip the login flow entirely:

```js
const ctx = await chromium.launchPersistentContext("/tmp/pw-profile", {
  executablePath: CHROME,
  headless: false,
  slowMo: 100,
  viewport: { width: 1920, height: 900 },
});
const page = ctx.pages()[0] || (await ctx.newPage());
// close with ctx.close(), not browser.close()
```

Clear the profile dir to force a fresh login: `rm -rf /tmp/pw-profile`.

## Detecting where you are in a login flow

Don't use `input[type="password"]` as the signal for "password page" — apps
often include a hidden password field on the email step for browser autofill.
Use a **button that only exists on the password page** (e.g. the sign-in submit
button):

```js
const signal = await Promise.race([
  page
    .waitForSelector('[data-test-id="app.signInButton"]', { timeout: 30000 })
    .then(() => "password"),
  page.waitForSelector('[role="grid"]', { timeout: 30000 }).then(() => "grid"),
  page
    .waitForFunction(() => /verify.*/i.test(document.body.innerText), {
      timeout: 30000,
    })
    .then(() => "mfa"),
]).catch(() => "timeout");
```

Allow **20–30 seconds** for the transition from email step to password step —
some auth services are slow.

## OTP / MFA injection via file

When a test encounters an MFA step, have it write a sentinel and poll a file
rather than hard-coding a code:

```js
import { existsSync, readFileSync, writeFileSync } from "fs";
const CODE_FILE = "/tmp/mfa-code.txt";

async function waitForCode() {
  writeFileSync(CODE_FILE, ""); // clear stale value
  console.log("Write 6-digit code to /tmp/mfa-code.txt");
  const deadline = Date.now() + 300_000; // 5 min
  while (Date.now() < deadline) {
    const v = existsSync(CODE_FILE)
      ? readFileSync(CODE_FILE, "utf8").trim()
      : "";
    if (/^\d{6}$/.test(v)) return v;
    await new Promise((r) => setTimeout(r, 2000));
  }
  throw new Error("Code not provided");
}
```

Inject from another terminal: `echo 123456 > /tmp/mfa-code.txt`

For segmented OTP inputs (individual digit boxes), use `keyboard.type`:

```js
await page.locator("input:visible").first().click();
await page.keyboard.type(code, { delay: 100 });
```

`fill()` often doesn't advance segmented inputs; `keyboard.type` does.

## Test-ID attributes

Different frameworks use different attribute names:

| Framework                                  | Attribute                   |
| ------------------------------------------ | --------------------------- |
| Over React (`addTestId`)                   | `data-test-id` (hyphenated) |
| React Testing Library / Playwright default | `data-testid` (no hyphen)   |
| MUI default                                | `data-testid`               |

Always confirm the actual attribute with a DOM inspection step before writing
locators. The wrong attribute name silently returns 0 elements.

Some apps only emit test-ID attributes when a specific URL query parameter is
present (e.g. `?automation=true`). Check the app's functional test setup for the
correct flag.

## Anti-patterns

- **Using `input[type="password"]` for login-step detection** — fires on hidden
  autofill fields; use a visible button unique to the password step instead.
- **Hard-coding MFA codes** — they expire in 10 minutes and are
  session-specific; use the file-injection pattern and fetch from email/SMS via
  automation.
- **`fill()` on segmented OTP inputs** — does not advance focus; use
  `keyboard.type()` instead.
- **Querying `[data-testid]` when the app uses `data-test-id`** — silently finds
  nothing; inspect the DOM or the framework docs first.
- **Not using a persistent context** — forces a fresh login every run; the first
  successful login should be saved so subsequent runs skip auth.
