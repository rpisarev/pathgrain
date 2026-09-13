"""Synthetic read-only adapter regressions. No private capture is required."""
import hashlib
import pathlib
import sqlite3
import tempfile
import unittest

from tool.read_surface_capture import read


class CaptureReaderTest(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.path = pathlib.Path(self.directory.name) / 'synthetic.sqlite'
        with sqlite3.connect(self.path) as db:
            db.executescript('''
                CREATE TABLE walks(id INTEGER);
                CREATE TABLE walk_points(walk_id,sequence,latitude,longitude,
                    recorded_at_ms,accuracy_meters,unrelated_metadata);
                CREATE TABLE walk_surface_analyses(walk_id,point_count,points_valid);
                CREATE TABLE walk_surface_segments(walk_id,ordinal,start_edge,end_edge,
                    surface,assignment,surface_reason,edge_reason,from_feature_key,to_feature_key);
                CREATE TABLE evidence_cells(namespace,cell,fetched_at_ms,evidence_json);
                INSERT INTO walks VALUES(7),(99);
                INSERT INTO walk_points VALUES(7,1,1,2,1000,7,'excluded');
                INSERT INTO walk_points VALUES(99,0,3,4,2000,7,'unrelated walk');
                INSERT INTO walk_points VALUES(7,0,1,2,0,7,'excluded');
                INSERT INTO evidence_cells VALUES('fixture-a','15/1/1',0,'{"elements":[]}');
                INSERT INTO evidence_cells VALUES('fixture-a','15/2/2',0,'{"elements":[]}');
                INSERT INTO evidence_cells VALUES('fixture-b','15/1/1',0,'{"elements":[]}');
            ''')

    def request(self, kind, **fields):
        return read({'kind': kind, 'database': str(self.path), **fields})

    def test_only_requested_walk_without_metadata_and_no_database_mutation(self):
        before = hashlib.sha256(self.path.read_bytes()).hexdigest()
        files = list(self.path.parent.iterdir())
        result = self.request('walk', walkId=7)
        self.assertEqual([p['sequence'] for p in result['points']], [0, 1])
        self.assertTrue(all('unrelated_metadata' not in p and 'walk_id' not in p
                            for p in result['points']))
        self.assertEqual(result['header'], [])
        self.assertEqual(result['segments'], [])
        self.assertEqual(hashlib.sha256(self.path.read_bytes()).hexdigest(), before)
        self.assertEqual(list(self.path.parent.iterdir()), files)
        with self.assertRaisesRegex(ValueError, 'Walk not found'):
            self.request('walk', walkId=123)

    def test_namespace_is_explicit_when_ambiguous_and_only_requested_cells_are_read(self):
        with self.assertRaisesRegex(ValueError, 'Specify namespace'):
            self.request('cells', cells=['15/1/1'])
        result = self.request('cells', namespace='fixture-a', cells=['15/1/1', '15/3/3'])
        self.assertEqual([c['cell'] for c in result['cells']], ['15/1/1'])
        with self.assertRaisesRegex(ValueError, 'namespace not found'):
            self.request('cells', namespace='absent', cells=[])

    def test_pending_wal_or_journal_is_refused(self):
        for suffix in ['-wal', '-journal']:
            sidecar = pathlib.Path(str(self.path) + suffix)
            sidecar.write_bytes(b'pending')
            with self.assertRaisesRegex(ValueError, 'consistent SQLite snapshot'):
                self.request('walk', walkId=7)
            sidecar.unlink()


if __name__ == '__main__':
    unittest.main()
