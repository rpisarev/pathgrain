"""Read one saved walk or explicitly requested cache cells; never open writable DBs.

Invoked by capture_input.dart. No matching or geographic algorithms live here.
Requires a consistent captured SQLite database (checkpointed, no pending WAL).
"""
import json
import pathlib
import sqlite3
import sys


def read(request):
    path = pathlib.Path(request['database']).resolve(strict=True)
    # immutable=1 ignores WAL; refuse it rather than silently replay stale rows.
    for suffix in ['-wal', '-journal']:
        sidecar = pathlib.Path(str(path) + suffix)
        if sidecar.exists() and sidecar.stat().st_size:
            raise ValueError('Capture must be a consistent SQLite snapshot without pending WAL/journal')
    with sqlite3.connect(path.as_uri() + '?mode=ro&immutable=1', uri=True) as db:
        db.row_factory = sqlite3.Row
        if request['kind'] == 'walk':
            walk_id = request['walkId']
            points = [dict(r) for r in db.execute(
                'SELECT sequence,latitude,longitude,recorded_at_ms,accuracy_meters '
                'FROM walk_points WHERE walk_id=? ORDER BY sequence', (walk_id,))]
            if not db.execute('SELECT 1 FROM walks WHERE id=?', (walk_id,)).fetchone():
                raise ValueError('Walk not found')
            segments = [dict(r) for r in db.execute(
                'SELECT ordinal,start_edge,end_edge,surface,assignment,surface_reason,'
                'edge_reason,from_feature_key,to_feature_key '
                'FROM walk_surface_segments WHERE walk_id=? ORDER BY ordinal', (walk_id,))]
            header = [dict(r) for r in db.execute(
                'SELECT point_count,points_valid FROM walk_surface_analyses WHERE walk_id=?',
                (walk_id,))]
            return {'points': points, 'segments': segments, 'header': header}
        if request['kind'] != 'cells':
            raise ValueError('Unknown capture request')
        namespaces = [r[0] for r in db.execute('SELECT DISTINCT namespace FROM evidence_cells')]
        namespace = request.get('namespace')
        if namespace is None:
            if len(namespaces) != 1:
                raise ValueError('Specify namespace when cache has zero or multiple namespaces')
            namespace = namespaces[0]
        if namespace not in namespaces:
            raise ValueError('Evidence namespace not found')
        rows = []
        for cell in request['cells']:
            row = db.execute(
                'SELECT cell,fetched_at_ms,evidence_json FROM evidence_cells '
                'WHERE namespace=? AND cell=?', (namespace, cell)).fetchone()
            if row:
                rows.append(dict(row))
        return {'namespace': namespace, 'cells': rows}


if __name__ == '__main__':
    try:
        json.dump(read(json.load(sys.stdin)), sys.stdout)
    except (OSError, ValueError, sqlite3.Error, KeyError) as error:
        # No coordinates, SQL rows or device metadata in errors.
        print(f'Capture read failed: {type(error).__name__}: {error}', file=sys.stderr)
        sys.exit(1)
