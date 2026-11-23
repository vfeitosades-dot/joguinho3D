#!/usr/bin/env python3
"""Importa GLBs CC0 de Kenney, a partir do espelho publico Hidencod/tge-assets.
Obrigatorio antes da compilacao CI; o jogo tambem aceita modelos procedurais de reserva.
"""
from pathlib import Path
import urllib.request
import time

BASE = 'https://raw.githubusercontent.com/Hidencod/tge-assets/main/packs/'
PACKS = {
 'city-kit-commercial': ['building-a','building-b','building-c','building-d','building-e','building-f','building-g','building-h','building-skyscraper-a','building-skyscraper-b','low-detail-building-a','low-detail-building-b','detail-parasol-a','detail-awning'],
 'city-kit-suburban': ['building-type-a','building-type-b','building-type-c','building-type-d','building-type-e','tree-large','tree-small','planter'],
 'city-kit-roads': ['light-curved','traffic-light','road-sign-stop','dumpster','construction-cone','road-crossing'],
 'car-kit': ['sedan','sedan-sports','suv','taxi','van','hatchback-sports','suv-luxury'],
 'nature-kit': ['canoe','cactus-tall','cliff-rock'],
 'mini-characters': ['character-male-a','character-male-c','character-female-a','character-female-b'],
}
base = Path(__file__).resolve().parents[1] / 'assets' / 'kenney'
count=0
for pack,names in PACKS.items():
 for name in names:
  target = base / pack / f'{name}.glb'
  if target.is_file() and target.stat().st_size > 20:
   count += 1
   continue
  target.parent.mkdir(parents=True, exist_ok=True)
  url = f'{BASE}{pack}/{name}.glb'
  for retry in range(3):
   try:
    req=urllib.request.Request(url, headers={'User-Agent':'CostaLivre-Godot-asset-build/0.1'})
    with urllib.request.urlopen(req, timeout=35) as response:
     data=response.read()
    if len(data)<20 or data[:4] != b'glTF':
     raise ValueError(f'Nao e GLB valido: {url}')
    target.write_bytes(data)
    count += 1
    print(f'[asset] {pack}/{name}.glb ({len(data)} bytes)')
    break
   except Exception as exc:
    print(f'[tentativa {retry+1}/3] {url}: {exc}')
    if retry == 2:
     raise
    time.sleep(1.5)
print('Total GLBs:', count)
