#!/usr/bin/env bash

set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(git -C "$script_dir" rev-parse --show-toplevel)
notes_file=$(mktemp)
stderr_file=$(mktemp)
trap 'rm -f "$notes_file" "$stderr_file"' EXIT

cd "$repo_root"

assert_build_relevant() {
    local hash=$1

    if ! .github/scripts/build-relevance.sh commit "$hash"; then
        printf 'expected %s to affect the build\n' "$hash" >&2
        exit 1
    fi
}

assert_not_build_relevant() {
    local hash=$1

    if .github/scripts/build-relevance.sh commit "$hash"; then
        printf 'expected %s not to affect the build\n' "$hash" >&2
        exit 1
    fi
}

assert_contains() {
    local expected=$1

    if ! grep -Fq -- "$expected" "$notes_file"; then
        printf 'release notes missing expected text: %s\n' "$expected" >&2
        sed -n '1,240p' "$notes_file" >&2
        exit 1
    fi
}

find_commit_touching() {
    local pattern=$1
    shift

    git log -n 1 HEAD -G "$pattern" --format='%H' -- "$@"
}

# Sources/<Domain> 是 DYYY 的真实构建输入；发布脚本自身不应触发业务 Release。
hide_ai_commit=$(find_commit_touching 'AWEGeneralSearchAIBallButton' DYYY.xm Sources)
image_speed_commit=$(find_commit_touching 'DYYYApplySpeedToVisibleAFDSlidesViews' DYYY.xm)
release_automation_commit=$(git log -n 1 HEAD --format='%H' --grep='发布日志生成')

if [[ -z "$hide_ai_commit" || -z "$image_speed_commit" || -z "$release_automation_commit" ]]; then
    printf 'unable to locate release-note regression fixtures in Git history\n' >&2
    exit 1
fi

assert_build_relevant "$hide_ai_commit"
assert_build_relevant "$image_speed_commit"
assert_not_build_relevant "$release_automation_commit"

RELEASE_PREVIOUS_TAG="${hide_ai_commit}^" \
RELEASE_HEAD_SHA="$image_speed_commit" \
RELEASE_TITLE='DYYY_2.3-0#19' \
    .github/scripts/generate-release-notes.sh "$notes_file" 2>"$stderr_file" >/dev/null

assert_contains '### 新功能与体验改进'
assert_contains '综合搜索 AI 浮钮'
assert_contains "${hide_ai_commit:0:8}"
assert_contains '开启“隐藏键盘 AI”后，综合搜索结果页右下角的“继续追问”等 AI 浮钮也会一并隐藏，并避免入口先出现再消失。'
assert_contains '### Bug 修复'
assert_contains '图文播放倍率状态'
assert_contains "${image_speed_commit:0:8}"
assert_contains '修复图文场景可能沿用上一个视频倍率状态的问题；切换倍率或恢复 1.0 倍速时，现在会正确作用于当前图文内容，并避免误触发长按快进转场。'

if grep -Eq 'Release note fallback|^warning:' "$stderr_file"; then
    printf 'evidence-backed #19 notes unexpectedly used the generic fallback\n' >&2
    cat "$stderr_file" >&2
    exit 1
fi

# 没有显式正文且没有专用差异证据时，用户可见的 feat/fix/perf 仍需得到
# 一句可读说明，同时在 CI 中提示维护者补充更精确的 Release-Note。
generic_commit=$(git log -n 1 HEAD --format='%H' --fixed-strings --grep='feat: 新增主页关注确认弹窗与提示优化')
if [[ -z "$generic_commit" ]]; then
    printf 'unable to locate generic release-note fallback fixture in current HEAD history\n' >&2
    exit 1
fi
generic_parent=$(git rev-parse "${generic_commit}^")
RELEASE_PREVIOUS_TAG="$generic_parent" \
RELEASE_HEAD_SHA="$generic_commit" \
RELEASE_TITLE='fallback-test' \
GITHUB_ACTIONS=true \
    .github/scripts/generate-release-notes.sh "$notes_file" 2>"$stderr_file" >/dev/null

assert_contains '主页关注确认弹窗与提示优化'
assert_contains '现在可以使用主页关注确认弹窗与提示优化。'
if ! grep -Fq '::warning title=Release note fallback::' "$stderr_file"; then
    printf 'generic release-note fallback did not emit a GitHub Actions warning\n' >&2
    cat "$stderr_file" >&2
    exit 1
fi

printf 'release-note regression tests passed\n'
