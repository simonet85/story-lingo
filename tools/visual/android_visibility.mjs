import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const BASE_URL = (process.env.BASE_URL || 'http://127.0.0.1:8766').replace(/\/$/, '');
const ADMIN_TOKEN = process.env.ADMIN_TOKEN;
const ADB = process.env.ADB || 'adb';
const PKG = process.env.ANDROID_PACKAGE || 'com.storylingo.storylingo';
const ACTIVITY = process.env.ANDROID_ACTIVITY || `${PKG}/.MainActivity`;
const OUT_DIR = process.env.VISUAL_OUT || '.tmp/visual';
const BOOK_ID = 'visual-crud';
const TIMEOUT = Number(process.env.ANDROID_TIMEOUT || 120000);
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

const PREFS = `<?xml version='1.0' encoding='utf-8' standalone='yes' ?>
<map>
    <long name="flutter.prefs.version" value="1" />
    <boolean name="flutter.onboarding.completed" value="true" />
    <string name="flutter.user.level">a2</string>
    <string name="flutter.user.interests">VGhpcyBpcyB0aGUgcHJlZml4IGZvciBhIGxpc3Qu![&quot;mystery&quot;,&quot;gothic&quot;]</string>
    <string name="flutter.settings.theme_mode">light</string>
</map>
`;

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
const assert = (condition, message) => {
  if (!condition) throw new Error(message);
};
const adb = (args, options = {}) => execFileSync(ADB, args, { encoding: 'utf8', ...options });

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

async function form(cookie, target, fields) {
  return request(cookie, target, {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams(fields),
  });
}

async function adminSession() {
  const cookie = await loginHttp();
  const booksPage = await request(cookie, '/admin/books');
  assert(booksPage.status === 200, `liste admin : ${booksPage.status}`);
  const tokenMatch = (await booksPage.text()).match(/name="csrf" value="([0-9a-f]{32})"/);
  assert(tokenMatch, 'jeton CSRF introuvable');
  return { cookie, csrf: tokenMatch[1] };
}

async function removeIfPresent({ cookie, csrf }) {
  const page = await (await request(cookie, '/admin/books')).text();
  if (!page.includes(`/admin/books/${BOOK_ID}`)) return;
  const removed = await form(cookie, `/admin/books/${BOOK_ID}/delete`, {
    csrf,
    confirm: BOOK_ID,
  });
  assert(removed.status === 303, `nettoyage : ${removed.status}`);
  console.log('admin : pack de test précédent supprimé');
}

async function importPack({ cookie, csrf }) {
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
}

async function editPack({ cookie, csrf }) {
  const edited = await form(cookie, `/admin/books/${BOOK_ID}/edit`, {
    csrf,
    title: 'Visual CRUD mobile',
    title_fr: 'CRUD mobile',
    author: 'Studio Mobile',
    level: 'B1',
    description_fr: 'Livre mis à jour depuis l’admin web pour l’émulateur Android.',
    access: 'free',
  });
  assert(edited.status === 303, `édition : ${edited.status}`);
  console.log('admin : métadonnées modifiées');
}

async function removePack({ cookie, csrf }) {
  const removed = await form(cookie, `/admin/books/${BOOK_ID}/delete`, {
    csrf,
    confirm: BOOK_ID,
  });
  assert(removed.status === 303, `suppression : ${removed.status}`);
  console.log('admin : livre supprimé');
}

async function dumpUi() {
  adb(['shell', 'uiautomator', 'dump', '/sdcard/ui.xml'], { stdio: 'ignore' });
  return adb(['shell', 'cat', '/sdcard/ui.xml']);
}

async function waitForText(text, timeout = TIMEOUT) {
  const started = Date.now();
  while (Date.now() - started < timeout) {
    try {
      if ((await dumpUi()).includes(text)) return;
    } catch {
      // uiautomator can be briefly unavailable right after a boot.
    }
    await sleep(500);
  }
  throw new Error(`texte absent après ${timeout} ms : ${text}`);
}

function nodes(xml) {
  const result = [];
  for (const tag of xml.match(/<node\b[^>]*>/g) || []) {
    const desc = tag.match(/content-desc="([^"]*)"/);
    const bounds = tag.match(/bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"/);
    if (!desc || !bounds) continue;
    const label = desc[1]
      .replaceAll('&quot;', '"')
      .replaceAll('&amp;', '&')
      .replaceAll('&#10;', '\n');
    if (!label) continue;
    const [, x1, y1, x2, y2] = bounds;
    result.push({
      label,
      x: Math.round((Number(x1) + Number(x2)) / 2),
      y: Math.round((Number(y1) + Number(y2)) / 2),
      top: Number(y1),
    });
  }
  return result;
}

async function tap(label) {
  const matches = nodes(await dumpUi())
    .filter(
      (node) =>
        node.label === label ||
        node.label.startsWith(`${label}\n`) ||
        node.label.startsWith(label),
    )
    .sort((a, b) => a.top - b.top);
  assert(matches.length, `aucun nœud « ${label} »`);
  const target = matches[0];
  console.log(`tap « ${target.label.split('\n')[0]} » @ ${target.x},${target.y}`);
  adb(['shell', 'input', 'tap', String(target.x), String(target.y)]);
}

async function shot(name) {
  const buffer = execFileSync(ADB, ['exec-out', 'screencap', '-p'], {
    maxBuffer: 50 * 1024 * 1024,
  });
  fs.writeFileSync(path.join(OUT_DIR, name), buffer);
  console.log(`capture ${name}`);
}

async function restartApp() {
  adb(['shell', 'am', 'force-stop', PKG]);
  adb(['shell', 'pm', 'clear', PKG]);
  adb(['shell', 'am', 'start', '-W', '-n', ACTIVITY], { stdio: 'ignore' });
  await sleep(2500);
  adb(['shell', 'am', 'force-stop', PKG]);
  adb(['shell', 'run-as', PKG, 'mkdir', '-p', 'shared_prefs']);
  try {
    adb(['shell', `run-as ${PKG} sh -c 'cat > shared_prefs/FlutterSharedPreferences.xml'`], {
      input: PREFS,
    });
  } catch {
    const staged = path.join(OUT_DIR, 'android-prefs.xml');
    fs.writeFileSync(staged, PREFS);
    adb(['push', staged, '/data/local/tmp/storylingo-prefs.xml'], { stdio: 'ignore' });
    adb(
      [
        'shell',
        `run-as ${PKG} sh -c 'cp /data/local/tmp/storylingo-prefs.xml shared_prefs/FlutterSharedPreferences.xml'`,
      ],
      { stdio: 'ignore' },
    );
    adb(['shell', 'rm', '/data/local/tmp/storylingo-prefs.xml']);
  }
  const check = adb([
    'shell', 'run-as', PKG, 'cat', 'shared_prefs/FlutterSharedPreferences.xml',
  ]);
  assert(check.includes('flutter.onboarding.completed'), 'préfs non écrites');
  adb(['shell', 'am', 'start', '-W', '-n', ACTIVITY], { stdio: 'ignore' });
  console.log('app relancée avec préfs propres');
}

async function waitForLibraryText(text) {
  for (let attempt = 0; attempt < 3; attempt += 1) {
    try {
      await waitForText(text);
      return;
    } catch (error) {
      if (!(await dumpUi()).includes('Catalogue indisponible')) throw error;
      await tap('Actualiser le catalogue');
      await sleep(1000);
    }
  }
  throw new Error(`texte absent de la bibliothèque : ${text}`);
}

async function openLibrary() {
  await waitForText('Commencer la session');
  await tap('Bibliothèque');
}

async function main() {
  const devices = adb(['devices']).trim().split('\n').slice(1).filter(Boolean);
  assert(
    devices.some((line) => /\tdevice$/.test(line)),
    'aucun émulateur connecté (adb devices)',
  );
  assert(
    adb(['shell', 'pm', 'list', 'packages', PKG]).includes(`package:${PKG}`),
    `${PKG} n'est pas installé sur l'émulateur`,
  );
  console.log(`api ${BASE_URL} — appareil ${devices[0].split('\t')[0]}`);

  const session = await adminSession();
  await removeIfPresent(session);
  await importPack(session);

  const catalogue = await (await request(session.cookie, '/v1/catalogue')).json();
  assert(
    catalogue.books.some((book) => book.id === BOOK_ID),
    'le livre importé est absent du catalogue',
  );
  console.log('api : catalogue, manifeste et chapitre distants disponibles');

  await restartApp();
  await openLibrary();
  await waitForLibraryText('Visual CRUD');
  const before = await dumpUi();
  assert(before.includes('CRUD visuel'), 'titre français absent de la bibliothèque');
  assert(before.includes('Livre de test visuel.'), 'description absente de la bibliothèque');
  await shot('android-10-library-uploaded.png');
  console.log('app : livre importé visible dans la bibliothèque');

  await tap('Lire le chapitre 1');
  await waitForText('Hello visual world.');
  const reader = await dumpUi();
  assert(reader.includes('Un matin'), 'titre du chapitre absent du lecteur');
  assert(reader.includes('Lecture'), 'en-tête du lecteur absent');
  await shot('android-11-reader-uploaded.png');
  console.log('app : chapitre du livre importé consultable dans le lecteur');

  await editPack(session);
  await restartApp();
  await openLibrary();
  await waitForLibraryText('Visual CRUD mobile');
  const edited = await dumpUi();
  assert(edited.includes('Studio Mobile'), 'auteur mis à jour absent');
  assert(edited.includes('Livre mis à jour depuis l’admin web'), 'description mise à jour absente');
  await shot('android-12-library-edited.png');
  console.log('app : mise à jour admin visible dans la bibliothèque');

  await removePack(session);
  const gone = await request(session.cookie, `/v1/books/${BOOK_ID}`);
  assert(gone.status === 404, `manifeste après suppression : ${gone.status}`);
  await restartApp();
  await openLibrary();
  await waitForLibraryText('Sleepy Hollow');
  const after = await dumpUi();
  assert(!after.includes('Visual CRUD'), 'le livre supprimé est encore dans la bibliothèque');
  await shot('android-13-library-after-delete.png');
  console.log('app : livre supprimé absent de la bibliothèque');
  console.log(`OK — captures dans ${OUT_DIR}`);
}

main().catch((error) => {
  console.error(`ÉCHEC : ${error.message}`);
  process.exit(1);
});
