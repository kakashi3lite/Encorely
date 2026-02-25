#!/usr/bin/env python3
"""Project Architect

Comprehensive analysis and optimization tool for software projects.
Provides deep analysis, performance metrics, and actionable recommendations.
"""

import argparse
import os
import sys
from pathlib import Path


def parse_args():
    parser = argparse.ArgumentParser(
        description="Analyze project architecture and provide recommendations"
    )
    parser.add_argument(
        "target_path",
        nargs="?",
        default=".",
        help="Path to the project directory (default: current directory)",
    )
    parser.add_argument(
        "--verbose",
        "-v",
        action="store_true",
        help="Enable verbose output",
    )
    parser.add_argument(
        "--fix",
        action="store_true",
        help="Automatically apply recommended fixes where possible",
    )
    return parser.parse_args()


def check_project_structure(project_path: Path, verbose: bool = False) -> list:
    """Check for recommended project structure elements."""
    recommendations = []
    checks = {
        "README.md": "Add a README.md with project overview and setup instructions",
        ".gitignore": "Add a .gitignore to exclude build artifacts and secrets",
        ".env.example": "Add a .env.example to document required environment variables",
        "CONTRIBUTING.md": "Add a CONTRIBUTING.md to guide contributors",
        "CHANGELOG.md": "Add a CHANGELOG.md to track version history",
    }

    for filename, recommendation in checks.items():
        path = project_path / filename
        if not path.exists():
            recommendations.append({"type": "structure", "message": recommendation})
            if verbose:
                print(f"  [MISSING] {filename}: {recommendation}")
        elif verbose:
            print(f"  [OK] {filename}")

    return recommendations


def check_code_quality(project_path: Path, verbose: bool = False) -> list:
    """Check for code quality indicators."""
    recommendations = []

    test_dirs = ["tests", "test", "__tests__", "spec"]
    has_tests = any((project_path / d).exists() for d in test_dirs)
    if not has_tests:
        recommendations.append({
            "type": "quality",
            "message": "Add a tests/ directory with unit and integration tests",
        })
        if verbose:
            print("  [MISSING] Test directory")
    elif verbose:
        print("  [OK] Test directory found")

    lint_configs = [
        ".eslintrc", ".eslintrc.js", ".eslintrc.json", ".eslintrc.yml",
        ".pylintrc", "pyproject.toml", ".swiftlint.yml", ".golangci.yml",
    ]
    has_linter = any((project_path / f).exists() for f in lint_configs)
    if not has_linter:
        recommendations.append({
            "type": "quality",
            "message": "Add linter configuration (ESLint, Pylint, SwiftLint, etc.)",
        })
        if verbose:
            print("  [MISSING] Linter configuration")
    elif verbose:
        print("  [OK] Linter configuration found")

    return recommendations


def check_security(project_path: Path, verbose: bool = False) -> list:
    """Check for security best practices."""
    recommendations = []

    security_files = ["SECURITY.md", ".github/SECURITY.md"]
    has_security = any((project_path / f).exists() for f in security_files)
    if not has_security:
        recommendations.append({
            "type": "security",
            "message": "Add a SECURITY.md to document vulnerability reporting process",
        })
        if verbose:
            print("  [MISSING] SECURITY.md")
    elif verbose:
        print("  [OK] SECURITY.md found")

    env_files = [".env", ".env.local", ".env.development"]
    for env_file in env_files:
        env_path = project_path / env_file
        if env_path.exists():
            gitignore_path = project_path / ".gitignore"
            if gitignore_path.exists():
                gitignore_content = gitignore_path.read_text()
                if env_file not in gitignore_content and ".env" not in gitignore_content:
                    recommendations.append({
                        "type": "security",
                        "message": f"Ensure {env_file} is listed in .gitignore to avoid leaking secrets",
                    })
                    if verbose:
                        print(f"  [WARNING] {env_file} may not be gitignored")

    return recommendations


def check_ci_cd(project_path: Path, verbose: bool = False) -> list:
    """Check for CI/CD configuration."""
    recommendations = []
    ci_paths = [
        ".github/workflows",
        ".circleci",
        ".gitlab-ci.yml",
        "Jenkinsfile",
        ".travis.yml",
    ]

    has_ci = any((project_path / p).exists() for p in ci_paths)
    if not has_ci:
        recommendations.append({
            "type": "devops",
            "message": "Add CI/CD configuration (GitHub Actions, CircleCI, etc.)",
        })
        if verbose:
            print("  [MISSING] CI/CD configuration")
    elif verbose:
        print("  [OK] CI/CD configuration found")

    return recommendations


def compute_metrics(project_path: Path) -> dict:
    """Compute basic project metrics."""
    metrics = {
        "total_files": 0,
        "source_files": 0,
        "test_files": 0,
        "doc_files": 0,
    }

    source_extensions = {".py", ".js", ".ts", ".swift", ".kt", ".go", ".dart"}
    test_keywords = {"test", "spec", "__test__"}

    try:
        for root, dirs, files in os.walk(project_path):
            dirs[:] = [d for d in dirs if not d.startswith(".") and d not in {"node_modules", ".git", "build", "dist"}]
            for fname in files:
                metrics["total_files"] += 1
                ext = Path(fname).suffix.lower()
                if ext in source_extensions:
                    metrics["source_files"] += 1
                    if any(kw in fname.lower() for kw in test_keywords):
                        metrics["test_files"] += 1
                if ext in {".md", ".rst", ".txt"}:
                    metrics["doc_files"] += 1
    except PermissionError:
        pass

    return metrics


def print_report(recommendations: list, metrics: dict, project_name: str):
    """Print the analysis report."""
    print(f"\n{'='*60}")
    print(f"Project Architecture Report: {project_name}")
    print(f"{'='*60}")

    print(f"\nProject Metrics:")
    print(f"  Total files:   {metrics['total_files']}")
    print(f"  Source files:  {metrics['source_files']}")
    print(f"  Test files:    {metrics['test_files']}")
    print(f"  Doc files:     {metrics['doc_files']}")

    if recommendations:
        print(f"\nRecommendations ({len(recommendations)} found):")
        categories = {}
        for rec in recommendations:
            cat = rec["type"]
            categories.setdefault(cat, []).append(rec["message"])

        for category, messages in sorted(categories.items()):
            print(f"\n  [{category.upper()}]")
            for msg in messages:
                print(f"    - {msg}")
    else:
        print("\nNo recommendations - project looks great!")

    print(f"\n{'='*60}")


def main():
    args = parse_args()
    project_path = Path(args.target_path).resolve()

    if not project_path.exists():
        print(f"Error: Target path '{project_path}' does not exist.", file=sys.stderr)
        sys.exit(1)

    project_name = project_path.name
    print(f"Analyzing project: {project_name}")
    print(f"Path: {project_path}")

    if args.verbose:
        print("\nChecking project structure...")
    structure_recs = check_project_structure(project_path, verbose=args.verbose)

    if args.verbose:
        print("\nChecking code quality...")
    quality_recs = check_code_quality(project_path, verbose=args.verbose)

    if args.verbose:
        print("\nChecking security practices...")
    security_recs = check_security(project_path, verbose=args.verbose)

    if args.verbose:
        print("\nChecking CI/CD configuration...")
    cicd_recs = check_ci_cd(project_path, verbose=args.verbose)

    if args.verbose:
        print("\nComputing project metrics...")
    metrics = compute_metrics(project_path)

    all_recommendations = structure_recs + quality_recs + security_recs + cicd_recs
    print_report(all_recommendations, metrics, project_name)

    return 0 if not all_recommendations else 1


if __name__ == "__main__":
    sys.exit(main())
