"""Live checks are reported independently of deterministic tests. Never print credentials/URLs."""
import json, os, urllib.request, urllib.parse
results = {}
def get(url):
    request = urllib.request.Request(url, headers={'User-Agent': 'SpotiFastAndroid/4', 'Accept': 'application/json'})
    with urllib.request.urlopen(request, timeout=20) as r:
        return json.loads(r.read(2_000_000))
try:
    data = get('https://api.audius.co/v1/tracks/search?query=ambient&limit=5&app_name=SpotiFastAndroid')
    tracks = data['data']
    results['audius_search'] = {'status': 'passed', 'tracks': len(tracks)}
except Exception as e:
    results['audius_search'] = {'status': 'blocked', 'reason': type(e).__name__}
client = os.environ.get('JAMENDO_CLIENT_ID', '')
if client:
    try:
        data = get('https://api.jamendo.com/v3.0/tracks/?' + urllib.parse.urlencode({'client_id': client, 'format': 'json', 'search': 'ambient', 'limit': 5}))
        results['jamendo_search'] = {'status': 'passed' if data['headers']['code'] == 0 else 'failed', 'tracks': len(data.get('results', []))}
    except Exception as e:
        results['jamendo_search'] = {'status': 'blocked', 'reason': type(e).__name__}
else:
    results['jamendo_search'] = {'status': 'not_run', 'reason': 'No legitimate Client ID configured'}
with open('provider-checks.json', 'w') as f:
    json.dump(results, f, indent=2)
print(json.dumps(results, indent=2))
