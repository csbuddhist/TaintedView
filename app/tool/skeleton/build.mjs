// 生成 App 的白骨观资源 assets/skeleton/：
//   node build.mjs <build_skeleton.py 输出目录>
// 简化并压缩骨骼模型，转成 model.js（base64，供 WebView 通过 <script> 离线加载，绕开 file:// 的跨域限制），
// 打包查看器 viewer.js，并复制 index.html 和 bones.json。
import { execFileSync } from 'node:child_process';
import { copyFileSync, mkdirSync, readFileSync, statSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { build } from 'esbuild';

const here = dirname(fileURLToPath(import.meta.url));
const input = process.argv[2];
if (!input) {
  console.error('用法：node build.mjs <build_skeleton.py 输出目录>');
  process.exit(1);
}
const out = join(here, '../../assets/skeleton');
mkdirSync(out, { recursive: true });

const cli = join(here, 'node_modules/.bin/gltf-transform');
const run = (...args) => execFileSync(cli, args, { stdio: 'inherit' });
const welded = join(input, 'skeleton_weld.glb');
const simplified = join(input, 'skeleton_simplified.glb');
const final = join(input, 'skeleton.glb');
run('weld', join(input, 'skeleton_raw.glb'), welded);
// 不用 optimize：它会把同材质网格合并（join），每块骨头就无法单独点选了。
run('simplify', welded, simplified, '--ratio', '0.2', '--error', '0.002');
run('meshopt', simplified, final, '--level', 'medium');

const glb = readFileSync(final);
writeFileSync(join(out, 'model.js'), `window.SKELETON_GLB="${glb.toString('base64')}";\n`);
copyFileSync(join(input, 'bones.json'), join(out, 'bones.json'));
copyFileSync(join(here, 'src/index.html'), join(out, 'index.html'));
await build({
  entryPoints: [join(here, 'src/viewer.js')],
  outfile: join(out, 'viewer.js'),
  bundle: true,
  minify: true,
  format: 'iife',
  target: ['es2019'],
  legalComments: 'eof',
});

for (const f of ['model.js', 'viewer.js', 'bones.json', 'index.html']) {
  console.log(`${f}\t${(statSync(join(out, f)).size / 1024).toFixed(0)} KB`);
}
