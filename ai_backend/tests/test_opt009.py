import unittest
import threading
import time
import numpy as np
import os
import sys

# Add parent dir to path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from main import get_embeddings_snapshot, update_embeddings_atomic, embeddings_lock

class TestOPT009ThreadSafety(unittest.TestCase):
    def test_concurrent_reads_and_writes(self):
        # Initialize test embeddings
        initial_vecs = np.random.randn(10, 512).astype(np.float32)
        initial_ids = [f"ST_{i}" for i in range(10)]
        update_embeddings_atomic(initial_vecs, initial_ids)

        read_errors = []
        stop_event = threading.Event()

        def reader_task():
            while not stop_event.is_set():
                vecs, ids = get_embeddings_snapshot()
                if vecs is not None and len(vecs) != len(ids):
                    read_errors.append(f"Mismatched lengths: vecs={len(vecs)}, ids={len(ids)}")
                time.sleep(0.001)

        def writer_task():
            for i in range(50):
                n = 10 + (i % 20)
                new_vecs = np.random.randn(n, 512).astype(np.float32)
                new_ids = [f"ST_{j}" for j in range(n)]
                update_embeddings_atomic(new_vecs, new_ids)
                time.sleep(0.002)

        reader_threads = [threading.Thread(target=reader_task) for _ in range(5)]
        writer_threads = [threading.Thread(target=writer_task) for _ in range(2)]

        for t in reader_threads + writer_threads:
            t.start()

        for t in writer_threads:
            t.join()

        stop_event.set()
        for t in reader_threads:
            t.join()

        self.assertEqual(len(read_errors), 0, f"Thread safety violations detected: {read_errors}")

if __name__ == "__main__":
    unittest.main()
