import os
import re
import subprocess
import sys

TEMPLATE_PATH = ".github/release-notes/combined-release-template.md"
OUTPUT_PATH = "combined-release.md"

release_version = os.environ.get("RELEASE_VERSION")
artifacts_dir = os.getcwd()
images = ["core-image-minimal", "core-image-medtech"]

# Generate summary table
summary_table = ["| Image | SSH Mode | Artifact |", "|-------|----------|----------|"]
image_details = []
whats_changed_sections = set()

# Find artifact folders (assume artifacts are in subdirs)
for f in sorted([x for x in os.listdir(artifacts_dir) if os.path.isdir(x)]):
    for artifact in os.listdir(f):
        img = "-".join(artifact.split("-")[:3])
        mode_match = re.search(r"(public-hardened|internal-keyed)", artifact)
        mode = mode_match.group(1) if mode_match else "-"
        summary_table.append(f"| {img} | {mode} | [{artifact}]({f}/{artifact}) |")

for img in images:
    tag = f"{img}-{release_version}"
    try:
        note = subprocess.check_output([
            "gh", "release", "view", tag, "--json", "body", "--jq", ".body"
        ], text=True).strip()
    except subprocess.CalledProcessError:
        note = f"_No release notes found for {tag}_"
    # Extract What's Changed section
    match = re.search(r"(?s)(##? What's Changed.*?)(?:\n##|\Z)", note)
    if match:
        whats_changed_sections.add(match.group(1).strip())
    # Remove What's Changed from image details
    note_wo_wc = re.sub(r"(?s)##? What's Changed.*", "", note).strip()
    image_details.append(f"### {img}\n\n{note_wo_wc}\n")

# Combine What's Changed sections, deduplicated
whats_changed = '\n\n'.join(sorted(whats_changed_sections)) if whats_changed_sections else '_No changes found._'

# Read template
with open(TEMPLATE_PATH, 'r') as f:
    template = f.read()

# Replace placeholders
out = template.replace('{{RELEASE_VERSION}}', release_version)
out = out.replace('{{SUMMARY_TABLE}}', '\n'.join(summary_table))
out = out.replace('{{IMAGE_DETAILS}}', '\n'.join(image_details))
out = out.replace('{{WHATS_CHANGED}}', whats_changed)

with open(OUTPUT_PATH, 'w') as f:
    f.write(out)

print(f"Combined release notes written to {OUTPUT_PATH}")
