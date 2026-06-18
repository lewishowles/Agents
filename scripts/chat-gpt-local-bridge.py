#!/usr/bin/env python3
"""
Minimal local file bridge for ChatGPT Canvas.

Run this from the repository root:

	python local_bridge.py

Then Canvas/Python can read files from:

	http://127.0.0.1:8753/files/PROGRESS.md

Writes are supported with PUT, but should only be used when you explicitly request edits.
"""

from __future__ import annotations

import argparse
import os
import secrets
from pathlib import Path
from flask import Flask, request, jsonify, Response, abort

app = Flask(__name__)

ROOT: Path
TOKEN: str

def safe_path(relative_path: str) -> Path:
	# Normalize and prevent path traversal.
	candidate = (ROOT / relative_path).resolve()

	if candidate == ROOT or ROOT in candidate.parents:
		return candidate

	abort(403, description="Path escapes repository root")


def require_token() -> None:
	supplied = request.headers.get("X-Bridge-Token")
	if not supplied or supplied != TOKEN:
		abort(401, description="Missing or invalid X-Bridge-Token")


@app.after_request
def add_cors_headers(response):
	# Keep this limited to localhost use.
	response.headers["Access-Control-Allow-Origin"] = "*"
	response.headers["Access-Control-Allow-Headers"] = "Content-Type, X-Bridge-Token"
	response.headers["Access-Control-Allow-Methods"] = "GET, PUT, OPTIONS"
	return response


@app.route("/files/<path:relative_path>", methods=["OPTIONS"])
def options_file(relative_path: str):
	return Response(status=204)


@app.route("/files/<path:relative_path>", methods=["GET"])
def read_file(relative_path: str):
	require_token()

	path = safe_path(relative_path)

	if not path.exists():
		abort(404, description="File not found")

	if not path.is_file():
		abort(400, description="Path is not a file")

	try:
		text = path.read_text(encoding="utf-8")
	except UnicodeDecodeError:
		abort(400, description="Only UTF-8 text files are supported")

	return Response(text, mimetype="text/plain; charset=utf-8")


@app.route("/files/<path:relative_path>", methods=["PUT"])
def write_file(relative_path: str):
	require_token()

	path = safe_path(relative_path)

	if path.exists() and not path.is_file():
		abort(400, description="Path is not a file")

	body = request.get_data(as_text=True)

	# Create parent directories only inside the repo.
	path.parent.mkdir(parents=True, exist_ok=True)
	path.write_text(body, encoding="utf-8")

	return jsonify({
		"ok": True,
		"path": str(path.relative_to(ROOT)),
		"bytes": len(body.encode("utf-8")),
	})


@app.route("/health", methods=["GET"])
def health():
    require_token()

    return jsonify({
        "ok": True,
        "root": str(ROOT),
    })

@app.route("/ping")
def ping():
    return "pong"

def main():
	global ROOT, TOKEN

	parser = argparse.ArgumentParser()
	parser.add_argument("--host", default="127.0.0.1")
	parser.add_argument("--port", default=8753, type=int)
	parser.add_argument("--root", default=".")
	parser.add_argument("--token", default=None)
	parser.add_argument("--token-file", default=os.path.expanduser("~/.chatgpt-bridge-token"))
	args = parser.parse_args()

	ROOT = Path(args.root).resolve()

	if not ROOT.exists() or not ROOT.is_dir():
		raise SystemExit(f"Root does not exist or is not a directory: {ROOT}")

	if args.token:
		TOKEN = args.token
	else:
		token_path = Path(args.token_file)

		if not token_path.exists():
			raise SystemExit(
				f"Token file does not exist: {token_path}"
			)

		TOKEN = token_path.read_text(
			encoding="utf-8"
		).strip()

	print()
	print("Local bridge running")
	print(f"Root:  {ROOT}")
	print(f"URL:   http://{args.host}:{args.port}")
	print(f"Token: {TOKEN}")
	print()
	print("Keep this terminal open while using the GPT.")
	print("Stop it with Ctrl+C.")
	print()

	app.run(host=args.host, port=args.port)


if __name__ == "__main__":
	main()
