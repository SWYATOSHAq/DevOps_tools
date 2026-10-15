"""Check that local images referenced by the README exist."""
from pathlib import Path
import re


def missing_images(root: Path) -> list[str]:
    """Return missing local Markdown image targets."""
    text = (root / "README.md").read_text(encoding="utf-8")
    targets = re.findall(r"!\[[^\]]*\]\(([^)]+)\)", text)
    return [target for target in targets
            if not target.startswith(("https://", "http://", "data:"))
            and not (root / target).is_file()]


if __name__ == "__main__":
    missing = missing_images(Path(__file__).resolve().parents[1])
    if missing:
        raise SystemExit(f"Missing README images: {missing}")
    print("README local images: OK")
