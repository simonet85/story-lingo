import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const BASE_URL = (process.env.BASE_URL || 'http://127.0.0.1:8766').replace(/\/$/, '');
const APP_URL = (process.env.APP_URL || 'http://127.0.0.1:8081').replace(/\/$/, '');
const CDP_URL = (process.env.CDP_URL || 'http://127.0.0.1:9223').replace(/\/$/, '');
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

async function form(cookie, target, fields) {
  return request(cookie, target, {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams(fields),
  });
}

async function connectCdp() {
  const targets = await (await fetch(`${CDP_URL}/json/list`)).json();
  const target =
    targets.find((item) => item.type === 'page' && item.url.includes(APP_URL)) ||
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
    width: 430,
    height: 932,
    deviceScaleFactor: 2,
    mobile: false,
  });
  await send('Page.addScriptToEvaluateOnNewDocument', {
    source: `
      localStorage.clear();
      localStorage.setItem('flutter.prefs.version', '1');
      localStorage.setItem('flutter.onboarding.completed', 'true');
      localStorage.setItem('flutter.user.level', '"b1"');
      localStorage.setItem('flutter.user.interests', '["mystery","gothic"]');
      localStorage.setItem('flutter.settings.theme_mode', '"light"');
    `,
  });

  const evaluate = async (expression) => {
    const result = await send('Runtime.evaluate', {
      expression,
      returnByValue: true,
      awaitPromise: true,
    });
    if (result.exceptionDetails) {
      throw new Error(`JS : ${JSON.stringify(result.exceptionDetails).slice(0, 300)}`);
    }
    return result.result.value;
  };
  const waitFor = async (expression, timeout = 15000, label = expression) => {
    const started = Date.now();
    while (Date.now() - started < timeout) {
      if (await evaluate(expression)) return true;
      await sleep(200);
    }
    throw new Error(`délai dépassé : ${label}`);
  };
  const semanticsText = () =>
    evaluate(`(() => [...document.querySelectorAll('flt-semantics')]
      .map((node) => (node.getAttribute('aria-label') || '') + ' ' + (node.textContent || ''))
      .join(' | '))()`);
  const enableSemantics = async () => {
    for (let attempt = 0; attempt < 120; attempt += 1) {
      const ready = await evaluate(`(() => {
        if (document.querySelectorAll('flt-semantics').length > 0) return true;
        const placeholder = document.querySelector('flt-semantics-placeholder');
        if (placeholder) placeholder.click();
        return false;
      })()`);
      if (ready) return;
      await sleep(500);
    }
    throw new Error('arbre de sémantique indisponible');
  };
  const findButton = async (needle) => {
    const raw = await evaluate(`(() => {
      const match = [...document.querySelectorAll('flt-semantics[role="button"]')]
        .find((node) => {
          const label = node.getAttribute('aria-label') || '';
          const text = node.textContent || '';
          return label.includes(${JSON.stringify(needle)}) || text.includes(${JSON.stringify(needle)});
        });
      if (!match) return null;
      match.scrollIntoView({ block: 'center' });
      const rect = match.getBoundingClientRect();
      return { x: rect.x, y: rect.y, width: rect.width, height: rect.height };
    })()`);
    return raw;
  };
  const clickButton = async (needle) => {
    for (let attempt = 0; attempt < 20; attempt += 1) {
      const rect = await findButton(needle);
      if (rect && rect.width > 0 && rect.height > 0) {
        await sleep(350);
        const x = rect.x + rect.width / 2;
        const y = rect.y + rect.height / 2;
        await send('Input.dispatchMouseEvent', { type: 'mouseMoved', x, y });
        await send('Input.dispatchMouseEvent', {
          type: 'mousePressed',
          x,
          y,
          button: 'left',
          buttons: 1,
          clickCount: 1,
        });
        await sleep(120);
        await send('Input.dispatchMouseEvent', {
          type: 'mouseReleased',
          x,
          y,
          button: 'left',
          buttons: 0,
          clickCount: 1,
        });
        return true;
      }
      await sleep(400);
    }
    throw new Error(`bouton introuvable : ${needle}`);
  };
  const openLibrary = async (run) => {
    await send('Page.navigate', {
      url: `${APP_URL}/?run=${run}#/library`,
    });
    await sleep(6000);
    await enableSemantics();
  };
  const shot = async (name) => {
    const { data } = await send('Page.captureScreenshot', { format: 'png' });
    fs.writeFileSync(path.join(OUT_DIR, name), Buffer.from(data, 'base64'));
    console.log(`capture ${name}`);
  };

  return { send, evaluate, waitFor, semanticsText, enableSemantics, clickButton, openLibrary, shot, problems, close: () => socket.close() };
}

async function main() {
  console.log(`api ${BASE_URL} — app ${APP_URL} — chrome ${CDP_URL}`);
  const cookie = await loginHttp();

  const booksPage = await request(cookie, '/admin/books');
  assert(booksPage.status === 200, `liste admin : ${booksPage.status}`);
  const tokenMatch = (await booksPage.text()).match(/name="csrf" value="([0-9a-f]{32})"/);
  assert(tokenMatch, 'jeton CSRF introuvable');
  const csrf = tokenMatch[1];

  const upload = new FormData();
  upload.set('csrf', csrf);
  upload.set('access', 'free');
  upload.set(
    'file',
    new File([fs.readFileSync(FIXTURE)], 'visual-crud.zip', { type: 'application/zip' }),
  );
  const imported = await request(cookie, '/admin/import', { method: 'POST', body: upload });
  assert(imported.status === 303, `import : ${imported.status}`);
  console.log('admin : pack visual-crud importé (gratuit)');

  let manifest = await json(cookie, `/v1/books/${BOOK_ID}`);
  assert(manifest.title === 'Visual CRUD', 'titre initial inattendu');
  assert(manifest.isFree === true, 'le livre importé devrait être gratuit');
  const chapterSummary = manifest.chapters[0];
  assert(chapterSummary.url, 'URL de chapitre absente du manifeste servi');
  const chapter = await json(cookie, `/v1/books/${BOOK_ID}/chapters/chapter-01`);
  const chapterText = chapter.paragraphs[0].segments.map((item) => item.text).join('');
  assert(chapterText === 'Hello visual world.', 'texte de chapitre distant inattendu');
  console.log('api : catalogue, manifeste et chapitre distants disponibles');

  const cdp = await connectCdp();

  await cdp.openLibrary('upload');
  await cdp.waitFor(
    `(() => [...document.querySelectorAll('flt-semantics[role="button"]')]
      .some((node) => ((node.getAttribute('aria-label') || '') + ' ' + (node.textContent || ''))
        .includes('Lire le chapitre 1')))()`,
    30000,
    'bouton Lire le chapitre 1 après import',
  );
  let text = await cdp.semanticsText();
  assert(text.includes('Visual CRUD'), 'titre du livre absent de la bibliothèque');
  assert(text.includes('CRUD visuel'), 'titre français absent de la bibliothèque');
  assert(!text.includes('Débloquer avec l’abonnement'), 'le livre gratuit est verrouillé');
  await cdp.shot('01-mobile-library-after-upload.png');
  console.log('app : livre importé visible et déverrouillé dans la bibliothèque');

  await cdp.clickButton('Lire le chapitre 1');
  await cdp.waitFor(
    `location.hash.includes('/read/${BOOK_ID}/chapter-01')`,
    10000,
    'navigation vers le lecteur',
  );
  await cdp.waitFor(
    `(() => [...document.querySelectorAll('flt-semantics')]
      .some((node) => ((node.getAttribute('aria-label') || '') + ' ' + (node.textContent || ''))
        .includes('Hello visual world.')))()`,
    20000,
    'texte du chapitre dans le lecteur',
  );
  text = await cdp.semanticsText();
  assert(text.includes('Un matin'), 'titre du chapitre absent du lecteur');
  assert(text.includes('Lecture'), 'en-tête du lecteur absent');
  await cdp.shot('02-mobile-reader-chapter.png');
  console.log('app : chapitre du livre importé consultable dans le lecteur');

  const edited = await form(cookie, `/admin/books/${BOOK_ID}/edit`, {
    csrf,
    title: 'Visual CRUD mobile',
    title_fr: 'CRUD mobile',
    author: 'Studio Mobile',
    level: 'B1',
    description_fr: 'Mis à jour depuis le back-office puis relu dans l’application.',
    access: 'free',
  });
  assert(edited.status === 303, `édition : ${edited.status}`);
  manifest = await json(cookie, `/v1/books/${BOOK_ID}`);
  assert(manifest.title === 'Visual CRUD mobile', 'titre non mis à jour');
  assert(manifest.level === 'b1', 'niveau non normalisé en minuscules');
  console.log('admin : métadonnées modifiées');

  await cdp.openLibrary('update');
  await cdp.waitFor(
    `document.body.innerText.includes('Visual CRUD mobile') ||
      [...document.querySelectorAll('flt-semantics')]
        .some((node) => ((node.getAttribute('aria-label') || '') + ' ' + (node.textContent || ''))
          .includes('Visual CRUD mobile'))`,
    30000,
    'titre mis à jour dans la bibliothèque',
  );
  text = await cdp.semanticsText();
  assert(text.includes('Studio Mobile'), 'auteur mis à jour absent');
  assert(text.includes('Mis à jour depuis le back-office'), 'description mise à jour absente');
  assert(text.includes('B1'), 'niveau mis à jour absent');
  await cdp.shot('03-mobile-library-after-update.png');
  console.log('app : mise à jour admin visible dans la bibliothèque');

  const removed = await form(cookie, `/admin/books/${BOOK_ID}/delete`, {
    csrf,
    confirm: BOOK_ID,
  });
  assert(removed.status === 303, `suppression : ${removed.status}`);
  const gone = await request(cookie, `/v1/books/${BOOK_ID}`);
  assert(gone.status === 404, `manifeste après suppression : ${gone.status}`);
  const catalogue = await json(cookie, '/v1/catalogue');
  assert(
    catalogue.books.every((book) => book.id !== BOOK_ID),
    'le livre supprimé est encore dans le catalogue',
  );
  console.log('admin : livre supprimé et retiré du catalogue');

  await cdp.openLibrary('delete');
  await cdp.waitFor(
    `[...document.querySelectorAll('flt-semantics')]
      .some((node) => ((node.getAttribute('aria-label') || '') + ' ' + (node.textContent || ''))
        .includes('Sleepy Hollow'))`,
    30000,
    'bibliothèque après suppression',
  );
  text = await cdp.semanticsText();
  assert(!text.includes('Visual CRUD'), 'le livre supprimé est encore dans la bibliothèque');
  assert(!text.includes('Studio Mobile'), 'les métadonnées supprimées sont encore visibles');
  await cdp.shot('04-mobile-library-after-delete.png');
  console.log('app : livre supprimé absent de la bibliothèque, catalogue de secours affiché');

  assert(cdp.problems.length === 0, `erreurs navigateur : ${cdp.problems.join(' | ')}`);
  console.log(`OK — captures dans ${OUT_DIR}`);
  cdp.close();
}

main().catch((error) => {
  console.error(`ÉCHEC : ${error.message}`);
  process.exit(1);
});
