#!/usr/bin/env bash
# Portable PT-v4 checks using production Foundation code and repository XCTest cases.
# Requires Swift 6 and Python 3. This does not build or launch the macOS app.
set -euo pipefail

ptv4_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ptv4_temp="$(mktemp -d "${TMPDIR:-/tmp}/ptv4-training.XXXXXX")"
trap 'rm -rf "$ptv4_temp"' EXIT

python3 - "$ptv4_root" "$ptv4_temp" <<'PY'
from pathlib import Path
import re
import sys

root, temporary = map(Path, sys.argv[1:])
core = root / "Sources/PokeTaskBar/Core"


def declaration(filename, name):
    """Copy an unchanged top-level pure declaration, with no replacement logic."""
    source = (core / filename).read_text()
    match = re.search(rf"^(?:enum|struct) {re.escape(name)}\b[^\n]*", source, re.MULTILINE)
    if not match:
        raise SystemExit(f"Missing production declaration: {filename}:{name}")
    if "}" in match.group():
        return match.group() + "\n"
    closing = re.search(r"^}\s*$", source[match.end():], re.MULTILINE)
    if not closing:
        raise SystemExit(f"Missing declaration boundary: {filename}:{name}")
    return source[match.start():match.end() + closing.end()] + "\n"


# The enclosing files also contain network/timer actors. Copy only these exact
# production declarations needed by the unchanged model and save-transfer files.
fragments = ["import Foundation\n"]
for filename, names in [
    ("PokeAPIClient.swift", ["NameDTO", "NamedRef"]),
    ("PokemonNameLocalization.swift", ["PokemonNameLocalization"]),
    ("LinearClient.swift", ["LinearCompletedIssue", "LinearCompletedProject",
                            "LinearIssueXPRecord", "LinearRewards"]),
]:
    fragments.extend(declaration(filename, name) for name in names)

potion = (core / "FocusPotion.swift").read_text()
kinds = re.search(r"^    static let kinds: \[ItemKind\] = .*$", potion, re.MULTILINE)
if not kinds:
    raise SystemExit("Missing production FocusPotion.kinds declaration")
fragments.append("enum FocusPotion {\n" + kinds.group() + "\n}\n")
(temporary / "ProductionFragments.swift").write_text("\n".join(fragments))

cases = []
for filename in ["RepeatCatchTrainingTests.swift", "RepeatCatchPersistenceTests.swift", "PokedexRegistryTests.swift"]:
    source = (root / "Tests/PokeTaskBarTests" / filename).read_text()
    source = re.sub(r"^@testable import PokeTaskBar\s*\n", "", source, flags=re.MULTILINE)
    classes = re.findall(r"^final class (\w+): XCTestCase \{", source, re.MULTILINE)
    if len(classes) != 1:
        raise SystemExit(f"Expected one XCTestCase class in {filename}")
    methods = re.findall(r"^    func (test\w+)\(\)(?: throws)? \{", source, re.MULTILINE)
    declared = re.findall(r"^    func (test\w+)\(", source, re.MULTILINE)
    if not methods or methods != declared:
        raise SystemExit(f"Unsupported test signature in {filename}; update the manifest generator")
    (temporary / filename).write_text(source)
    classname = classes[0]
    entries = ",\n".join(f'        ("{method}", {classname}.{method})' for method in methods)
    cases.append("    testCase([\n" + entries + "\n    ])")
    print(f"{classname}: {len(methods)} production test methods")

(temporary / "main.swift").write_text("import XCTest\n\nXCTMain([\n" + ",\n".join(cases) + "\n])\n")
PY

ptv4_production_sources=(
    "$ptv4_root/Sources/PokeTaskBar/Core/RepeatCatchTraining.swift"
    "$ptv4_root/Sources/PokeTaskBar/Core/CompanionModel.swift"
    "$ptv4_root/Sources/PokeTaskBar/Core/PokemonProfile.swift"
    "$ptv4_root/Sources/PokeTaskBar/Core/SaveTransfer.swift"
    "$ptv4_root/Sources/PokeTaskBar/Core/UnownForm.swift"
    "$ptv4_root/Sources/PokeTaskBar/Core/CollectionWeight.swift"
    "$ptv4_root/Sources/PokeTaskBar/Core/EconomyScale.swift"
    "$ptv4_root/Sources/PokeTaskBar/Core/PokedexRegistry.swift"
    "$ptv4_temp/ProductionFragments.swift"
)

swiftc -swift-version 6 -typecheck "${ptv4_production_sources[@]}"
echo "Production Foundation sources: Swift 6 typecheck passed"

# Linux XCTest's manual manifest captures non-Sendable XCTestCase instances.
# Compile that harness in Swift 5 mode, after checking production in Swift 6.
swiftc -swift-version 5 "${ptv4_production_sources[@]}" \
    "$ptv4_temp/RepeatCatchTrainingTests.swift" \
    "$ptv4_temp/RepeatCatchPersistenceTests.swift" \
    "$ptv4_temp/PokedexRegistryTests.swift" \
    "$ptv4_temp/main.swift" \
    -o "$ptv4_temp/check-training"

"$ptv4_temp/check-training"
