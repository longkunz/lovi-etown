"""Small read-only contract experiments; these requests are NOT app traffic."""
import datetime, hashlib, json, math, urllib.error, urllib.request
from pathlib import Path

OUT = Path(__file__).resolve().parents[1] / 'evidence/camera/contract-pass6'
OUT.mkdir(parents=True, exist_ok=True)
BASE = 'https://api.notis.vn/v4/'
LAT, LNG = 10.775708, 106.700359
HEADERS = {'User-Agent': 'camera-spec-investigation/1.0'}
results = []

def fetch(name, path, extra=None):
    record = dict(name=name, kind='analyst-GET-not-app-traffic', timestamp=datetime.datetime.now(datetime.timezone.utc).isoformat(), method='GET', url=BASE+path, authentication_sent=False, request_headers={**HEADERS, **(extra or {})})
    try:
        try:
            response = urllib.request.urlopen(urllib.request.Request(BASE+path, headers=record['request_headers']), timeout=10)
        except urllib.error.HTTPError as err:
            response = err
        with response:
            body = response.read(2*1024*1024+1)
            record.update(status=response.status, final_url=response.url, headers={k.lower(): v for k,v in response.headers.items() if k.lower() in ('content-type','content-length','cache-control','etag','last-modified','expires','age','vary','retry-after')}, bytes=len(body), sha256=hashlib.sha256(body).hexdigest(), truncated=len(body)>2*1024*1024)
        if name.startswith('snapshot'):
            record['magic_hex'] = body[:12].hex()
        elif record['status'] == 200 and not record['truncated']:
            data = json.loads(body)
            record['response_type'] = type(data).__name__
            if isinstance(data, list):
                # Retain only IDs and coordinates/distances; no camera IP/stream query.
                rows = [{'id': x.get('_id'), 'coordinates': x.get('loc',{}).get('coordinates'), 'distance': x.get('distance')} for x in data]
                record['count'] = len(rows)
                record['rows'] = rows
    except Exception as err:
        record['error'] = str(err)
    results.append(record)
    (OUT / (name+'.json')).write_text(json.dumps(record,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps({k:v for k,v in record.items() if k not in ('rows','request_headers')},ensure_ascii=False),flush=True)
    return record

snapshot = fetch('snapshot', 'cameras/5deb576d1dc17d7c5515ad13/snapshot')
etag = snapshot.get('headers',{}).get('etag')
if etag:
    fetch('snapshot-conditional', 'cameras/5deb576d1dc17d7c5515ad13/snapshot', {'If-None-Match': etag})
query = f'cameras?lat={LAT}&lng={LNG}&distance='
small = fetch('radius-500', query+'500')
large = fetch('radius-5000', query+'5000')
fetch('radius-10000', query+'10000')
fetch('limit-5', query+'5000&limit=5')
fetch('page-2-limit-5', query+'5000&limit=5&page=2')
fetch('bbox-wide', 'cameras/bybbox?lat1=10.73&lng1=106.65&lat2=10.82&lng2=106.75')

def meters(point):
    lng, lat = point
    p1,p2 = math.radians(LAT),math.radians(lat)
    a = math.sin((p2-p1)/2)**2 + math.cos(p1)*math.cos(p2)*math.sin(math.radians(lng-LNG)/2)**2
    return 6371008.8*2*math.atan2(math.sqrt(a),math.sqrt(1-a))

summary = {'kind':'analyst-probe-comparison-not-app-contract','results':[]}
baseline = [x['id'] for x in large.get('rows',[])]
for result in results:
    rows = result.get('rows')
    if rows is None:
        continue
    distances = [meters(x['coordinates']) for x in rows if isinstance(x.get('coordinates'),list) and len(x['coordinates'])==2]
    supplied = [x.get('distance') for x in rows]
    summary['results'].append(dict(name=result['name'],count=len(rows),same_ordered_ids_as_radius5000=[x['id'] for x in rows]==baseline,computed_distance_min_m=min(distances) if distances else None,computed_distance_max_m=max(distances) if distances else None,reported_distance_sorted=all(isinstance(x,(int,float)) for x in supplied) and supplied==sorted(supplied),max_abs_reported_vs_haversine_m=max((abs(x['distance']-meters(x['coordinates'])) for x in rows if isinstance(x.get('distance'),(int,float)) and isinstance(x.get('coordinates'),list)),default=None)))
(OUT/'summary.json').write_text(json.dumps(summary,indent=2),encoding='utf-8')
print(json.dumps(summary),flush=True)
wide = next((x for x in results if x['name']=='bbox-wide'), {})
within = [x for x in wide.get('rows',[]) if meters(x['coordinates'])<=5000]
missing = [x for x in within if x['id'] not in set(baseline)]
comparison = dict(kind='analyst-comparison-not-app-traffic', bbox_records_within_5000m=len(within), nearby_count=len(baseline), bbox_records_within_5000m_absent_from_nearby=len(missing), absent_ids=[x['id'] for x in missing], limitation='Different endpoint selection rules and coordinate-distance approximation remain unknown; this does not establish pagination or a cap.')
(OUT/'bbox-comparison.json').write_text(json.dumps(comparison,indent=2),encoding='utf-8')
