from __future__ import annotations

import sys
import unittest
from pathlib import Path
from tempfile import TemporaryDirectory


SCRIPT_DIR = Path(__file__).resolve().parents[1] / "scripts"
sys.path.insert(0, str(SCRIPT_DIR))

import remove_bg  # noqa: E402


class RemoveBgTests(unittest.TestCase):
    def test_builds_default_single_file_output_path(self) -> None:
        with TemporaryDirectory() as tmp:
            image = Path(tmp) / "portrait.jpg"
            image.write_bytes(b"fake image")

            jobs = remove_bg.build_jobs(image, None, recursive=False, suffix="_removebg", force=False)

            self.assertEqual(len(jobs), 1)
            self.assertEqual(jobs[0].output_path, Path(tmp) / "portrait_removebg.png")

    def test_builds_recursive_batch_outputs_under_output_directory(self) -> None:
        with TemporaryDirectory() as tmp:
            root = Path(tmp) / "photos"
            nested = root / "nested"
            nested.mkdir(parents=True)
            (root / "a.jpg").write_bytes(b"a")
            (nested / "b.webp").write_bytes(b"b")
            output = Path(tmp) / "cutouts"

            jobs = remove_bg.build_jobs(root, output, recursive=True, suffix="_transparent", force=False)

            outputs = sorted(job.output_path for job in jobs)
            self.assertEqual(
                outputs,
                [
                    output / "a_transparent.png",
                    output / "nested" / "b_transparent.png",
                ],
            )

    def test_refuses_to_overwrite_without_force(self) -> None:
        with TemporaryDirectory() as tmp:
            image = Path(tmp) / "product.png"
            image.write_bytes(b"fake image")
            existing = Path(tmp) / "product_removebg.png"
            existing.write_bytes(b"old")

            with self.assertRaises(remove_bg.UserFacingError) as error:
                remove_bg.build_jobs(image, None, recursive=False, suffix="_removebg", force=False)

            self.assertIn("--force", str(error.exception))

    def test_process_job_uses_injected_remover(self) -> None:
        with TemporaryDirectory() as tmp:
            source = Path(tmp) / "input.jpg"
            target = Path(tmp) / "out" / "input.png"
            source.write_bytes(b"source")

            def remover(data: bytes, options: remove_bg.RemoveOptions) -> bytes:
                self.assertEqual(data, b"source")
                self.assertTrue(options.alpha_matting)
                return b"png data"

            remove_bg.process_job(
                remove_bg.Job(input_path=source, output_path=target),
                remover,
                remove_bg.RemoveOptions(alpha_matting=True, model="dummy"),
            )

            self.assertEqual(target.read_bytes(), b"png data")


if __name__ == "__main__":
    unittest.main()
