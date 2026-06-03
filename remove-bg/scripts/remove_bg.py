"""Remove image backgrounds with rembg and write transparent PNGs."""

from __future__ import annotations

import argparse
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Callable, Iterable


IMAGE_EXTENSIONS = {".bmp", ".jpeg", ".jpg", ".png", ".tif", ".tiff", ".webp"}


@dataclass(frozen=True)
class Job:
    input_path: Path
    output_path: Path


@dataclass(frozen=True)
class RemoveOptions:
    alpha_matting: bool
    model: str


class UserFacingError(RuntimeError):
    """An expected error that should be printed without a traceback."""


def iter_images(input_path: Path, recursive: bool) -> Iterable[Path]:
    if input_path.is_file():
        if input_path.suffix.lower() not in IMAGE_EXTENSIONS:
            raise UserFacingError(f"Input is not a supported image: {input_path}")
        yield input_path
        return

    if not input_path.is_dir():
        raise UserFacingError(f"Input path does not exist: {input_path}")

    iterator = input_path.rglob("*") if recursive else input_path.glob("*")
    for candidate in sorted(iterator):
        if candidate.is_file() and candidate.suffix.lower() in IMAGE_EXTENSIONS:
            yield candidate


def build_jobs(
    input_path: Path,
    output_path: Path | None,
    recursive: bool,
    suffix: str,
    force: bool,
) -> list[Job]:
    images = list(iter_images(input_path, recursive))
    if not images:
        raise UserFacingError(f"No supported images found in: {input_path}")

    jobs: list[Job] = []
    input_is_file = input_path.is_file()

    if input_is_file:
        if output_path is None:
            target = input_path.with_name(f"{input_path.stem}{suffix}.png")
        elif output_path.suffix.lower() == ".png":
            target = output_path
        else:
            target = output_path / f"{input_path.stem}.png"
        jobs.append(Job(input_path=images[0], output_path=target))
    else:
        target_root = output_path or input_path
        for image in images:
            relative_parent = image.parent.relative_to(input_path)
            target = target_root / relative_parent / f"{image.stem}{suffix}.png"
            jobs.append(Job(input_path=image, output_path=target))

    existing = [job.output_path for job in jobs if job.output_path.exists()]
    if existing and not force:
        joined = "\n".join(str(path) for path in existing[:10])
        more = "" if len(existing) <= 10 else f"\n...and {len(existing) - 10} more"
        raise UserFacingError(f"Output already exists. Use --force to overwrite:\n{joined}{more}")

    return jobs


def load_remover(model: str) -> Callable[[bytes, RemoveOptions], bytes]:
    try:
        from rembg import new_session, remove
    except ImportError as exc:
        raise UserFacingError(
            "Missing dependency: rembg.\n"
            "Install it from this skill directory with:\n"
            "python -m pip install -r requirements.txt"
        ) from exc

    session = new_session(model)

    def remover(data: bytes, options: RemoveOptions) -> bytes:
        return remove(
            data,
            session=session,
            alpha_matting=options.alpha_matting,
        )

    return remover


def process_job(job: Job, remover: Callable[[bytes, RemoveOptions], bytes], options: RemoveOptions) -> None:
    source = job.input_path.read_bytes()
    result = remover(source, options)
    job.output_path.parent.mkdir(parents=True, exist_ok=True)
    job.output_path.write_bytes(result)


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Remove backgrounds from image files and write transparent PNG cutouts."
    )
    parser.add_argument("input", help="Image file or directory of images.")
    parser.add_argument("--output", "-o", help="Output PNG file for one image, or output directory for batches.")
    parser.add_argument("--recursive", action="store_true", help="Recurse into subdirectories when input is a folder.")
    parser.add_argument("--alpha-matting", action="store_true", help="Improve soft edges such as hair and shadows.")
    parser.add_argument("--model", default="isnet-general-use", help="rembg model name, e.g. isnet-general-use, u2net, u2netp.")
    parser.add_argument("--suffix", default="_removebg", help="Suffix for generated output files.")
    parser.add_argument("--force", action="store_true", help="Overwrite existing output files.")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv or sys.argv[1:])
    input_path = Path(args.input).expanduser().resolve()
    output_path = Path(args.output).expanduser().resolve() if args.output else None
    options = RemoveOptions(alpha_matting=args.alpha_matting, model=args.model)

    try:
        jobs = build_jobs(
            input_path=input_path,
            output_path=output_path,
            recursive=args.recursive,
            suffix=args.suffix,
            force=args.force,
        )
        remover = load_remover(args.model)
        for job in jobs:
            process_job(job, remover, options)
            print(f"Wrote {job.output_path}")
    except UserFacingError as exc:
        print(str(exc), file=sys.stderr)
        return 2

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
