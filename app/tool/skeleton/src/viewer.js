// 白骨观 3D 骨骼查看器：单指旋转、双指缩放和平移，轻点骨骼通过 Bones 通道告诉 Flutter 选中了哪块骨头。
import * as THREE from 'three';
import { GLTFLoader } from 'three/examples/jsm/loaders/GLTFLoader.js';
import { OrbitControls } from 'three/examples/jsm/controls/OrbitControls.js';
import { MeshoptDecoder } from 'three/examples/jsm/libs/meshopt_decoder.module.js';

const BONE = 0xe9dfc9;
const SELECTED = 0xd9822b;

function post(msg) {
  if (window.Bones) window.Bones.postMessage(JSON.stringify(msg));
}

// 任何启动错误（例如手机不支持 WebGL）都报给 Flutter 显示，而不是一直转圈。
window.addEventListener('error', (e) => post({ type: 'error', message: String(e.message || e.error) }));
window.addEventListener('unhandledrejection', (e) => post({ type: 'error', message: String(e.reason) }));

const canvas = document.getElementById('view');
const renderer = new THREE.WebGLRenderer({ canvas, antialias: true });
renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
renderer.outputColorSpace = THREE.SRGBColorSpace;

const scene = new THREE.Scene();
scene.background = new THREE.Color(0x1c1b19);

const camera = new THREE.PerspectiveCamera(35, 1, 0.01, 100);
scene.add(camera);
scene.add(new THREE.HemisphereLight(0xffffff, 0x4a4036, 1.6));
const key = new THREE.DirectionalLight(0xffffff, 2.2);
key.position.set(1, 1.5, 2);
camera.add(key);

const controls = new OrbitControls(camera, canvas);
controls.enableDamping = true;
controls.dampingFactor = 0.12;
controls.zoomToCursor = true;
controls.touches = { ONE: THREE.TOUCH.ROTATE, TWO: THREE.TOUCH.DOLLY_PAN };

const boneMaterial = new THREE.MeshStandardMaterial({ color: BONE, roughness: 0.65, metalness: 0 });
const selectedMaterial = new THREE.MeshStandardMaterial({
  color: SELECTED,
  emissive: SELECTED,
  emissiveIntensity: 0.35,
  roughness: 0.5,
});

const meshes = [];
let selected = null;
let home = null;
let model = null;

// 安卓 WebView 常在视图还是 0×0 时就加载页面，这时不能取景，否则相机位置变成 NaN、
// 骨架永远不显示；等拿到真实尺寸后再取景。
function resize() {
  const w = window.innerWidth;
  const h = window.innerHeight;
  if (!w || !h) return;
  renderer.setSize(w, h, false);
  camera.aspect = w / h;
  camera.updateProjectionMatrix();
  if (model && !home) frame(model);
}

function frame(object) {
  const box = new THREE.Box3().setFromObject(object);
  const size = box.getSize(new THREE.Vector3());
  const center = box.getCenter(new THREE.Vector3());
  const fov = THREE.MathUtils.degToRad(camera.fov);
  const dist = Math.max(size.y / 2 / Math.tan(fov / 2), size.x / 2 / Math.tan(fov / 2) / camera.aspect) * 1.15;
  home = { target: center, position: center.clone().add(new THREE.Vector3(0, 0, dist)) };
  controls.minDistance = size.y * 0.03;
  controls.maxDistance = dist * 3;
  camera.near = dist / 200;
  camera.far = dist * 10;
  camera.updateProjectionMatrix();
  resetView();
}

function resetView() {
  if (!home) return;
  camera.position.copy(home.position);
  controls.target.copy(home.target);
  controls.update();
}

function select(mesh) {
  if (selected) selected.material = boneMaterial;
  selected = mesh;
  if (mesh) mesh.material = selectedMaterial;
}

// 按下和抬起位置接近、时间短才算轻点，避免旋转、缩放结束时误选。
const raycaster = new THREE.Raycaster();
const down = new Map();
let multiTouch = false;
canvas.addEventListener('pointerdown', (e) => {
  down.set(e.pointerId, { x: e.clientX, y: e.clientY, t: performance.now() });
  if (down.size > 1) multiTouch = true;
});
canvas.addEventListener('pointercancel', (e) => down.delete(e.pointerId));
canvas.addEventListener('pointerup', (e) => {
  const start = down.get(e.pointerId);
  down.delete(e.pointerId);
  const wasMulti = multiTouch;
  if (down.size === 0) multiTouch = false;
  if (!start || wasMulti) return;
  if (Math.hypot(e.clientX - start.x, e.clientY - start.y) > 8 || performance.now() - start.t > 500) return;
  const rect = canvas.getBoundingClientRect();
  const ndc = new THREE.Vector2(
    ((e.clientX - rect.left) / rect.width) * 2 - 1,
    -((e.clientY - rect.top) / rect.height) * 2 + 1,
  );
  raycaster.setFromCamera(ndc, camera);
  const hit = raycaster.intersectObjects(meshes, false)[0];
  select(hit ? hit.object : null);
  post({ type: 'select', id: hit ? hit.object.name : null });
});

window.resetView = resetView;
window.clearSelection = () => select(null);

function base64ToBuffer(b64) {
  const bin = atob(b64);
  const bytes = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
  return bytes.buffer;
}

async function load() {
  await MeshoptDecoder.ready;
  const loader = new GLTFLoader();
  loader.setMeshoptDecoder(MeshoptDecoder);
  const gltf = await loader.parseAsync(base64ToBuffer(window.SKELETON_GLB), '');
  window.SKELETON_GLB = null;
  gltf.scene.traverse((o) => {
    if (!o.isMesh) return;
    o.material = boneMaterial;
    // gltf-transform 会把网格挂在同名节点下，选中时上报节点名（FMA 编号）。
    if (!o.name || o.name.startsWith('mesh')) o.name = o.parent?.name || o.name;
    meshes.push(o);
  });
  model = gltf.scene;
  scene.add(model);
  resize();
  post({ type: 'ready', count: meshes.length });
}

window.addEventListener('resize', resize);
if (window.ResizeObserver) new ResizeObserver(resize).observe(document.body);
resize();
renderer.setAnimationLoop(() => {
  controls.update();
  renderer.render(scene, camera);
});
load().catch((err) => post({ type: 'error', message: String((err && err.message) || err) }));
