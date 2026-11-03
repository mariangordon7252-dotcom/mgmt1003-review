// 生成 / 补全 data/zh/wNN.json：把每道题的英文原文（en / enOptions）列出来，留空的 q / options 等着填中文。
// 已经填好的翻译会保留；英文原文变了的题会把 en 更新并清空翻译，提示重译。
// 用法：node tools/zh-skeleton.js [w01 w02 ...]（不写则处理全部周）
const fs = require("fs"), path = require("path");
const root = path.join(__dirname, "..");
const pad = n => String(n).padStart(2, "0");
const names = process.argv.slice(2).length ? process.argv.slice(2) : [...Array(11)].map((_, i) => "w" + pad(i + 1));
fs.mkdirSync(path.join(root, "data", "zh"), { recursive: true });
for (const name of names) {
  const W = JSON.parse(fs.readFileSync(path.join(root, "data", name + ".json"), "utf8"));
  const lp = path.join(root, "data", "learn", name + ".json");
  const L = fs.existsSync(lp) ? JSON.parse(fs.readFileSync(lp, "utf8")) : { points: [] };
  const out = path.join(root, "data", "zh", name + ".json");
  const old = fs.existsSync(out) ? JSON.parse(fs.readFileSync(out, "utf8")).items : {};
  const items = {};
  const add = (id, q, options) => {
    const prev = old[id];
    const same = prev && prev.en === q && JSON.stringify(prev.enOptions || null) === JSON.stringify(options || null);
    const e = { en: q };
    if (options) e.enOptions = options;
    e.q = same ? prev.q : "";
    if (options) e.options = same ? prev.options : options.map(() => "");
    items[id] = e;
  };
  const w = W.week;
  (W.tf || []).forEach((q, i) => add(`w${w}-tf-${i}`, q.q));
  (W.mcq || []).forEach((q, i) => add(`w${w}-mcq-${i}`, q.q, q.options));
  (W.essay || []).forEach((q, i) => add(`w${w}-essay-${i}`, q.q));
  L.points.forEach(p => p.items.forEach((it, i) => add(`${p.id}-${i}`, it.q, it.type === "mcq" ? it.options : null)));
  // 一题一行，方便逐行编辑和看 diff
  const lines = Object.entries(items).map(([id, e]) => "    " + JSON.stringify(id) + ": " + JSON.stringify(e));
  fs.writeFileSync(out, '{\n  "week": ' + w + ',\n  "items": {\n' + lines.join(",\n") + "\n  }\n}\n");
  const todo = Object.values(items).filter(e => !e.q || (e.options && e.options.some(o => !o))).length;
  console.log(`${name}: ${lines.length} 题，待翻译 ${todo}`);
}
