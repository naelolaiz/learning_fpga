#!/usr/bin/env python3
"""Emit netlistsvg decoration flags inferred from a project's netlist.

The shared Makefile still accepts explicit SVG_LINKS/SVG_RELABEL entries
for overrides. This helper fills in the common case automatically:

* submodule cells get clean labels from their Yosys/GHDL cell type;
* cells whose module has its own gallery diagram link to that diagram;
* otherwise, cells whose module comes from a source file link to source.
"""
import argparse
import json
import os
from pathlib import Path
import re
import sys


ASSIGN_RE = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*)\s*:?=\s*(.*)$")
VHDL_ENTITY_RE = re.compile(r"(?im)^\s*entity\s+([A-Za-z][A-Za-z0-9_]*)\s+is\b")
VERILOG_MODULE_RE = re.compile(r"(?m)^\s*module\s+([A-Za-z_][A-Za-z0-9_$]*)\b")


def _logical_make_lines(text: str):
    buf = ""
    for raw in text.splitlines():
        line = raw.split("#", 1)[0].rstrip()
        if not line and not buf:
            continue
        if line.endswith("\\"):
            buf += line[:-1] + " "
            continue
        yield (buf + line).strip()
        buf = ""
    if buf.strip():
        yield buf.strip()


def _parse_make_vars(path: Path) -> dict[str, str]:
    vals: dict[str, str] = {}
    try:
        text = path.read_text(encoding="utf-8")
    except OSError:
        return vals
    for line in _logical_make_lines(text):
        m = ASSIGN_RE.match(line)
        if m:
            vals[m.group(1)] = m.group(2).strip()
    return vals


def _add_alias(mapping: dict[str, set[str]], key: str, value: str) -> None:
    if not key or not value:
        return
    mapping.setdefault(key, set()).add(value)
    mapping.setdefault(key.lower(), set()).add(value)


def _single(mapping: dict[str, set[str]], key: str) -> str | None:
    vals = mapping.get(key) or mapping.get(key.lower())
    if vals and len(vals) == 1:
        return next(iter(vals))
    return None


def _artifact_dir(project: Path, repo_root: Path) -> str:
    rel = project.relative_to(repo_root).as_posix()
    return rel.replace("/", "-")


def _scan_diagram_targets(
    repo_root: Path,
    flow: str,
) -> tuple[dict[str, set[str]], dict[str, set[str]]]:
    targets: dict[str, set[str]] = {}
    labels: dict[str, set[str]] = {}
    for makefile in repo_root.rglob("Makefile"):
        if makefile == repo_root / "Makefile":
            continue
        try:
            text = makefile.read_text(encoding="utf-8")
        except OSError:
            continue
        if "mk/common.mk" not in text:
            continue
        vals = _parse_make_vars(makefile)
        artifact = _artifact_dir(makefile.parent, repo_root)
        if flow == "verilog":
            top = vals.get("V_TOP")
            if top:
                _add_alias(targets, top, f"../{artifact}/{top}_v.svg")
                _add_alias(labels, top, top)
        else:
            top = vals.get("TOP")
            if top:
                _add_alias(targets, top, f"../{artifact}/{top}.svg")
                _add_alias(labels, top, top)
    return targets, labels


def _github_source_url(repo_rel: str) -> str | None:
    base = os.environ.get("NETLISTSVG_SOURCE_BASE")
    if base:
        return f"{base.rstrip('/')}/{repo_rel}"

    server = os.environ.get("GITHUB_SERVER_URL")
    repo = os.environ.get("GITHUB_REPOSITORY")
    ref = (
        os.environ.get("NETLISTSVG_SOURCE_REF")
        or os.environ.get("GITHUB_HEAD_SHA")
        or os.environ.get("GITHUB_SHA")
    )
    if server and repo and ref:
        return f"{server.rstrip('/')}/{repo}/blob/{ref}/{repo_rel}"
    return None


def _source_url(path: Path, repo_root: Path, svg_path: Path) -> str:
    repo_rel = path.relative_to(repo_root).as_posix()
    gh_url = _github_source_url(repo_rel)
    if gh_url:
        return gh_url
    return os.path.relpath(path, svg_path.parent)


def _scan_source_targets(
    source_files: list[str],
    project_dir: Path,
    repo_root: Path,
    svg_path: Path,
    flow: str,
) -> tuple[dict[str, set[str]], dict[str, set[str]]]:
    targets: dict[str, set[str]] = {}
    labels: dict[str, set[str]] = {}
    pattern = VERILOG_MODULE_RE if flow == "verilog" else VHDL_ENTITY_RE
    for src in source_files:
        path = (project_dir / src).resolve()
        try:
            text = path.read_text(encoding="utf-8")
        except OSError:
            continue
        url = _source_url(path, repo_root, svg_path.resolve())
        for name in pattern.findall(text):
            _add_alias(targets, name, url)
            _add_alias(labels, name, name)
    return targets, labels


def canonical_type(cell_type: str) -> str | None:
    if cell_type.startswith("$paramod"):
        parts = cell_type.split("\\")
        if len(parts) < 2:
            return None
        name = parts[1]
    elif cell_type.startswith("$"):
        return None
    else:
        name = cell_type

    name = name.lstrip("\\")
    if "_B" in name:
        name = name.split("_B", 1)[0]
    return name or None


def _cell_id(mapping: str) -> str:
    return mapping.split("=", 1)[0]


def _collect_auto_decorations(
    netlist: dict,
    diagram_targets: dict[str, set[str]],
    source_targets: dict[str, set[str]],
    labels: dict[str, set[str]],
) -> tuple[dict[str, set[str]], dict[str, set[str]]]:
    relabels: dict[str, set[str]] = {}
    links: dict[str, set[str]] = {}

    for module in netlist.get("modules", {}).values():
        for cell_id, cell in module.get("cells", {}).items():
            label = canonical_type(cell.get("type", ""))
            if not label:
                continue
            relabels.setdefault(cell_id, set()).add(_single(labels, label) or label)
            target = _single(diagram_targets, label) or _single(source_targets, label)
            if target:
                links.setdefault(cell_id, set()).add(target)

    return relabels, links


def _emit_unique(
    kind: str,
    values: dict[str, set[str]],
    explicit_cells: set[str],
    project_dir: Path,
) -> list[str]:
    args: list[str] = []
    for cell_id in sorted(values):
        if cell_id in explicit_cells:
            continue
        vals = values[cell_id]
        if len(vals) != 1:
            print(
                f"netlistsvg_auto_decorate: {project_dir}: "
                f"skip ambiguous {kind} for cell_{cell_id}: {sorted(vals)}",
                file=sys.stderr,
            )
            continue
        args.extend([f"--{kind}", f"{cell_id}={next(iter(vals))}"])
    return args


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", required=True, type=Path)
    parser.add_argument("--project-dir", required=True, type=Path)
    parser.add_argument("--flow", required=True, choices=("vhdl", "verilog"))
    parser.add_argument("--json", required=True, type=Path)
    parser.add_argument("--svg", required=True, type=Path)
    parser.add_argument("--source-file", action="append", default=[])
    parser.add_argument("--explicit-link", action="append", default=[])
    parser.add_argument("--explicit-relabel", action="append", default=[])
    args = parser.parse_args()

    repo_root = args.repo_root.resolve()
    project_dir = args.project_dir.resolve()
    svg_path = (project_dir / args.svg).resolve()

    with args.json.open(encoding="utf-8") as f:
        netlist = json.load(f)

    diagram_targets, diagram_labels = _scan_diagram_targets(repo_root, args.flow)
    source_targets, source_labels = _scan_source_targets(
        args.source_file,
        project_dir,
        repo_root,
        svg_path,
        args.flow,
    )
    labels = {**diagram_labels}
    for key, value in source_labels.items():
        labels.setdefault(key, set()).update(value)

    relabels, links = _collect_auto_decorations(
        netlist,
        diagram_targets,
        source_targets,
        labels,
    )

    explicit_links = {_cell_id(v) for v in args.explicit_link}
    explicit_relabels = {_cell_id(v) for v in args.explicit_relabel}
    out: list[str] = []
    out += _emit_unique("link", links, explicit_links, project_dir)
    out += _emit_unique("relabel", relabels, explicit_relabels, project_dir)
    print(" ".join(out))
    return 0


if __name__ == "__main__":
    sys.exit(main())
