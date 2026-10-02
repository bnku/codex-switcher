#!/usr/bin/env bash
set -euo pipefail

# Self-copy to /tmp and re-exec to ensure script survives git branch switching
if [ "${REBUILD_ENHANCED_STAGE:-0}" != "1" ]; then
    TMP_SCRIPT="$(mktemp /tmp/rebuild-enhanced.XXXXXX.sh)"
    cp "${BASH_SOURCE[0]}" "$TMP_SCRIPT"
    chmod +x "$TMP_SCRIPT"
    trap 'rm -f "$TMP_SCRIPT"' EXIT
    export REBUILD_ENHANCED_STAGE=1
    exec "$TMP_SCRIPT" "$@"
fi

ROOT_DIR="$(git rev-parse --show-toplevel)"
cd "$ROOT_DIR"

echo "=================================================="
echo "  Codex Switcher: Rebuilding Enhanced Branch"
echo "=================================================="

# 1. Ensure working directory is clean
if [ -n "$(git status --porcelain)" ]; then
    echo "Error: Working directory has uncommitted changes. Please commit or stash them first." >&2
    git status -s
    exit 1
fi

INITIAL_BRANCH="$(git branch --show-current)"
echo "Starting from branch: $INITIAL_BRANCH"

# 2. Fetch latest changes from remotes
echo "--> Fetching upstream and origin..."
git fetch upstream main
git fetch origin

# 3. Reset enhanced branch directly from pristine upstream/main
echo "--> Resetting 'enhanced' to upstream/main..."
git checkout -B enhanced upstream/main

# 4. List of active feature / bugfix branches to merge into enhanced
FEATURE_BRANCHES=(
    "feature/auto-session-recovery"
    "fork/enhanced-infra"
)

for branch in "${FEATURE_BRANCHES[@]}"; do
    echo "--> Merging branch '$branch' into enhanced..."
    MERGE_TARGET="$branch"
    if git rev-parse --verify "origin/$branch" >/dev/null 2>&1; then
        MERGE_TARGET="origin/$branch"
    fi

    if ! git merge "$MERGE_TARGET" -m "merge: $branch into enhanced"; then
        echo "Merge conflict detected while merging $branch!"
        # Check if only known trivial conflict in App.tsx imports exists
        if git status -s | grep -q "UU src/App.tsx"; then
            echo "--> Resolving import conflict in src/App.tsx..."
            node -e '
                const fs = require("fs");
                let content = fs.readFileSync("src/App.tsx", "utf8");
                content = content.replace(/<<<<<<< HEAD[\s\S]*?=======[\s\S]*?>>>>>>>[^\n]*/g, (match) => {
                    if (match.includes("WindowResizeBorders") || match.includes("AppSettings")) {
                        return "import { AccountCard, AddAccountModal, UpdateChecker, WindowResizeBorders } from \"./components\";\nimport type { AccountWithUsage, AppSettings, CodexProcessInfo, DockDisplayMode, UsageInfo } from \"./types\";";
                    }
                    return match;
                });
                fs.writeFileSync("src/App.tsx", content);
            '
            git add src/App.tsx
            git commit -m "merge: $branch into enhanced (resolved conflicts)"
            echo "--> Conflict resolved successfully."
        else
            echo "Error: Unresolved merge conflict. Please resolve manually and re-run." >&2
            exit 1
        fi
    fi
done

# 5. Build and test validation
echo "--> Validating frontend build..."
pnpm build

echo "--> Running Rust test suite..."
cargo test --manifest-path src-tauri/Cargo.toml

# 6. Push updated enhanced branch to origin
echo "--> Pushing updated 'enhanced' to origin..."
git push origin enhanced --force-with-lease

# 7. Compile local daily-driver release binary
echo "--> Compiling local release binary (with embedded frontend assets)..."
pnpm tauri build --no-bundle

RELEASE_BIN="$ROOT_DIR/src-tauri/target/release/codex-switcher"
if [ -f "$RELEASE_BIN" ]; then
    echo "--> Installing binary to ~/.local/bin/codex-switcher..."
    mkdir -p "$HOME/.local/bin"
    cp "$RELEASE_BIN" "$HOME/.local/bin/codex-switcher"
    chmod +x "$HOME/.local/bin/codex-switcher"

    # Also keep a copy in repo root for convenience
    cp "$RELEASE_BIN" "$ROOT_DIR/codex-switcher"
    chmod +x "$ROOT_DIR/codex-switcher"
fi

echo "=================================================="
echo "  Enhanced Rebuild Finished Successfully!"
echo "  Installed to: ~/.local/bin/codex-switcher"
echo "  Repo binary:  $ROOT_DIR/codex-switcher"
echo "=================================================="
