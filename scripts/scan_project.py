#!/usr/bin/env python3
import os, re, json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

swift_files = []
for base, dirs, files in os.walk(ROOT):
    # Skip caches and VCS
    skip = any(s in base for s in [f"{os.sep}.git{os.sep}", f"{os.sep}.build{os.sep}", f"{os.sep}build{os.sep}", f"{os.sep}DerivedData{os.sep}"])
    if skip:
        continue
    for f in files:
        if f.endswith('.swift'):
            swift_files.append(Path(base) / f)

info_plist = ROOT / 'Info.plist'
entitlements = ROOT / 'AI-Mixtapes.entitlements'
package_swift = ROOT / 'Package.swift'
workflows = ROOT / '.github/workflows'

rx = {
    'intent': re.compile(r'\b(AppIntent|IntentHandler)\b|@main\s+struct\s+.*:\s*App\b|@available\(.*\)\s*struct\s+.*:\s*AppIntent'),
    'appIntentsImport': re.compile(r'\bimport\s+AppIntents\b'),
    'widget': re.compile(r'\bimport\s+WidgetKit\b'),
    'activity': re.compile(r'\bimport\s+ActivityKit\b'),
    'musickit': re.compile(r'\bimport\s+MusicKit\b|\bMPMusicPlayerController\b'),
    'vision': re.compile(r'\bimport\s+Vision\b|\bVNFace\w+'),
    'arkit': re.compile(r'\bimport\s+ARKit\b|\bARFaceAnchor\b'),
    'soundanalysis': re.compile(r'\bimport\s+SoundAnalysis\b|\bSNAudioStreamAnalyzer\b'),
    'swiftdata': re.compile(r'@Model\b|\bimport\s+SwiftData\b'),
}

intents = []
widgets = []
activities = []
capabilities = set()
models = []
dataModels = []
ci_configs = []

for f in swift_files:
    try:
        text = f.read_text(errors='ignore')
    except Exception:
        continue
    if rx['appIntentsImport'].search(text) or rx['intent'].search(text):
        intents.append(str(f.relative_to(ROOT)))
    if rx['widget'].search(text):
        widgets.append(str(f.relative_to(ROOT)))
    if rx['activity'].search(text):
        activities.append(str(f.relative_to(ROOT)))
    if rx['musickit'].search(text):
        capabilities.add('MusicKit')
    if rx['vision'].search(text):
        capabilities.add('Vision')
    if rx['arkit'].search(text):
        capabilities.add('ARKit')
    if rx['soundanalysis'].search(text):
        capabilities.add('SoundAnalysis')
    if rx['swiftdata'].search(text):
        dataModels.append(str(f.relative_to(ROOT)))

# ML models
for p in ROOT.rglob('*.mlmodel'):
    models.append(str(p.relative_to(ROOT)))

# Info.plist parse (very small)
info = {}
if info_plist.exists():
    info_text = info_plist.read_text(errors='ignore')
    info['bundleName'] = 'Encorely' if 'Encorely' in info_text else 'AI-Mixtapes'
    info['hasBackgroundAudio'] = '<key>UIBackgroundModes</key>' in info_text and 'audio' in info_text

# Entitlements quick scan
ent = {}
if entitlements.exists():
    et = entitlements.read_text(errors='ignore')
    ent['siri'] = 'com.apple.security.siri' in et
    ent['microphone'] = 'com.apple.security.device.microphone' in et
    ent['music'] = 'music' in et
    ent['appGroups'] = 'com.apple.security.application-groups' in et

# Package targets
targets = []
if package_swift.exists():
    pt = package_swift.read_text(errors='ignore')
    for m in re.finditer(r'name:\s*"([A-Za-z0-9_\-]+)"\s*,\s*\n\s*dependencies', pt):
        targets.append(m.group(1))

# CI
if workflows.exists():
    for wf in workflows.glob('**/*.yml'):
        ci_configs.append(str(wf.relative_to(ROOT)))

missing = []
for need in ['App Intents', 'Live Activity', 'SwiftData']:
    if need == 'App Intents' and not intents:
        missing.append('appIntents')
    if need == 'Live Activity' and not activities:
        missing.append('liveActivity')
    if need == 'SwiftData' and not dataModels:
        missing.append('swiftData')

summary = {
    'targets': targets,
    'bundle': info,
    'entitlements': ent,
    'intents': intents,
    'widgets': widgets,
    'activities': activities,
    'models': models,
    'dataModels': dataModels,
    'capabilities': sorted(list(capabilities)),
    'ci': ci_configs,
    'missing': sorted(missing),
}

print(json.dumps(summary, indent=2))
