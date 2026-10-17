#!/usr/bin/env python3
"""BodyParts3D → 白骨观骨骼模型。

从 BodyParts3D 4.0（PART-OF 版本）挑出全部骨骼和软骨，每块骨头合并成一个网格，
节点名用 FMA 编号，输出未压缩的 skeleton_raw.glb 和中英文骨名 bones.json。
随后由 build.mjs 做简化、压缩并生成 App 资源。

用法：
    python3 build_skeleton.py <BodyParts3D 目录> <输出目录>

BodyParts3D 目录需包含 https://dbarchive.biosciencedbc.jp/en/bodyparts3d/download.html 下载的
partof_BP3D_4.0_obj_99.zip 解压后的 OBJ 文件，以及 partof_element_parts.txt。
"""

from __future__ import annotations

import json
import re
import struct
import sys
from collections import defaultdict
from pathlib import Path

import numpy as np

# 名称里含这些词的概念算作骨骼（含肋软骨、椎间盘）。
BONE_TERMS = [
    'frontal bone', 'occipital bone', 'parietal bone', 'temporal bone', 'sphenoid bone', 'ethmoid',
    'vomer', 'mandible', 'maxilla', 'zygomatic bone', 'nasal bone', 'lacrimal bone', 'palatine bone',
    'inferior nasal concha', 'hyoid bone', 'atlas', 'axis', 'vertebra', 'sacrum', 'coccyx', 'rib',
    'costal cartilage', 'manubrium', 'body of sternum', 'xiphoid process', 'clavicle', 'scapula',
    'humerus', 'radius', 'ulna', 'scaphoid', 'lunate', 'triquetral', 'pisiform', 'trapezium',
    'trapezoid', 'capitate', 'hamate', 'metacarpal bone', 'phalanx', 'hip bone', 'pelvic girdle',
    'femur', 'patella', 'tibia', 'fibula', 'talus', 'calcaneus', 'navicular bone', 'cuboid bone',
    'cuneiform bone', 'metatarsal bone', 'intervertebral disk',
]
EXCLUDE = re.compile(r'artery|vein|nerve|muscle|ligament|tendon|tract|part of|skeleton|joint|bursa|eye|symphysis')
BONE_RE = re.compile(r'\b(' + '|'.join(re.escape(t) for t in BONE_TERMS) + r')\b')

ORDINAL = {
    'first': '一', 'second': '二', 'third': '三', 'fourth': '四', 'fifth': '五', 'sixth': '六',
    'seventh': '七', 'eighth': '八', 'ninth': '九', 'tenth': '十', 'eleventh': '十一', 'twelfth': '十二',
}
SIMPLE = {
    'frontal bone': '额骨', 'occipital bone': '枕骨', 'parietal bone': '顶骨', 'temporal bone': '颞骨',
    'sphenoid bone': '蝶骨', 'ethmoid': '筛骨', 'vomer': '犁骨', 'mandible': '下颌骨', 'maxilla': '上颌骨',
    'zygomatic bone': '颧骨', 'nasal bone': '鼻骨', 'lacrimal bone': '泪骨', 'palatine bone': '腭骨',
    'inferior nasal concha': '下鼻甲', 'hyoid bone': '舌骨', 'atlas': '寰椎（第一颈椎）',
    'axis': '枢椎（第二颈椎）', 'sacrum': '骶骨', 'coccyx': '尾骨', 'manubrium': '胸骨柄',
    'body of sternum': '胸骨体', 'xiphoid process': '剑突', 'clavicle': '锁骨', 'scapula': '肩胛骨',
    'humerus': '肱骨', 'radius': '桡骨', 'ulna': '尺骨', 'scaphoid': '手舟骨', 'lunate': '月骨',
    'triquetral': '三角骨', 'pisiform': '豌豆骨', 'trapezium': '大多角骨', 'trapezoid': '小多角骨',
    'capitate': '头状骨', 'hamate': '钩骨', 'hip bone': '髋骨', 'pelvic girdle': '髋骨', 'femur': '股骨',
    'patella': '髌骨', 'tibia': '胫骨', 'fibula': '腓骨', 'talus': '距骨', 'calcaneus': '跟骨',
    'navicular bone of foot': '足舟骨', 'cuboid bone': '骰骨', 'medial cuneiform bone': '内侧楔骨',
    'intermediate cuneiform bone': '中间楔骨', 'lateral cuneiform bone': '外侧楔骨',
    'intervertebral disk': '椎间盘',
}
REGION = {'cervical': '颈', 'thoracic': '胸', 'lumbar': '腰'}
FINGER = {'thumb': '拇指', 'index finger': '示指', 'middle finger': '中指', 'ring finger': '环指',
          'little finger': '小指'}
TOE = {'big toe': '拇趾', 'second toe': '第二趾', 'third toe': '第三趾', 'fourth toe': '第四趾',
       'little toe': '小趾'}
SEGMENT = {'proximal': '近节', 'middle': '中节', 'distal': '远节'}


def to_chinese(en: str) -> str:
    """按 FMA 英文名拼出中文骨名，例如 right patella → 右髌骨。"""
    side = ''
    m = re.search(r'\b(right|left) ', en)
    if m:
        side = '右' if m.group(1) == 'right' else '左'
        en = en.replace(m.group(0), '', 1)

    if m := re.fullmatch(r'(proximal|middle|distal) phalanx of (.+)', en):
        seg, digit = m.groups()
        if digit in FINGER:
            return f'{side}{FINGER[digit]}{SEGMENT[seg]}指骨'
        return f'{side}{TOE[digit]}{SEGMENT[seg]}趾骨'
    if m := re.fullmatch(r'intervertebral disk of (.+)', en):
        return f'{to_chinese(m.group(1)).split("（")[0]}椎间盘'
    if m := re.fullmatch(r'(\w+) (cervical|thoracic|lumbar) vertebra', en):
        return f'第{ORDINAL[m.group(1)]}{REGION[m.group(2)]}椎'
    if m := re.fullmatch(r'(\w+) (rib|costal cartilage|metacarpal bone|metatarsal bone)', en):
        kind = {'rib': '肋', 'costal cartilage': '肋软骨', 'metacarpal bone': '掌骨',
                'metatarsal bone': '跖骨'}[m.group(2)]
        return f'{side}第{ORDINAL[m.group(1)]}{kind}'
    if en in SIMPLE:
        return side + SIMPLE[en]
    raise ValueError(f'缺少中文名：{en}')


def read_table(path: Path) -> list[list[str]]:
    return [line.rstrip('\n').split('\t') for line in path.read_text().splitlines()[1:] if line.strip()]


def find_obj(src: Path, fj: str) -> Path:
    hits = list(src.rglob(f'{fj}.obj'))
    if not hits:
        raise FileNotFoundError(f'{fj}.obj')
    return hits[0]


def read_obj(path: Path) -> tuple[np.ndarray, np.ndarray]:
    verts, faces = [], []
    for line in path.read_text(errors='replace').splitlines():
        if line.startswith('v '):
            verts.append([float(x) for x in line.split()[1:4]])
        elif line.startswith('f '):
            idx = [int(p.split('/')[0]) for p in line.split()[1:]]
            for i in range(1, len(idx) - 1):
                faces.append([idx[0], idx[i], idx[i + 1]])
    v = np.asarray(verts, dtype=np.float64)
    f = np.asarray(faces, dtype=np.int64)
    f = np.where(f > 0, f - 1, len(v) + f)
    return v, f


def vertex_normals(v: np.ndarray, f: np.ndarray) -> np.ndarray:
    n = np.zeros_like(v)
    fn = np.cross(v[f[:, 1]] - v[f[:, 0]], v[f[:, 2]] - v[f[:, 0]])
    for k in range(3):
        np.add.at(n, f[:, k], fn)
    length = np.linalg.norm(n, axis=1, keepdims=True)
    return n / np.where(length == 0, 1, length)


def write_glb(path: Path, bones: list[tuple[str, np.ndarray, np.ndarray]]) -> None:
    buf = bytearray()
    views, accessors, meshes, nodes = [], [], [], []

    def add(data: bytes, target: int) -> int:
        while len(buf) % 4:
            buf.append(0)
        views.append({'buffer': 0, 'byteOffset': len(buf), 'byteLength': len(data), 'target': target})
        buf.extend(data)
        return len(views) - 1

    for name, v, f in bones:
        pos = v.astype(np.float32)
        nrm = vertex_normals(v, f).astype(np.float32)
        idx = f.astype(np.uint32)
        a = len(accessors)
        accessors += [
            {'bufferView': add(pos.tobytes(), 34962), 'componentType': 5126, 'count': len(pos), 'type': 'VEC3',
             'min': pos.min(0).tolist(), 'max': pos.max(0).tolist()},
            {'bufferView': add(nrm.tobytes(), 34962), 'componentType': 5126, 'count': len(nrm), 'type': 'VEC3'},
            {'bufferView': add(idx.tobytes(), 34963), 'componentType': 5125, 'count': idx.size, 'type': 'SCALAR'},
        ]
        meshes.append({'name': name, 'primitives': [
            {'attributes': {'POSITION': a, 'NORMAL': a + 1}, 'indices': a + 2, 'material': 0}]})
        nodes.append({'name': name, 'mesh': len(meshes) - 1})

    gltf = {
        'asset': {'version': '2.0', 'generator': 'TaintedView build_skeleton.py',
                  'copyright': 'BodyParts3D, © The Database Center for Life Science, CC BY 4.0'},
        'scene': 0,
        'scenes': [{'nodes': list(range(len(nodes)))}],
        'nodes': nodes,
        'meshes': meshes,
        'materials': [{'name': 'bone', 'pbrMetallicRoughness': {'baseColorFactor': [0.91, 0.87, 0.79, 1],
                                                               'metallicFactor': 0, 'roughnessFactor': 0.7}}],
        'accessors': accessors,
        'bufferViews': views,
        'buffers': [{'byteLength': len(buf)}],
    }
    js = json.dumps(gltf, separators=(',', ':')).encode()
    js += b' ' * (-len(js) % 4)
    buf += b'\0' * (-len(buf) % 4)
    with path.open('wb') as out:
        out.write(struct.pack('<III', 0x46546C67, 2, 12 + 8 + len(js) + 8 + len(buf)))
        out.write(struct.pack('<II', len(js), 0x4E4F534A) + js)
        out.write(struct.pack('<II', len(buf), 0x004E4942) + bytes(buf))


def main() -> None:
    src, out = Path(sys.argv[1]), Path(sys.argv[2])
    out.mkdir(parents=True, exist_ok=True)

    elems: dict[str, set[str]] = defaultdict(set)
    names: dict[str, str] = {}
    for concept, name, fj in read_table(src / 'partof_element_parts.txt'):
        elems[concept].add(fj)
        names[concept] = name
    bone_concepts = [c for c, n in names.items() if BONE_RE.search(n) and not EXCLUDE.search(n)]

    # 每个 OBJ 归到包含它的最小骨骼概念，例如 FJ3236 → left ninth rib，而不是 rib cage。
    owner: dict[str, str] = {}
    for c in sorted(bone_concepts, key=lambda c: (-len(elems[c]), c)):
        for fj in elems[c]:
            owner[fj] = c
    groups: dict[str, list[str]] = defaultdict(list)
    for fj, c in owner.items():
        groups[c].append(fj)

    bones, table = [], {}
    for concept in sorted(groups, key=lambda c: names[c]):
        parts = [read_obj(find_obj(src, fj)) for fj in sorted(groups[concept])]
        offset, vs, fs = 0, [], []
        for v, f in parts:
            vs.append(v)
            fs.append(f + offset)
            offset += len(v)
        bones.append((concept, np.concatenate(vs), np.concatenate(fs)))
        table[concept] = {'zh': to_chinese(names[concept]), 'en': names[concept]}

    # 毫米、Z 轴向上 → 米、Y 轴向上，并把整副骨架移到原点。
    allv = np.concatenate([v for _, v, _ in bones])
    center = (allv.min(0) + allv.max(0)) / 2
    bones = [(n, ((v - center) @ np.array([[1, 0, 0], [0, 0, -1], [0, 1, 0]])) / 1000, f) for n, v, f in bones]

    write_glb(out / 'skeleton_raw.glb', bones)
    (out / 'bones.json').write_text(json.dumps(table, ensure_ascii=False, indent=1) + '\n')
    tris = sum(len(f) for _, _, f in bones)
    print(f'{len(bones)} 块骨骼，{tris} 个三角形 → {out}')


if __name__ == '__main__':
    main()
