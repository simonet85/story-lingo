import { createHash } from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const BASE_URL = (process.env.BASE_URL || 'http://127.0.0.1:8765').replace(/\/$/, '');
const CDP_URL = (process.env.CDP_URL || 'http://127.0.0.1:9222').replace(/\/$/, '');
const ADMIN_TOKEN = process.env.ADMIN_TOKEN;
const BOOK_ID = 'visual-crud';
const OUT_DIR = process.env.VISUAL_OUT || '.tmp/visual';
const FIXTURE =
  process.env.VISUAL_FIXTURE ||
  path.join(path.dirname(fileURLToPath(import.meta.url)), 'fixtures', 'visual-crud.zip');

if (!ADMIN_TOKEN) {
  console.error('ADMIN_TOKEN est requis (mot de passe du back-office).');
  process.exit(2);
}
if (!fs.existsSync(FIXTURE)) {
  console.error(`Fixture introuvable : ${FIXTURE}`);
  process.exit(2);
}
fs.mkdirSync(OUT_DIR, { recursive: true });

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
const assert = (condition, message) => {
  if (!condition) throw new Error(message);
};

async function loginHttp() {
  const response = await fetch(`${BASE_URL}/admin/login`, {
    method: 'POST',
    redirect: 'manual',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({ password: ADMIN_TOKEN }),
  });
  assert(response.status === 303, `connexion HTTP : ${response.status}`);
  const raw =
    typeof response.headers.getSetCookie === 'function'
      ? response.headers.getSetCookie()[0]
      : response.headers.get('set-cookie');
  assert(raw, 'cookie de session absent');
  return raw.split(';')[0];
}

async function request(cookie, target, init = {}) {
  return fetch(`${BASE_URL}${target}`, {
    ...init,
    redirect: 'manual',
    headers: { ...(init.headers || {}), cookie },
  });
}

async function json(cookie, target) {
  const response = await request(cookie, target);
  assert(response.status === 200, `${target} : ${response.status}`);
  return response.json();
}

async function connectCdp() {
  const targets = await (await fetch(`${CDP_URL}/json/list`)).json();
  const target =
    targets.find((item) => item.type === 'page' && item.url.includes(BASE_URL)) ||
    targets.find((item) => item.type === 'page');
  assert(target, 'aucune page Chrome disponible');
  const socket = new WebSocket(target.webSocketDebuggerUrl);
  await new Promise((resolve, reject) => {
    socket.onopen = resolve;
    socket.onerror = reject;
  });

  let nextId = 1;
  const pending = new Map();
  const problems = [];
  socket.onmessage = (event) => {
    const message = JSON.parse(event.data);
    if (message.id && pending.has(message.id)) {
      const { resolve, reject } = pending.get(message.id);
      pending.delete(message.id);
      if (message.error) reject(new Error(JSON.stringify(message.error)));
      else resolve(message.result);
      return;
    }
    if (message.method === 'Runtime.exceptionThrown') {
      problems.push(`EXCEPTION ${JSON.stringify(message.params.exceptionDetails).slice(0, 300)}`);
    } else if (
      message.method === 'Runtime.consoleAPICalled' &&
      message.params.type === 'error'
    ) {
      problems.push(`CONSOLE ${JSON.stringify(message.params.args).slice(0, 300)}`);
    } else if (
      message.method === 'Log.entryAdded' &&
      message.params.entry.level === 'error'
    ) {
      problems.push(`LOG ${message.params.entry.text.slice(0, 300)}`);
    }
  };
  const send = (method, params = {}) =>
    new Promise((resolve, reject) => {
      const id = nextId++;
      pending.set(id, { resolve, reject });
      socket.send(JSON.stringify({ id, method, params }));
    });

  await send('Page.enable');
  await send('Runtime.enable');
  await send('Log.enable');
  await send('Network.enable');
  await send('Emulation.setDeviceMetricsOverride', {
    width: 1280,
    height: 900,
    deviceScaleFactor: 1,
    mobile: false,
  });

  const evaluate = async (expression) => {
    const result = await send('Runtime.evaluate', {
      expression,
      returnByValue: true,
      awaitPromise: true,
    });
    if (result.exceptionDetails) {
      throw new Error(`JS: ${JSON.stringify(result.exceptionDetails)}`);
    }
    return result.result.value;
  };
  const waitFor = async (expression, timeout = 6000) => {
    const started = Date.now();
    while (Date.now() - started < timeout) {
      if (await evaluate(expression)) return true;
      await sleep(120);
    }
    throw new Error(`délai dépassé : ${expression}`);
  };
  const navigate = async (target) => {
    await send('Page.navigate', { url: `${BASE_URL}${target}` });
    await sleep(600);
  };
  const shot = async (name) => {
    const { data } = await send('Page.captureScreenshot', { format: 'png' });
    fs.writeFileSync(path.join(OUT_DIR, name), Buffer.from(data, 'base64'));
    console.log(`capture ${name}`);
  };

  return { send, evaluate, waitFor, navigate, shot, problems, close: () => socket.close() };
}

async function main() {
  console.log(`base ${BASE_URL} — chrome ${CDP_URL}`);
  const cookie = await loginHttp();

  const booksPage = await request(cookie, '/admin/books');
  assert(booksPage.status === 200, `liste admin : ${booksPage.status}`);
  const tokenMatch = (await booksPage.text()).match(/name="csrf" value="([0-9a-f]{32})"/);
  assert(tokenMatch, 'jeton CSRF introuvable');
  const csrf = tokenMatch[1];

  const form = new FormData();
  form.set('csrf', csrf);
  form.set('access', 'free');
  form.set('file', new File([fs.readFileSync(FIXTURE)], 'visual-crud.zip', { type: 'application/zip' }));
  const imported = await request(cookie, '/admin/import', { method: 'POST', body: form });
  assert(imported.status === 303, `import : ${imported.status}`);
  console.log('création : pack visual-crud importé');

  let manifest = await json(cookie, `/v1/books/${BOOK_ID}`);
  assert(manifest.title === 'Visual CRUD', 'titre initial inattendu');
  assert(manifest.isFree === true, 'le livre importé devrait être gratuit');

  const cdp = await connectCdp();
  await cdp.send('Network.clearBrowserCookies');
  await cdp.navigate('/admin/login');
  await cdp.waitFor("document.querySelector('input[name=password]') !== null");
  await cdp.shot('01-login.png');
  await cdp.evaluate(
    `document.querySelector('input[name=password]').value = ${JSON.stringify(ADMIN_TOKEN)};` +
      "document.querySelector('form').submit();",
  );
  await cdp.waitFor("location.pathname === '/admin/books'");
  await cdp.waitFor("document.body.innerText.includes('visual-crud')");
  await cdp.shot('02-list-after-create.png');

  await cdp.navigate(`/admin/books/${BOOK_ID}`);
  await cdp.waitFor("document.body.innerText.includes('Visual CRUD')");
  await cdp.shot('03-detail.png');

  await cdp.navigate(`/admin/books/${BOOK_ID}/edit`);
  await cdp.waitFor("document.querySelector('form.edit') !== null");
  await cdp.shot('04-edit-form.png');
  await cdp.evaluate(`
    (() => {
      const form = document.querySelector('form.edit');
      form.querySelector('[name=title]').value = 'Visual CRUD modifié';
      form.querySelector('[name=title_fr]').value = 'CRUD visuel modifié';
      form.querySelector('[name=author]').value = 'Studio Visuel';
      form.querySelector('[name=level]').value = 'B1';
      form.querySelector('[name=description_fr]').value = 'Description mise à jour par le test visuel.';
      form.querySelector('input[name=access][value=paid]').checked = true;
      form.submit();
    })();
  `);
  await cdp.waitFor("location.pathname === '/admin/books'");
  console.log('mise à jour : formulaire soumis');

  manifest = await json(cookie, `/v1/books/${BOOK_ID}`);
  assert(manifest.title === 'Visual CRUD modifié', 'titre non mis à jour');
  assert(manifest.titleFr === 'CRUD visuel modifié', 'titre FR non mis à jour');
  assert(manifest.level === 'b1', 'niveau non normalisé en minuscules');
  assert(manifest.isFree === false, 'accès non mis à jour');
  const catalogue = await json(cookie, '/v1/catalogue');
  const entry = catalogue.books.find((book) => book.id === BOOK_ID);
  assert(entry && entry.title === 'Visual CRUD modifié', 'catalogue non mis à jour');

  const descriptor = await json(cookie, `/v1/books/${BOOK_ID}/download`);
  for (const item of descriptor.files) {
    const file = await request(cookie, item.downloadUrl);
    assert(file.status === 200, `${item.path} : ${file.status}`);
    const bytes = Buffer.from(await file.arrayBuffer());
    assert(bytes.length === item.sizeBytes, `${item.path} : taille incohérente`);
    assert(
      createHash('sha256').update(bytes).digest('hex') === item.sha256,
      `${item.path} : empreinte incohérente`,
    );
  }
  console.log('descripteur de téléchargement cohérent');

  await cdp.navigate(`/admin/books/${BOOK_ID}`);
  await cdp.waitFor("document.body.innerText.includes('Visual CRUD modifié')");
  await cdp.shot('05-detail-after-update.png');
  const detailText = await cdp.evaluate('document.body.innerText');
  assert(detailText.includes('Description mise à jour par le test visuel.'), 'description absente du détail');
  assert(detailText.includes('Payant'), 'badge payant absent du détail');

  await cdp.evaluate(`
    (() => {
      const form = document.querySelector('form.delete');
      form.querySelector('[name=confirm]').value = ${JSON.stringify(BOOK_ID)};
      form.submit();
    })();
  `);
  await cdp.waitFor("location.pathname === '/admin/books'");
  await cdp.waitFor(
    "document.querySelector('a[href=\"/admin/books/visual-crud\"]') === null",
  );
  await cdp.shot('06-list-after-delete.png');
  console.log('suppression : pack archivé et livre retiré');

  const deleted = await request(cookie, `/v1/books/${BOOK_ID}`);
  assert(deleted.status === 404, `manifeste après suppression : ${deleted.status}`);
  const finalCatalogue = await json(cookie, '/v1/catalogue');
  assert(
    finalCatalogue.books.every((book) => book.id !== BOOK_ID),
    'le livre supprimé est encore dans le catalogue',
  );

  assert(cdp.problems.length === 0, `erreurs navigateur : ${cdp.problems.join(' | ')}`);
  console.log(`OK — captures dans ${OUT_DIR}`);
  cdp.close();
}

main().catch((error) => {
  console.error(`ÉCHEC : ${error.message}`);
  process.exit(1);
});
