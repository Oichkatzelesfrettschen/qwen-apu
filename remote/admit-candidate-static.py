#!/usr/bin/env python3
"""Read a candidate's architecture and tokenizer identity without fetching it.

A GGUF places its metadata block and tensor index at the head of the file, so
an HTTP range read of the first megabytes answers what architecture the file
declares, what chat template it carries, and what its tensors weigh, while the
weights themselves stay on the server. Static admission costs a few megabytes
per candidate where a one-token load costs the whole artifact, which is what
lets the funnel cut the set before any device time is spent.

The parser is remote/gguf-tensor-census.py, imported rather than reimplemented,
so the reader this tree already cross-checks against the pinned gguf-py is the
reader that fills the ledger.

A short read is a distinct failure from an absent key. The ledger writes `-`
for a column it has not fetched, so a truncated buffer that silently produced
"no chat template" would fabricate an absence; every parse that runs off the
end of the buffer refetches at the next window and reports `short-read` when
the largest window still fails.
"""

import argparse
import contextlib
import hashlib
import importlib.util
import json
import pathlib
import re
import subprocess
import sys

SCRIPT_DIRECTORY = pathlib.Path(__file__).resolve().parent
HUGGINGFACE_ENDPOINT = "https://huggingface.co"

# Windows the header is read at, in bytes. The metadata block carries the whole
# vocabulary: the 2B distill declares 248,320 tokens and its header ends at
# 10,962,034 bytes, so a one-megabyte window falls short on every
# full-vocabulary Qwen file and sixteen covers them in a single read. Each
# retry refetches from zero, so the ladder is short on purpose.
HEADER_WINDOWS = (16 << 20, 64 << 20, 256 << 20)

# A projector encodes images into a language model's embedding space and
# declares its own architecture, so it answers a different question than the
# checkpoint it pairs with and never stands as the artifact a row is read from.
PROJECTOR_PATTERN = re.compile(r"mmproj", re.IGNORECASE)

# A sharded artifact carries its metadata block in the first part alone.
SHARD_PATTERN = re.compile(r"-(\d{5})-of-(\d{5})\.gguf$", re.IGNORECASE)

# Preference order for the artifact a fingerprint is read from. Q4_K_M is the
# quantization every measured row in this tree serves, so reading it makes the
# fingerprint comparable with the served rows; the remaining entries fall back
# through the formats a repository publishes instead.
ARTIFACT_PREFERENCE = ("q4_k_m", "q4_k_s", "q4_0", "q5_k_m", "q6_k", "q8_0",
                       "bf16", "f16")


def load_census_module():
    """Import the census parser from its hyphenated filename."""
    census_path = SCRIPT_DIRECTORY / "gguf-tensor-census.py"
    spec = importlib.util.spec_from_file_location("gguf_tensor_census",
                                                  census_path)
    if spec is None or spec.loader is None:
        raise SystemExit(f"census parser is unreadable: {census_path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


CENSUS = load_census_module()


class AdmissionError(Exception):
    pass


def fetch_json(url):
    result = subprocess.run(
        ["curl", "-sSL", "--fail-with-body", "-w", "\n%{http_code}", url],
        capture_output=True, text=True)
    body, _, status = result.stdout.rpartition("\n")
    if result.returncode != 0 or status.strip() != "200":
        raise AdmissionError(
            f"tree query returned {status.strip() or 'no status'}: {url}")
    return json.loads(body)


def fetch_range(url, length):
    """Read the first `length` bytes, and report what the server actually sent."""
    result = subprocess.run(
        ["curl", "-sSL", "--fail-with-body", "-H", f"Range: bytes=0-{length - 1}",
         "-w", "%{http_code}", "-o", "/dev/stdout", url],
        capture_output=True)
    payload = result.stdout
    status = payload[-3:].decode("ascii", errors="replace")
    payload = payload[:-3]
    if result.returncode != 0 or status not in ("200", "206"):
        raise AdmissionError(f"range read returned {status or 'no status'}: {url}")
    return payload


def list_artifacts(repository, revision):
    url = (f"{HUGGINGFACE_ENDPOINT}/api/models/{repository}/tree/{revision}"
           "?recursive=1")
    entries = []
    for entry in fetch_json(url):
        if entry.get("type") != "file":
            continue
        path = entry.get("path", "")
        if not path.lower().endswith(".gguf"):
            continue
        size = entry.get("size")
        lfs = entry.get("lfs") or {}
        entries.append({"path": path, "bytes": lfs.get("size", size)})
    return entries


def select_artifact(entries, requested_file=None):
    """Name the one file a fingerprint is read from, and say why it was chosen."""
    if requested_file is not None:
        for entry in entries:
            if entry["path"] == requested_file:
                return entry, "requested"
        raise AdmissionError(f"requested file is absent from the tree: {requested_file}")

    candidates = []
    for entry in entries:
        if PROJECTOR_PATTERN.search(entry["path"]):
            continue
        shard = SHARD_PATTERN.search(entry["path"])
        if shard is not None and shard.group(1) != "00001":
            continue
        candidates.append(entry)
    if not candidates:
        raise AdmissionError("the tree holds no checkpoint GGUF")

    lowered = {entry["path"]: entry["path"].lower() for entry in candidates}
    for preference in ARTIFACT_PREFERENCE:
        matched = [entry for entry in candidates
                   if preference in lowered[entry["path"]]]
        if matched:
            matched.sort(key=lambda entry: (entry["bytes"] or 0, entry["path"]))
            return matched[0], f"preference:{preference}"
    candidates.sort(key=lambda entry: (entry["bytes"] or 0, entry["path"]))
    return candidates[0], "smallest"


def parse_header_over_range(url):
    """Grow the window until the header parses, or report the short read."""
    last_error = None
    for window in HEADER_WINDOWS:
        payload = fetch_range(url, window)
        if payload[:4] != CENSUS.GGUF_MAGIC:
            raise AdmissionError(
                f"file does not begin with the GGUF magic: {payload[:4]!r}")
        reader = CENSUS.GgufReader(payload)
        try:
            header = CENSUS.parse_header(reader)
        except CENSUS.GgufReadError as error:
            last_error = error
            if len(payload) < window:
                # The server sent the whole file and it still failed to parse,
                # so a larger window returns the same bytes.
                raise AdmissionError(f"header is malformed: {error}") from error
            continue
        return header, window
    raise AdmissionError(
        f"header exceeds {HEADER_WINDOWS[-1]} bytes: {last_error}")


def fingerprint(header):
    """Reduce the metadata block to the two identity claims the ledger carries."""
    metadata = header["metadata"]
    architecture = metadata.get("general.architecture", "")
    dimensions = CENSUS.architecture_dimensions(metadata, architecture)
    # The fingerprint names the shape a loader must support, in a fixed key
    # order so two rows of one architecture at different sizes stay comparable.
    parts = [architecture]
    for key in ("block_count", "embedding_length", "feed_forward_length",
                "attention.head_count", "attention.head_count_kv",
                "context_length", "nextn_predict_layers"):
        if key in dimensions:
            parts.append(f"{key}={dimensions[key]}")
    identity = CENSUS.tokenizer_identity(metadata)
    return {
        "architecture": architecture,
        "architecture_fingerprint": "/".join(parts),
        "chat_template_sha256": identity.get("chat_template_sha256", "absent"),
        "chat_template_bytes": identity.get("chat_template_bytes", 0),
        "tokenizer_model": identity.get("model", "absent"),
        "tokenizer_pre": identity.get("pre", "absent"),
        "vocabulary_size": identity.get("vocabulary_size", 0),
        "tokens_sha256": identity.get("tokens_sha256", "absent"),
        "block_count": header["block_count"],
        "nextn_layers": header["nextn_layers"],
        "tensor_count": len(header["tensors"]),
    }


def streamed_bytes(header):
    """Sum what an ordinary load streams, which excludes the prediction block.

    llama_hparams::n_layer_effective subtracts the multi-token-prediction
    layers from the trunk and an ordinary load reports each of their tensors as
    unused, so the file size overstates per-token traffic by that block.
    """
    total = 0
    skipped = 0
    for tensor in header["tensors"]:
        if tensor["family"] == "mtp":
            skipped += tensor["bytes"]
            continue
        total += tensor["bytes"]
    return total, skipped


# Capabilities a serving path depends on and a template either implements or
# does not. The appliance turns reasoning off through
# chat_template_kwargs.enable_thinking, and the graded tool rows put a schema in
# the request body's tools field, so a template silent on either name answers
# the same way whatever the request sets.
TEMPLATE_CAPABILITIES = (
    ("enable_thinking", re.compile(r"enable_thinking")),
    ("thinking_block", re.compile(r"<think>")),
    ("tools", re.compile(r"\btools\b")),
    ("tool_calls", re.compile(r"tool_calls")),
)


def template_capabilities(template):
    if not isinstance(template, str):
        return {}
    return {name: bool(pattern.search(template))
            for name, pattern in TEMPLATE_CAPABILITIES}


def admit(repository, revision, requested_file=None):
    entries = list_artifacts(repository, revision)
    entry, selection_rule = select_artifact(entries, requested_file)
    url = (f"{HUGGINGFACE_ENDPOINT}/{repository}/resolve/{revision}/"
           f"{entry['path']}")
    header, window = parse_header_over_range(url)
    record = fingerprint(header)
    record["chat_template"] = header["metadata"].get("tokenizer.chat_template")
    record.update(template_capabilities(record["chat_template"]))
    loaded, skipped = streamed_bytes(header)
    record.update({
        "repository": repository,
        "revision": revision,
        "artifact": entry["path"],
        "artifact_bytes": entry["bytes"],
        "selection_rule": selection_rule,
        "header_window_bytes": window,
        "gguf_version": header["version"],
        "loaded_tensor_bytes": loaded,
        "skipped_mtp_bytes": skipped,
        "gguf_file_count": len(entries),
    })
    return record


def main(argv):
    parser = argparse.ArgumentParser(
        description="Fingerprint a GGUF candidate over an HTTP range read")
    parser.add_argument("repository", nargs="?",
                        help="Hugging Face repository, owner/name")
    parser.add_argument("revision", nargs="?", help="pinned commit")
    parser.add_argument("--file", help="read this exact file rather than selecting one")
    parser.add_argument("--ledger", help="admit every gguf row of this ledger")
    parser.add_argument("--format", choices=("json", "tsv"), default="json")
    parser.add_argument("--print-chat-template", action="store_true",
                        help="write the template itself rather than a record")
    arguments = parser.parse_args(argv)

    if arguments.ledger and arguments.file:
        parser.error("--file names one artifact and cannot apply to a ledger")

    requests = []
    if arguments.ledger:
        with open(arguments.ledger, encoding="utf-8") as handle:
            header_fields = None
            for line in handle:
                if line.startswith("#") or not line.strip():
                    continue
                fields = line.rstrip("\n").split("\t")
                if header_fields is None:
                    header_fields = fields
                    continue
                row = dict(zip(header_fields, fields))
                if row.get("artifact_kind") != "gguf":
                    continue
                requests.append((row["candidate_id"], row["artifact_repository"],
                                 row["artifact_revision"]))
    elif arguments.repository and arguments.revision:
        requests.append((arguments.repository, arguments.repository,
                         arguments.revision))
    else:
        parser.error("name a repository and revision, or a ledger")

    records = []
    for candidate_id, repository, revision in requests:
        try:
            record = admit(repository, revision, arguments.file)
            record["admission"] = "parsed"
        except AdmissionError as error:
            record = {"repository": repository, "revision": revision,
                      "admission": "failed", "reason": str(error)}
        record["candidate_id"] = candidate_id
        records.append(record)
        if arguments.ledger:
            print(f"{candidate_id}\t{record['admission']}\t"
                  f"{record.get('architecture_fingerprint', record.get('reason', ''))}",
                  file=sys.stderr)

    if arguments.print_chat_template:
        for record in records:
            print(f"===== {record['candidate_id']} "
                  f"{record.get('chat_template_sha256', record.get('reason'))}")
            print(record.get("chat_template") or "")
        return 0 if all(r["admission"] == "parsed" for r in records) else 1

    # The template itself is kilobytes of Jinja that only its hash identifies,
    # so a record carries the hash and the capability flags and leaves the text
    # to --print-chat-template.
    for record in records:
        record.pop("chat_template", None)

    if arguments.format == "json":
        json.dump(records, sys.stdout, indent=2, sort_keys=True)
        print()
    else:
        # The provenance columns travel with the fingerprint because a
        # fingerprint speaks for one file of a repository that publishes many,
        # and a reader comparing two rows needs to know which files were read.
        columns = ("candidate_id", "admission", "architecture", "block_count",
                   "nextn_layers", "vocabulary_size", "tokenizer_pre",
                   "chat_template_sha256", "chat_template_bytes",
                   "tokens_sha256", "artifact", "artifact_bytes",
                   "loaded_tensor_bytes", "skipped_mtp_bytes",
                   "gguf_file_count", "selection_rule", "header_window_bytes",
                   "enable_thinking", "thinking_block", "tools", "tool_calls",
                   "architecture_fingerprint")
        print("\t".join(columns))
        for record in records:
            print("\t".join(str(record.get(column, "-")) for column in columns))
    return 0 if all(r["admission"] == "parsed" for r in records) else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
