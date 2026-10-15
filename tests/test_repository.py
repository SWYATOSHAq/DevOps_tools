"""Check missing files and distinguish remote URLs from local paths."""
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest
from tools.check_repository import missing_images


class RepositoryTests(unittest.TestCase):
    def test_missing_image(self):
        with TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "README.md").write_text("![x](missing.png)")
            self.assertEqual(missing_images(root), ["missing.png"])

    def test_existing_and_remote_images(self):
        with TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "image.png").touch()
            (root / "README.md").write_text(
                "![a](./image.png) ![b](https://example.com/image.png)")
            self.assertEqual(missing_images(root), [])
