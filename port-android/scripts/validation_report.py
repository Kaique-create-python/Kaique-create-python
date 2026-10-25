"""Summarize measured CI evidence. Missing measurements remain explicitly unavailable."""
from pathlib import Path
import json
import re
import xml.etree.ElementTree as ET

root = Path(__file__).resolve().parents[1] / 'android'

def text_file(name):
    p = root / name
    return p.read_text(errors='replace') if p.exists() else ''

def suites(folder):
    total = dict(tests=0, failures=0, errors=0, skipped=0)
    files = list(folder.rglob('TEST-*.xml')) if folder.exists() else []
    for path in files:
        suite = ET.parse(path).getroot()
        for key in total:
            total[key] += int(suite.get(key, '0'))
    return dict(status='executed' if files else 'unavailable', **total)

startup = text_file('startup.txt')
memory = text_file('memory.txt')
frames = text_file('frames.txt')
def match_number(pattern, value):
    m = re.search(pattern, value)
    return int(m[1].replace(',', '')) if m else None

lint_path = root / 'app/build/reports/lint-results-debug.xml'
lint = dict(status='unavailable')
if lint_path.exists():
    issues = ET.parse(lint_path).getroot().findall('issue')
    lint = dict(status='executed', errors=sum(i.get('severity') in ('Error', 'Fatal') for i in issues), warnings=sum(i.get('severity') == 'Warning' for i in issues))

report = dict(
    environment='GitHub Actions emulator Android 15 API 35 x86_64, 720x1600 / density 320',
    unit=suites(root / 'app/build/test-results/testDebugUnitTest'),
    instrumented=suites(root / 'app/build/outputs/androidTest-results'),
    lint=lint,
    startup=dict(status='ok' if 'Status: ok' in startup else 'unavailable', total_time_ms=match_number(r'TotalTime:\s*(\d+)', startup), wait_time_ms=match_number(r'WaitTime:\s*(\d+)', startup), method='am start -W after force-stop, single observation after tests; no V5 comparison'),
    memory=dict(total_pss_kib=match_number(r'TOTAL PSS:\s*([\d,]+)', memory), method='dumpsys meminfo snapshot immediately after launch'),
    frames=dict(rendered=match_number(r'Total frames rendered:\s*(\d+)', frames), janky=match_number(r'Janky frames:\s*(\d+)', frames), method='startup snapshot; not a scrolling benchmark'),
    physical_device_tests='not executed: POCO C65, Bluetooth, real phone calls, Wi-Fi/mobile handoff, battery drain, ARM64 native UI runtime',
)
providers = Path('provider-checks.json')
if providers.exists():
    report['providers'] = json.loads(providers.read_text())
Path('validation-report.json').write_text(json.dumps(report, indent=2, ensure_ascii=False))
print(json.dumps(report, indent=2, ensure_ascii=False))
