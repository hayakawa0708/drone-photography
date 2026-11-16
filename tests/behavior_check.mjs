// drone_checker.html の関数を取り出して Node 上で実際に動かす振る舞いテスト。
// test_static_security.py から呼ばれる。失敗があれば終了コード1。
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import vm from 'node:vm';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const html = readFileSync(join(root, 'drone_checker.html'), 'utf8');

function extract(name) {
  const m = new RegExp('(async\\s+)?function\\s+' + name + '\\s*\\(').exec(html);
  if (!m) throw new Error('function not found: ' + name);
  let i = html.indexOf('{', html.indexOf(')', m.index));
  let depth = 0;
  for (let j = i; j < html.length; j++) {
    if (html[j] === '{') depth++;
    else if (html[j] === '}' && --depth === 0) return html.slice(m.index, j + 1);
  }
  throw new Error('unbalanced: ' + name);
}

const results = [];
const check = (name, ok) => results.push({ name, ok: !!ok });

// ---------- インポート検証 ----------
{
  const ctx = vm.createContext({});
  vm.runInContext(extract('isPlainObject') + extract('validateBackupData'), ctx);
  const ok = d => { try { ctx.validateBackupData(d); return true; } catch { return false; } };
  const base = { exportedAt: '2026-11-16T00:00:00Z' };
  const log = (o = {}) => ({ id: 1, date: '2026-11-01', duration: 10, purpose: '空撮', ...o });
  check('正常なバックアップは通る', ok({ ...base, pilot: { name: 'A', chk_cert2: true }, flightLog: [log(), log({ id: 2 })], history: [{ date: 'x', catKey: 'c1', stopN: 0, warnN: 2 }] }));
  check('IDの重複は拒否', !ok({ ...base, flightLog: [log(), log()] }));
  check('日付が数値の記録は拒否', !ok({ ...base, flightLog: [log({ date: 42 })] }));
  check('飛行時間が文字列の記録は拒否', !ok({ ...base, flightLog: [log({ duration: '10' })] }));
  check('履歴の件数欄にHTMLは拒否', !ok({ ...base, history: [{ stopN: '<img src=x onerror=alert(1)>' }] }));
  check('履歴の件数欄が負数は拒否', !ok({ ...base, history: [{ stopN: -1 }] }));
  check('包括申請フラグが文字列"false"は拒否', !ok({ ...base, pilot: { 'chk_blanket-did': 'false' } }));
  check('操縦者がnullのバックアップは通る', ok({ ...base, pilot: null }));
}

// ---------- 履歴の件数表示 ----------
{
  const ctx = vm.createContext({});
  vm.runInContext(extract('histCount'), ctx);
  check('件数: 整数はそのまま', ctx.histCount(3) === '3');
  check('件数: HTML文字列は ? に置換', ctx.histCount('<b>') === '?');
}

// ---------- DID判定（三値） ----------
async function didWith(fetchImpl) {
  const ctx = vm.createContext({
    Image: class { set src(_) { setTimeout(() => this.onerror(new Error('wms down')), 0); } },
    document: { createElement: () => ({}) },
    fetch: fetchImpl,
    Math, setTimeout,
  });
  vm.runInContext(extract('getDIDStatusDetail') + extract('getDIDStatus'), ctx);
  return ctx.getDIDStatus(35.68, 139.76);
}
check('タイル500はDID不明(null)', (await didWith(async () => ({ ok: false, status: 500 }))) === null);
check('タイル404はDID外(false)', (await didWith(async () => ({ ok: false, status: 404 }))) === false);
check('タイル200はDID可能性あり(true)', (await didWith(async () => ({ ok: true, status: 200 }))) === true);
check('通信例外はDID不明(null)', (await didWith(async () => { throw new Error('offline'); })) === null);

// ---------- 古い地点のDID結果を捨てる ----------
{
  let resolveA;
  const badge = { className: '', textContent: '' };
  const ctx = vm.createContext({ document: { getElementById: () => badge } });
  vm.runInContext('var locGen=1, autoDID=null; var getDIDStatusDetail=()=>new Promise(r=>{resolveB=r});', ctx);
  vm.runInContext(extract('checkDID'), ctx);
  // 地点A（世代1）の判定中に地点B（世代2）へ移動 → Bは「DID内」→ その後Aの「DID外」が届く
  ctx.getDIDStatusDetail = () => new Promise(r => { resolveA = r; });
  const pA = ctx.checkDID(0, 0, 1);
  vm.runInContext('locGen=2', ctx);
  ctx.getDIDStatusDetail = async () => ({ did: true, source: 'wms' });
  await ctx.checkDID(0, 0, 2);
  resolveA({ did: false, source: 'wms' });
  await pA;
  check('古い地点の結果で上書きしない', vm.runInContext('autoDID', ctx) === true);
}

// ---------- CSVの数式対策 ----------
{
  let captured = '';
  const ctx = vm.createContext({
    Blob: class { constructor(parts) { captured = parts.join(''); } },
    URL: { createObjectURL: () => 'blob:x', revokeObjectURL: () => {} },
    document: { createElement: () => ({ click() {} }), body: { appendChild() {}, removeChild() {} } },
    Date,
  });
  vm.runInContext(extract('buildCSV'), ctx);
  ctx.buildCSV([{ date: '2026-11-01', note: '=HYPERLINK("x")', purpose: '+1', pilotName: '@a', duration: 10 }]);
  check('CSV: =で始まる備考は先頭に\'', captured.includes('"\'=HYPERLINK(""x"")"'));
  check('CSV: +と@も無害化', captured.includes('"\'+1"') && captured.includes('"\'@a"'));
  check('CSV: 数値の飛行時間はそのまま', captured.includes('"10"'));
}

// ---------- インポート途中の保存失敗で元に戻す ----------
async function runImport(data, quota) {
  const store = new Map([['pilot', '{"name":"旧"}'], ['log', '[]']]);
  const size = () => [...store.values()].reduce((s, v) => s + v.length, 0);
  const localStorage = {
    getItem: k => (store.has(k) ? store.get(k) : null),
    setItem: (k, v) => {
      const old = store.get(k) || '';
      if (size() - old.length + v.length > quota) throw new Error('QuotaExceeded');
      store.set(k, v);
    },
    removeItem: k => store.delete(k),
  };
  const alerts = []; const calls = [];
  const el = () => ({ style: {}, textContent: '' });
  const ctx = vm.createContext({
    localStorage, alert: m => alerts.push(m), confirm: () => true, setTimeout,
    PILOT_KEY: 'pilot', LOG_KEY: 'log', PF_KEY: 'pf', HIST_KEY: 'hist', MAX_BACKUP_FILE_BYTES: 2e6,
    document: { getElementById: el },
    FileReader: class { readAsText() { this.onload({ target: { result: JSON.stringify(data) } }); } },
    clearPilotForm: () => calls.push('clear'), loadPilot: () => calls.push('load'),
    renderPilotSummary() {}, renderPreflight() {}, renderLogList() {},
  });
  vm.runInContext(extract('isPlainObject') + extract('validateBackupData') + extract('importAllData'), ctx);
  ctx.importAllData({ target: { files: [{ size: 10 }], value: 'x' } });
  return { store, alerts, calls };
}
{
  const base = { exportedAt: '2026-11-16T00:00:00Z' };
  // プロフィールは入るが、大きな飛行記録で容量不足になる
  const big = { ...base, pilot: { name: '新' }, flightLog: [{ id: 1, note: 'x'.repeat(500) }] };
  const r = await runImport(big, 200);
  check('保存失敗時は元のプロフィールに戻る', r.store.get('pilot') === '{"name":"旧"}' && r.store.get('log') === '[]');
  check('保存失敗時は「元のまま」と案内', r.alerts.some(a => a.includes('元のデータのまま')));
  const ok = await runImport({ ...base, pilot: { name: '新' } }, 10000);
  check('一部だけのプロフィールでも先に入力欄を全部消す', ok.calls.indexOf('clear') !== -1 && ok.calls.indexOf('clear') < ok.calls.lastIndexOf('load'));
}

// ---------- ⅡAの包括申請判定に夜間・目視外・30m未満も含める ----------
check('ⅡAの包括判定に夜間・目視外・30m未満', html.includes('(!night||blanketNight)&&(!bvlos||blanketBvlos)&&(!close||blanketClose);catDesc=_c2aCov'));

// ---------- Excel出力で $ を置換構文にしない ----------
check('Excel: 置換は関数で行う', /xml = xml\.replace\(pat, \(_m, style\) =>/.test(html));

let fail = 0;
for (const r of results) { console.log((r.ok ? 'OK   ' : 'FAIL ') + r.name); if (!r.ok) fail++; }
console.log(`${results.length - fail}/${results.length} passed`);
process.exit(fail ? 1 : 0);
