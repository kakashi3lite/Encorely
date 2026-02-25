#!/usr/bin/env python3
"""Dependency Analyzer

Advanced tooling for analyzing project dependencies.
Provides expert-level automation, custom configurations, and production-grade output.
"""

import argparse
import json
import os
import sys
from pathlib import Path


def parse_args():
    parser = argparse.ArgumentParser(
        description="Analyze project dependencies and detect issues"
    )
    parser.add_argument(
        "project_path",
        nargs="?",
        default=".",
        help="Path to the project directory (default: current directory)",
    )
    parser.add_argument(
        "--analyze",
        action="store_true",
        help="Run full dependency analysis",
    )
    parser.add_argument(
        "--format",
        "-f",
        choices=["text", "json"],
        default="text",
        help="Output format (default: text)",
    )
    parser.add_argument(
        "--verbose",
        "-v",
        action="store_true",
        help="Enable verbose output",
    )
    return parser.parse_args()


def parse_package_json(project_path: Path, verbose: bool = False) -> dict:
    """Parse Node.js package.json for dependencies."""
    pkg_file = project_path / "package.json"
    if not pkg_file.exists():
        return {}

    try:
        data = json.loads(pkg_file.read_text())
        deps = {
            "runtime": list(data.get("dependencies", {}).keys()),
            "dev": list(data.get("devDependencies", {}).keys()),
            "peer": list(data.get("peerDependencies", {}).keys()),
            "versions": {
                **data.get("dependencies", {}),
                **data.get("devDependencies", {}),
            },
        }
        if verbose:
            print(f"  [package.json] {len(deps['runtime'])} runtime, {len(deps['dev'])} dev dependencies")
        return {"type": "npm", "dependencies": deps}
    except (json.JSONDecodeError, OSError) as e:
        print(f"  Warning: Could not parse package.json: {e}", file=sys.stderr)
        return {}


def parse_requirements_txt(project_path: Path, verbose: bool = False) -> dict:
    """Parse Python requirements.txt for dependencies."""
    req_file = project_path / "requirements.txt"
    if not req_file.exists():
        return {}

    try:
        lines = req_file.read_text().splitlines()
        packages = []
        for line in lines:
            line = line.strip()
            if line and not line.startswith("#"):
                packages.append(line)

        if verbose:
            print(f"  [requirements.txt] {len(packages)} packages")
        return {"type": "pip", "packages": packages}
    except OSError as e:
        print(f"  Warning: Could not parse requirements.txt: {e}", file=sys.stderr)
        return {}


def parse_go_mod(project_path: Path, verbose: bool = False) -> dict:
    """Parse Go go.mod for dependencies."""
    mod_file = project_path / "go.mod"
    if not mod_file.exists():
        return {}

    try:
        content = mod_file.read_text()
        modules = []
        in_require = False
        for line in content.splitlines():
            line = line.strip()
            if line.startswith("require ("):
                in_require = True
                continue
            if in_require:
                if line == ")":
                    in_require = False
                elif line:
                    parts = line.split()
                    if len(parts) >= 2:
                        modules.append({"module": parts[0], "version": parts[1]})
            elif line.startswith("require ") and not line.endswith("("):
                parts = line[8:].split()
                if len(parts) >= 2:
                    modules.append({"module": parts[0], "version": parts[1]})

        if verbose:
            print(f"  [go.mod] {len(modules)} modules")
        return {"type": "go", "modules": modules}
    except OSError as e:
        print(f"  Warning: Could not parse go.mod: {e}", file=sys.stderr)
        return {}


def parse_package_swift(project_path: Path, verbose: bool = False) -> dict:
    """Parse Swift Package.swift for dependencies."""
    pkg_file = project_path / "Package.swift"
    if not pkg_file.exists():
        return {}

    try:
        content = pkg_file.read_text()
        packages = []
        for line in content.splitlines():
            line = line.strip()
            if ".package(" in line and "url:" in line:
                packages.append(line.strip())

        if verbose:
            print(f"  [Package.swift] {len(packages)} packages")
        return {"type": "swift_pm", "packages": packages}
    except OSError as e:
        print(f"  Warning: Could not parse Package.swift: {e}", file=sys.stderr)
        return {}


def detect_outdated_patterns(dependencies: list) -> list:
    """Flag known deprecated or problematic dependency patterns."""
    warnings = []
    deprecated = {
        "request": "Use 'axios' or native fetch instead of the deprecated 'request' package",
        "moment": "Consider replacing 'moment' with 'date-fns' or 'dayjs' for smaller bundle size",
        "lodash": "Consider using native JS methods or tree-shaken 'lodash-es' instead of 'lodash'",
        "node-uuid": "Replace 'node-uuid' with the 'uuid' package",
    }

    for dep in dependencies:
        dep_name = dep.split("@")[0].split(">=")[0].split("==")[0].strip()
        if dep_name in deprecated:
            warnings.append({"dependency": dep_name, "message": deprecated[dep_name]})

    return warnings


def print_text_report(all_deps: dict, warnings: list, project_name: str):
    """Print a human-readable dependency report."""
    print(f"\n{'='*60}")
    print(f"Dependency Analysis Report: {project_name}")
    print(f"{'='*60}")

    for manager, data in all_deps.items():
        dep_type = data.get("type", manager)
        print(f"\n[{dep_type.upper()}]")
        if dep_type == "npm":
            deps = data.get("dependencies", {})
            print(f"  Runtime dependencies: {len(deps.get('runtime', []))}")
            print(f"  Dev dependencies:     {len(deps.get('dev', []))}")
            for dep in deps.get("runtime", [])[:10]:
                print(f"    - {dep}: {deps['versions'].get(dep, '?')}")
            if len(deps.get("runtime", [])) > 10:
                print(f"    ... and {len(deps['runtime']) - 10} more")
        elif dep_type == "pip":
            pkgs = data.get("packages", [])
            print(f"  Packages: {len(pkgs)}")
            for pkg in pkgs[:10]:
                print(f"    - {pkg}")
            if len(pkgs) > 10:
                print(f"    ... and {len(pkgs) - 10} more")
        elif dep_type == "go":
            mods = data.get("modules", [])
            print(f"  Modules: {len(mods)}")
            for mod in mods[:10]:
                print(f"    - {mod['module']} {mod['version']}")
            if len(mods) > 10:
                print(f"    ... and {len(mods) - 10} more")
        elif dep_type == "swift_pm":
            pkgs = data.get("packages", [])
            print(f"  Packages: {len(pkgs)}")
            for pkg in pkgs[:10]:
                print(f"    - {pkg}")

    if warnings:
        print(f"\nWarnings ({len(warnings)}):")
        for w in warnings:
            print(f"  [{w['dependency']}] {w['message']}")
    else:
        print("\nNo dependency warnings found.")

    print(f"\n{'='*60}")


def main():
    args = parse_args()
    project_path = Path(args.project_path).resolve()

    if not project_path.exists():
        print(f"Error: Project path '{project_path}' does not exist.", file=sys.stderr)
        sys.exit(1)

    project_name = project_path.name
    print(f"Analyzing dependencies for: {project_name}")

    if args.verbose:
        print("\nParsing dependency manifests...")

    all_deps = {}

    npm_deps = parse_package_json(project_path, verbose=args.verbose)
    if npm_deps:
        all_deps["npm"] = npm_deps

    pip_deps = parse_requirements_txt(project_path, verbose=args.verbose)
    if pip_deps:
        all_deps["pip"] = pip_deps

    go_deps = parse_go_mod(project_path, verbose=args.verbose)
    if go_deps:
        all_deps["go"] = go_deps

    swift_deps = parse_package_swift(project_path, verbose=args.verbose)
    if swift_deps:
        all_deps["swift"] = swift_deps

    if not all_deps:
        print("No recognized dependency manifests found.")
        if not args.analyze:
            print("Tip: Use --analyze flag for a full analysis.")
        sys.exit(0)

    all_packages = []
    for data in all_deps.values():
        dep_type = data.get("type", "")
        if dep_type == "npm":
            all_packages.extend(data.get("dependencies", {}).get("runtime", []))
        elif dep_type == "pip":
            all_packages.extend(data.get("packages", []))

    warnings = detect_outdated_patterns(all_packages) if args.analyze else []

    if args.format == "json":
        output = {
            "project": project_name,
            "dependencies": all_deps,
            "warnings": warnings,
        }
        print(json.dumps(output, indent=2))
    else:
        print_text_report(all_deps, warnings, project_name)

    return 0


if __name__ == "__main__":
    sys.exit(main())
