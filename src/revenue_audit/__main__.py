import argparse
import json
from .db import DEFAULT_DB
from .generate import generate, generate_labels
from .reporting import build_reports


def main():
    parser = argparse.ArgumentParser(description="Synthetic revenue assurance pipeline")
    parser.add_argument("command", choices=["build", "analyze"])
    parser.add_argument("--as-of", default="2025-12-31")
    args = parser.parse_args()
    if args.command == "build":
        generate(DEFAULT_DB)
        generate_labels()
    print(json.dumps(build_reports(as_of=args.as_of), indent=2))


if __name__ == "__main__":
    main()
