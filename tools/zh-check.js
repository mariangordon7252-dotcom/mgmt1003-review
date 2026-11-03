// 校验 data/zh/wNN.json：每道题都有中文、选项数对得上、英文原文和题库一致、中文里没有英文双引号。
// 用法：node tools/zh-check.js [w01 ...]
const fs = require("fs"), path = require("path");
const root = path.join(__dirname, "..");
const pad = n => String(n).padStart(2, "0");
const names = process.argv.slice(2).length ? process.argv.slice(2) : [...Array(11)].map((_, i) => "w" + pad(i + 1));
let bad = 0;
for (const name of names) {
  const W = JSON.parse(fs.readFileSync(path.join(root, "data", name + ".json"), "utf8"));
  const L = JSON.parse(fs.readFileSync(path.join(root, "data", "learn", name + ".json"), "utf8"));
  let Z;
  try { Z = JSON.parse(fs.readFileSync(path.join(root, "data", "zh", name + ".json"), "utf8")); }
  catch (e) { console.log(`${name}: JSON 无效 — ${e.message}`); bad++; continue; }
  const want = {};
  const w = W.week;
  (W.tf || []).forEach((q, i) => want[`w${w}-tf-${i}`] = [q.q]);
  (W.mcq || []).forEach((q, i) => want[`w${w}-mcq-${i}`] = [q.q, q.options]);
  (W.essay || []).forEach((q, i) => want[`w${w}-essay-${i}`] = [q.q]);
  L.points.forEach(p => p.items.forEach((it, i) => want[`${p.id}-${i}`] = [it.q, it.type === "mcq" ? it.options : null]));
  const issues = [];
  for (const [id, [q, opts]] of Object.entries(want)) {
    const e = Z.items[id];
    if (!e) { issues.push(`${id} 缺少`); continue; }
    if (e.en !== q) issues.push(`${id} 英文原文与题库不一致（重新运行 zh-skeleton）`);
    if (!e.q || !/[一-鿿]/.test(e.q)) issues.push(`${id} 题干没有中文`);
    if (opts) {
      if (!Array.isArray(e.options) || e.options.length !== opts.length) issues.push(`${id} 选项数不对`);
      else e.options.forEach((o, k) => { if (!o) issues.push(`${id} 选项 ${"ABCD"[k]} 为空`); });
    }
    for (const s of [e.q, ...(e.options || [])]) if (s && s.includes('"')) issues.push(`${id} 含英文双引号`);
  }
  for (const id of Object.keys(Z.items)) if (!want[id]) issues.push(`${id} 题库里已不存在`);
  console.log(`${name}: ${Object.keys(want).length} 题，${issues.length ? "问题 " + issues.length + " 条" : "没有问题"}`);
  issues.slice(0, 40).forEach(s => console.log("  " + s));
  bad += issues.length;
}
process.exitCode = bad ? 1 : 0;
