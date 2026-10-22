"""Live checks are reported independently of deterministic tests. Never print credentials/URLs."""
import json, os, urllib.request, urllib.parse
results = {}
def get(url):
    request = urllib.request.Request(url, headers={'User-Agent': 'SpotiFastAndroid/4', 'Accept': 'application/json'})
    with urllib.request.urlopen(request, timeout=20) as r:
        return json.loads(r.read(2_000_000))
def media_probe(url):
    if not url.startswith('https://'):
        return {'status': 'blocked', 'reason': 'Only HTTPS streams accepted'}
    request = urllib.request.Request(url, headers={'User-Agent': 'SpotiFastAndroid/4', 'Range': 'bytes=0-4095'})
    with urllib.request.urlopen(request, timeout=20) as response:
        content_type = response.headers.get('Content-Type', '')
        sample = response.read(4096)
        return {'status': 'passed' if sample and ('audio' in content_type or 'octet-stream' in content_type) else 'failed', 'sample_bytes': len(sample), 'content_type': content_type}
try:
    data = get('https://api.audius.co/v1/tracks/search?query=ambient&limit=5&app_name=SpotiFastAndroid')
    tracks = data['data']
    results['audius_search'] = {'status': 'passed', 'tracks': len(tracks)}
    permitted = [t for t in tracks if not any(t.get(k, False) for k in ['is_stream_gated', 'is_delete', 'is_private']) and t.get('is_streamable', True) and t.get('streamable', True) and not t.get('stream_conditions') and (t.get('access') or {}).get('stream', True)]
    if permitted:
        track = permitted[0]
        try:
            results['audius_stream_sample'] = media_probe('https://api.audius.co/v1/tracks/' + urllib.parse.quote(track['id'], safe='') + '/stream?app_name=SpotiFastAndroid')
        except Exception as e:
            results['audius_stream_sample'] = {'status': 'blocked', 'reason': type(e).__name__}
        artwork = (track.get('artwork') or {}).get('150x150', '')
        if artwork.startswith('https://'):
            try:
                with urllib.request.urlopen(artwork, timeout=20) as response:
                    results['audius_artwork'] = {'status': 'passed' if response.read(256) else 'failed', 'content_type': response.headers.get('Content-Type', '')}
            except Exception as e:
                results['audius_artwork'] = {'status': 'blocked', 'reason': type(e).__name__}
    else:
        results['audius_stream_sample'] = {'status': 'not_run', 'reason': 'No permitted track returned'}
except Exception as e:
    results['audius_search'] = {'status': 'blocked', 'reason': type(e).__name__}
client = os.environ.get('JAMENDO_CLIENT_ID', '')
if client:
    try:
        data = get('https://api.jamendo.com/v3.0/tracks/?' + urllib.parse.urlencode({'client_id': client, 'format': 'json', 'search': 'ambient', 'limit': 5}))
        results['jamendo_search'] = {'status': 'passed' if data['headers']['code'] == 0 else 'failed', 'tracks': len(data.get('results', []))}
        if data['headers']['code'] == 0 and data.get('results'):
            results['jamendo_stream_sample'] = media_probe(data['results'][0].get('audio', ''))
    except Exception as e:
        results['jamendo_search'] = {'status': 'blocked', 'reason': type(e).__name__}
else:
    results['jamendo_search'] = {'status': 'not_run', 'reason': 'No legitimate Client ID configured'}
with open('provider-checks.json', 'w') as f:
    json.dump(results, f, indent=2)
print(json.dumps(results, indent=2))
