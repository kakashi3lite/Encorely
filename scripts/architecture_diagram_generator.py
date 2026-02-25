#!/usr/bin/env python3
"""Architecture Diagram Generator

Automated tool for generating architecture diagrams from project structure.
Supports multiple output formats and configurable templates.
"""

import argparse
import json
import os
import sys
from pathlib import Path


def parse_args():
    parser = argparse.ArgumentParser(
        description="Generate architecture diagrams from project structure"
    )
    parser.add_argument(
        "project_path",
        nargs="?",
        default=".",
        help="Path to the project directory (default: current directory)",
    )
    parser.add_argument(
        "--output",
        "-o",
        default="architecture_diagram",
        help="Output file name without extension (default: architecture_diagram)",
    )
    parser.add_argument(
        "--format",
        "-f",
        choices=["mermaid", "plantuml", "json"],
        default="mermaid",
        help="Output diagram format (default: mermaid)",
    )
    parser.add_argument(
        "--verbose",
        "-v",
        action="store_true",
        help="Enable verbose output",
    )
    return parser.parse_args()


def detect_tech_stack(project_path: Path) -> dict:
    """Detect the technology stack used in the project."""
    stack = {
        "languages": [],
        "frontend": [],
        "backend": [],
        "database": [],
        "devops": [],
    }

    indicators = {
        "package.json": ("languages", "JavaScript/TypeScript"),
        "requirements.txt": ("languages", "Python"),
        "go.mod": ("languages", "Go"),
        "Package.swift": ("languages", "Swift"),
        "build.gradle": ("languages", "Kotlin/Java"),
        "pubspec.yaml": ("frontend", "Flutter"),
        "next.config.js": ("frontend", "Next.js"),
        "Dockerfile": ("devops", "Docker"),
        "docker-compose.yml": ("devops", "Docker Compose"),
        "k8s": ("devops", "Kubernetes"),
        "terraform": ("devops", "Terraform"),
    }

    for indicator, (category, tech) in indicators.items():
        path = project_path / indicator
        if path.exists():
            if tech not in stack[category]:
                stack[category].append(tech)

    return stack


def scan_components(project_path: Path, verbose: bool = False) -> list:
    """Scan project for architectural components."""
    components = []
    component_dirs = [
        "src", "lib", "app", "api", "services", "components",
        "models", "views", "controllers", "utils", "helpers",
        "middleware", "config", "scripts", "tests",
    ]

    for comp_dir in component_dirs:
        comp_path = project_path / comp_dir
        if comp_path.exists() and comp_path.is_dir():
            components.append(comp_dir)
            if verbose:
                print(f"  Found component: {comp_dir}")

    return components


def generate_mermaid_diagram(stack: dict, components: list, project_name: str) -> str:
    """Generate a Mermaid architecture diagram."""
    lines = [
        "graph TD",
        f'    Client["Client Layer"]',
        f'    API["API / Backend Layer"]',
        f'    Data["Data Layer"]',
        f'    Infra["Infrastructure"]',
        "",
        "    Client --> API",
        "    API --> Data",
        "    API --> Infra",
    ]

    if stack["frontend"]:
        for tech in stack["frontend"]:
            safe = tech.replace("/", "_").replace(".", "_").replace(" ", "_")
            lines.append(f'    {safe}["{tech}"] --> Client')

    if stack["backend"]:
        for tech in stack["backend"]:
            safe = tech.replace("/", "_").replace(".", "_").replace(" ", "_")
            lines.append(f'    API --> {safe}["{tech}"]')

    if stack["database"]:
        for tech in stack["database"]:
            safe = tech.replace("/", "_").replace(".", "_").replace(" ", "_")
            lines.append(f'    Data --> {safe}["{tech}"]')

    for comp in components:
        lines.append(f'    API --> {comp}["{comp}/"]')

    return "\n".join(lines)


def generate_plantuml_diagram(stack: dict, components: list, project_name: str) -> str:
    """Generate a PlantUML architecture diagram."""
    lines = [
        "@startuml",
        f"title {project_name} Architecture",
        "",
        "package \"Frontend\" {",
    ]

    for tech in stack.get("frontend", ["Web Client"]) or ["Web Client"]:
        lines.append(f'  [{tech}]')
    lines.append("}")
    lines.append("")
    lines.append('package "Backend" {')
    for comp in components:
        lines.append(f'  [{comp}]')
    lines.append("}")
    lines.append("")
    lines.append('package "Data" {')
    for tech in stack.get("database", ["Database"]) or ["Database"]:
        lines.append(f'  [{tech}]')
    lines.append("}")
    lines.append("")
    lines.append("[Frontend] --> [Backend]")
    lines.append("[Backend] --> [Data]")
    lines.append("@enduml")

    return "\n".join(lines)


def generate_json_diagram(stack: dict, components: list, project_name: str) -> str:
    """Generate a JSON representation of the architecture."""
    diagram = {
        "project": project_name,
        "tech_stack": stack,
        "components": components,
        "layers": {
            "presentation": stack.get("frontend", []),
            "application": components,
            "data": stack.get("database", []),
            "infrastructure": stack.get("devops", []),
        },
    }
    return json.dumps(diagram, indent=2)


def main():
    args = parse_args()
    project_path = Path(args.project_path).resolve()

    if not project_path.exists():
        print(f"Error: Project path '{project_path}' does not exist.", file=sys.stderr)
        sys.exit(1)

    project_name = project_path.name
    print(f"Generating architecture diagram for: {project_name}")
    print(f"Project path: {project_path}")
    print(f"Output format: {args.format}")

    if args.verbose:
        print("\nScanning project structure...")

    stack = detect_tech_stack(project_path)
    components = scan_components(project_path, verbose=args.verbose)

    if args.verbose:
        print(f"\nDetected tech stack: {stack}")
        print(f"Found components: {components}")

    if args.format == "mermaid":
        diagram = generate_mermaid_diagram(stack, components, project_name)
        ext = "md"
        content = f"# {project_name} Architecture Diagram\n\n```mermaid\n{diagram}\n```\n"
    elif args.format == "plantuml":
        diagram = generate_plantuml_diagram(stack, components, project_name)
        ext = "puml"
        content = diagram
    else:
        diagram = generate_json_diagram(stack, components, project_name)
        ext = "json"
        content = diagram

    output_file = Path(args.output).with_suffix(f".{ext}")
    output_file.write_text(content)
    print(f"\nArchitecture diagram saved to: {output_file}")
    print("Done.")


if __name__ == "__main__":
    main()
