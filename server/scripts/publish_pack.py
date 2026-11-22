from __future__ import annotations

import argparse
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from server.app.config import Settings  # noqa: E402
from server.app.db import Base, make_engine, make_session_factory  # noqa: E402
from server.app.packs import PackError, publish_pack  # noqa: E402


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Publish a Storylingo content pack to the API database."
    )
    parser.add_argument("pack", type=Path, help="Pack folder containing manifest.json.")
    parser.add_argument(
        "--content-dir",
        type=Path,
        help="Override STORYLINGO_CONTENT_DIR for the published packs.",
    )
    access = parser.add_mutually_exclusive_group()
    access.add_argument(
        "--free",
        dest="is_free",
        action="store_true",
        default=None,
        help="Publish the book as free (default: paid for new books).",
    )
    access.add_argument(
        "--paid",
        dest="is_free",
        action="store_false",
        help="Publish the book behind the subscription.",
    )
    args = parser.parse_args(argv)

    settings = Settings.from_env(ROOT)
    content_dir = args.content_dir or settings.content_dir
    engine = make_engine(settings.database_url)
    Base.metadata.create_all(engine)
    factory = make_session_factory(engine)
    try:
        with factory() as session:
            book = publish_pack(
                args.pack, content_dir, session, is_free=args.is_free
            )
    except PackError as error:
        parser.error(str(error))
        return 2
    print(
        f"Published {book.id} v{book.pack_version} "
        f"({'free' if book.is_free else 'paid'}, {book.chapter_count} chapters) "
        f"into {content_dir / book.folder}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
