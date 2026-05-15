import json
import os
import re
import subprocess

TEMPLATE_PATH = ".github/release-notes/combined-release-template.md"
OUTPUT_PATH = "combined-release.md"
IMAGES = ["core-image-minimal", "core-image-medtech"]


def parse_csv_env(value):
    if not value:
        return []
    return [item.strip() for item in value.split(",") if item.strip()]


def run_gh_api(path):
    result = subprocess.check_output(["gh", "api", path], text=True)
    return json.loads(result)


def extract_whats_changed_items(body):
    match = re.search(r"(?is)^##\s*What's Changed\s*$\n(.*?)(?=^##\s|\Z)", body, re.MULTILINE)
    if not match:
        return []
    section = match.group(1)
    items = []
    for line in section.splitlines():
        stripped = line.strip()
        if stripped.startswith("* ") or stripped.startswith("- "):
            items.append(stripped)
    return items


def strip_whats_changed(body):
    return re.sub(r"(?is)^##\s*What's Changed\s*$\n.*?(?=^##\s|\Z)", "", body, flags=re.MULTILINE).strip()


def release_channel_text(release):
    return "prerelease" if release.get("prerelease") else "release"


def build_bundle_links(releases):
    lines = []
    for rel in releases:
        image = rel["image"]
        html_url = rel["html_url"]
        if html_url:
            lines.append(f"- [{image}]({html_url})")
        else:
            lines.append(f"- {image}")
    return "\n".join(lines).strip()


def infer_image_from_tag(tag):
    match = re.match(r"^(.*)-v\d+.*$", tag)
    if match:
        return match.group(1)
    return tag


def main():
    release_version = os.environ.get("RELEASE_VERSION", "").strip()
    repository = os.environ.get("GITHUB_REPOSITORY", "").strip()
    grouped_release_tags = parse_csv_env(os.environ.get("GROUPED_RELEASE_TAGS", ""))

    if not release_version:
        raise RuntimeError("RELEASE_VERSION is required")
    if not repository:
        raise RuntimeError("GITHUB_REPOSITORY is required")

    tags = grouped_release_tags if grouped_release_tags else [f"{image}-{release_version}" for image in IMAGES]

    releases = []
    image_details = []
    seen_changes = set()
    merged_changes = []

    for tag in tags:
        image = infer_image_from_tag(tag)
        api_path = f"repos/{repository}/releases/tags/{tag}"
        try:
            rel = run_gh_api(api_path)
        except subprocess.CalledProcessError:
            rel = {
                "tag_name": tag,
                "name": tag,
                "html_url": "",
                "prerelease": False,
                "assets": [],
                "body": f"_No release notes found for {tag}_",
            }

        body = rel.get("body") or ""
        stripped_details = strip_whats_changed(body)
        image_details.append(f"### {image}\n\n{stripped_details}\n")

        for item in extract_whats_changed_items(body):
            if item not in seen_changes:
                seen_changes.add(item)
                merged_changes.append(item)

        releases.append(
            {
                "image": image,
                "tag_name": rel.get("tag_name", tag),
                "html_url": rel.get("html_url", ""),
                "channel": release_channel_text(rel),
                "assets": rel.get("assets", []),
            }
        )

    bundle_links = build_bundle_links(releases)
    whats_changed = "\n".join(merged_changes).strip() if merged_changes else "_No changes found._"

    with open(TEMPLATE_PATH, "r", encoding="utf-8") as file:
        template = file.read()

    output = template.replace("{{RELEASE_VERSION}}", release_version)
    output = output.replace("{{BUNDLE_LINKS}}", bundle_links)
    output = output.replace("{{IMAGE_DETAILS}}", "\n".join(image_details).strip())
    output = output.replace("{{WHATS_CHANGED}}", whats_changed)

    with open(OUTPUT_PATH, "w", encoding="utf-8") as file:
        file.write(output)

    print(f"Combined release notes written to {OUTPUT_PATH}")


if __name__ == "__main__":
    main()
