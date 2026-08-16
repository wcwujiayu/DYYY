#!/usr/bin/env bash

set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "${script_dir}/build-relevance.sh"

notes_file="${1:-release-notes.md}"
head_sha="${RELEASE_HEAD_SHA:-${GITHUB_SHA:-HEAD}}"
repository="${GITHUB_REPOSITORY:-$(git config --get remote.origin.url | sed -E 's#(git@github.com:|https://github.com/)##; s#\.git$##')}"
server_url="${GITHUB_SERVER_URL:-https://github.com}"
release_title="${RELEASE_TITLE:-Release}"

feat_file=$(mktemp)
fix_file=$(mktemp)
perf_file=$(mktemp)
refactor_file=$(mktemp)
docs_file=$(mktemp)
style_file=$(mktemp)
chore_file=$(mktemp)
revert_file=$(mktemp)
records_file=$(mktemp)
skip_file=$(mktemp)
contributors_file=$(mktemp)
groups_file=$(mktemp)
trap 'rm -f "$feat_file" "$fix_file" "$perf_file" "$refactor_file" "$docs_file" "$style_file" "$chore_file" "$revert_file" "$records_file" "$skip_file" "$contributors_file" "$groups_file"' EXIT

trim_text() {
    local value=$1

    printf '%s' "$value" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//'
}

strip_commit_type_prefix() {
    local subject=$1
    local commit_prefix_regex='^[A-Za-z]+(\([^)]+\))?(!)?[:：][[:space:]]*(.*)$'

    if [[ "$subject" =~ $commit_prefix_regex ]]; then
        subject=${BASH_REMATCH[3]}
    fi

    trim_text "$subject"
}

raw_commit_type() {
    local subject=$1
    local raw_type
    local commit_type_regex='^([A-Za-z]+)(\([^)]+\))?(!)?[:：]'

    if [[ "$subject" =~ $commit_type_regex ]]; then
        raw_type=${BASH_REMATCH[1]}
        printf '%s' "$raw_type" | tr '[:upper:]' '[:lower:]'
        return
    fi

    printf ''
}

canonical_commit_type() {
    local subject=$1
    local raw_type
    local content

    # 提交类型用于分组，但“回滚”是对发布净差异有决定性的语义：即使历史提交
    # 误写为 fix: 回滚…，也必须进入回滚处理，才能与同一发布范围内的原提交配对移除。
    content=$(strip_commit_type_prefix "$subject")
    case "$content" in
        Revert\ *|revert:*|revert：*|回滚*|撤销*)
            printf 'revert'
            return
            ;;
    esac

    raw_type=$(raw_commit_type "$subject")
    case "$raw_type" in
        feat|feature|add)
            printf 'feat'
            return
            ;;
        fix|bug|bugfix)
            printf 'fix'
            return
            ;;
        perf|performance)
            printf 'perf'
            return
            ;;
        refactor)
            printf 'refactor'
            return
            ;;
        docs|doc)
            printf 'docs'
            return
            ;;
        style|format)
            printf 'style'
            return
            ;;
        chore|build|ci|test|merge)
            printf 'chore'
            return
            ;;
        revert)
            printf 'revert'
            return
            ;;
    esac

    case "$subject" in
        Revert\ *|revert:*|revert：*|回滚*|撤销*)
            printf 'revert'
            ;;
        新增*|增加*|添加*|支持*|引入*|实现*)
            printf 'feat'
            ;;
        修复*|解决*|恢复*|纠正*|*修复*)
            printf 'fix'
            ;;
        性能*|提速*|加速*|*性能*优化*|*速度*优化*|*加载*优化*)
            printf 'perf'
            ;;
        重构*|简化*|清理*|整理*|调整*|优化*|完善*)
            printf 'refactor'
            ;;
        文档*|README*|readme*|注释*|更新版本号*|版本更新*)
            printf 'docs'
            ;;
        格式*|格式化*)
            printf 'style'
            ;;
        *)
            printf 'chore'
            ;;
    esac
}

version_summary_for_commit() {
    local hash=$1
    local previous_version
    local current_version

    previous_version=$(
        git show "${hash}^:control" 2>/dev/null |
            awk -F': ' '$1 == "Version" { print $2; exit }' || true
    )
    current_version=$(
        git show "${hash}:control" 2>/dev/null |
            awk -F': ' '$1 == "Version" { print $2; exit }' || true
    )

    if [[ -n "$current_version" && "$previous_version" != "$current_version" ]]; then
        if [[ -n "$previous_version" ]]; then
            printf '更新版本号：`%s` → `%s`' "$previous_version" "$current_version"
        else
            printf '设置版本号为 `%s`' "$current_version"
        fi
    fi
}

keyword_content_for_subject() {
    local subject=$1
    local commit_type=$2

    case "$subject" in
        *清屏隐藏清屏按钮*)
            printf '清屏按钮隐藏选项'
            ;;
        *清屏隐藏暂停图标*|*暂停图标*)
            if [[ "$commit_type" == "feat" ]]; then
                printf '清屏暂停图标隐藏选项'
            else
                printf '清屏暂停图标显示状态'
            fi
            ;;
        *暂停按钮*)
            if [[ "$commit_type" == "feat" ]]; then
                printf '清屏暂停按钮隐藏选项'
            else
                printf '清屏暂停按钮显示状态'
            fi
            ;;
        *贴边效果*)
            printf '隐藏按钮贴边效果'
            ;;
        *倍速按钮*不显示*|*倍速按钮可能不显示*)
            printf '倍速按钮显示状态'
            ;;
        *倍数悬浮按钮*数字*|*倍速悬浮按钮*数字*)
            printf '倍速悬浮按钮数字恢复状态'
            ;;
        *系统状态栏*|*隐藏状态栏*|*隐藏系统状态栏*)
            if [[ "$commit_type" == "feat" ]]; then
                printf '清屏状态栏隐藏功能'
            else
                printf '清屏状态栏隐藏状态'
            fi
            ;;
        *右侧图标*|*收藏*)
            printf '清屏恢复后的右侧图标显示'
            ;;
        *头像下加号*)
            printf '头像加号替代入口隐藏逻辑'
            ;;
        *圆形底板*)
            printf '头像入口圆形底板隐藏'
            ;;
        *打印所有视图*|*视图的接口*)
            printf '视图调试接口'
            ;;
        *Release*|*release*)
            printf 'Release 更新日志'
            ;;
        *dylib*|*Dylib*)
            printf 'dylib 发布产物'
            ;;
        *Deb*|*deb*)
            printf 'Deb 构建产物'
            ;;
    esac
}

feature_group_for_subject() {
    local subject=$1

    case "$subject" in
        *评论额外标签隐藏*|*合集与短剧入口隐藏*|*收敛评论与合集隐藏*|*搜索键盘语音入口隐藏*)
            printf '页面入口隐藏 Runtime Hook'
            ;;
        *快捷倍速*|*倍速侧边*|*倍速锁定*|*倍速长按*|*倍速设置*|*倍速悬浮*|*倍速按钮*)
            printf '快捷倍速'
            ;;
        *隐藏头像及周边*|*头像加号*|*圆形底板*)
            printf '隐藏头像及周边'
            ;;
        *推荐音乐过滤*|*推荐低赞过滤*|*搜索视频广告*|*推荐特效*|*合集*广告*)
            printf '推荐流过滤'
            ;;
    esac
}

summarize_commit_title() {
    local hash=$1
    local subject=$2
    local commit_type=$3
    local content
    local version_summary
    local revert_regex='^Revert[[:space:]]+"(.*)"$'
    local keyword_content

    if commit_touches_control "$hash"; then
        version_summary=$(version_summary_for_commit "$hash")
        if [[ -n "$version_summary" ]]; then
            printf '%s' "$version_summary"
            return
        fi
    fi

    if commit_touches_path "$hash" "Makefile" &&
       ! commit_touches_direct_build_path "$hash"; then
        printf '调整 Deb 构建配置'
        return
    fi

    content=$(strip_commit_type_prefix "$subject")
    content=$(printf '%s' "$content" | sed -E 's/[[:space:]。；;，,]+$//')

    if [[ "$commit_type" == "revert" && "$content" =~ $revert_regex ]]; then
        content=$(strip_commit_type_prefix "${BASH_REMATCH[1]}")
    fi

    keyword_content=$(keyword_content_for_subject "$subject" "$commit_type")
    if [[ -n "$keyword_content" ]]; then
        content=$keyword_content
    fi

    case "$commit_type" in
        feat)
            content=$(printf '%s' "$content" | sed -E 's/^(新增|增加|添加|支持|引入|实现|优化)[[:space:]:：]*//')
            content=$(trim_text "$content")
            printf '%s' "${content:-插件功能}"
            ;;
        fix)
            content=$(printf '%s' "$content" | sed -E 's/^(兜底修复|修复|解决|恢复|纠正|修正|修改|调整|优化|完善)[[:space:]:：]*//; s/的问题$//')
            content=$(printf '%s' "$content" | sed -E 's/不生效/生效异常/g; s/失效/异常/g; s/无法/不能/g')
            content=$(trim_text "$content")
            printf '%s' "${content:-已知问题}"
            ;;
        perf)
            content=$(printf '%s' "$content" | sed -E 's/^(性能优化|优化|提升|改善|提速|加速)[[:space:]:：]*//')
            content=$(trim_text "$content")
            printf '%s' "${content:-运行性能}"
            ;;
        refactor)
            content=$(printf '%s' "$content" | sed -E 's/^(重构|简化|清理|整理|调整|优化|完善)[[:space:]:：]*//')
            content=$(printf '%s' "$content" | sed -E 's/^将[[:space:]]*//')
            content=$(trim_text "$content")
            printf '%s' "${content:-代码结构}"
            ;;
        docs)
            content=$(printf '%s' "$content" | sed -E 's/^(文档|更新|修改|补充)[[:space:]:：]*//')
            content=$(trim_text "$content")
            printf '更新%s' "${content:-文档说明}"
            ;;
        style)
            content=$(printf '%s' "$content" | sed -E 's/^(格式化|格式|规范|调整)[[:space:]:：]*//')
            content=$(trim_text "$content")
            printf '规范%s' "${content:-代码格式}"
            ;;
        revert)
            content=$(printf '%s' "$content" | sed -E 's/^(回滚|撤销|取消)[[:space:]:：]*//')
            content=$(trim_text "$content")
            printf '%s' "${content:-上一项变更}"
            ;;
        *)
            content=$(printf '%s' "$content" | sed -E 's/^(杂项|其他|更新|调整|同步)[[:space:]:：]*//')
            content=$(trim_text "$content")
            printf '%s' "${content:-构建与维护项}"
            ;;
    esac
}

polish_release_title() {
    local subject=$1
    local commit_type=$2
    local summary_title=$3
    local content
    local target

    content=$(strip_commit_type_prefix "$subject")

    case "$commit_type" in
        feat)
            if [[ "$content" == 优化* && "$summary_title" != *改进 ]]; then
                summary_title+="改进"
            fi
            if [[ "$summary_title" == 隐藏*入口 ]]; then
                target=${summary_title#隐藏}
                target=${target%入口}
                summary_title="${target}隐藏支持"
            fi
            summary_title=$(printf '%s' "$summary_title" |
                sed -E 's/^消息页与我的页三项隐藏开关$/消息页与我的页新增三项隐藏选项/')
            ;;
        fix)
            if [[ "$content" == 优化* && "$summary_title" != *改进 ]]; then
                summary_title+="体验改进"
            elif [[ "$summary_title" == 适配* ]]; then
                summary_title="${summary_title#适配}适配"
            fi
            summary_title=$(printf '%s' "$summary_title" |
                sed -E 's/^图集与富内容倍速控制适配$/图集与富内容场景的倍速控制适配/; s/^快捷倍速交互与图集播放体验改进$/快捷倍速与图集播放体验改进/')
            ;;
        refactor)
            summary_title=$(printf '%s' "$summary_title" |
                sed -E 's/^迁移(.+)[[:space:]]+Runtime Hook$/\1改用 Runtime Hook/; s/^迁移(.+)[[:space:]]+Hook$/\1改用 Runtime Hook/; s/(.+)迁移为 Runtime Hook$/\1改用 Runtime Hook/; s/^收敛(.+)职责$/\1职责统一/; s/^手写源码按职责迁入 Sources 目录$/手写源码按职责归入 Sources 目录/')
            ;;
    esac

    summary_title=$(printf '%s' "$summary_title" |
        sed -E 's/^移除未使用的 Resources 图标资源$/移除未使用的图标资源/')

    printf '%s' "$summary_title"
}

normalize_group_text() {
    local value=$1

    value=$(strip_commit_type_prefix "$value")
    value=$(printf '%s' "$value" |
        sed -E 's/^(新增|增加|添加|支持|引入|实现|兜底修复|修复|解决|恢复|纠正|修改|调整|优化|完善|重构|简化|清理|整理|更新|规范|回滚|撤销|取消)[[:space:]:：]*//')
    value=$(printf '%s' "$value" |
        sed -E 's/(相关功能|相关问题|相关逻辑|相关配置|已知问题|的问题|问题|异常|失效|漏放|不能|闪退|逻辑|功能|选项|状态|改动|变更|同步|显示|隐藏|判定|配置|结构)$//')
    value=$(printf '%s' "$value" |
        tr -d '[:space:]' |
        sed -E 's/[[:punct:]，。；：“”"'\''（）()、]//g')

    printf '%s' "$value"
}

summary_group_key() {
    local hash=$1
    local subject=$2
    local commit_type=$3
    local summary_title=$4
    local feature_group
    local keyword_content
    local normalized

    if commit_touches_control "$hash"; then
        printf 'version:版本号'
        return
    fi

    if commit_touches_path "$hash" "Makefile" &&
       ! commit_touches_direct_build_path "$hash"; then
        printf 'build:Deb 构建配置'
        return
    fi

    feature_group=$(feature_group_for_subject "$subject")
    if [[ -n "$feature_group" ]]; then
        printf 'feature:%s' "$feature_group"
        return
    fi

    keyword_content=$(keyword_content_for_subject "$subject" "$commit_type")
    if [[ -n "$keyword_content" ]]; then
        printf 'keyword:%s' "$keyword_content"
        return
    fi

    normalized=$(normalize_group_text "$summary_title")
    if [[ -n "$normalized" ]]; then
        printf 'text:%s' "$normalized"
        return
    fi

    printf 'hash:%s' "$hash"
}

section_file_for_type() {
    case "$1" in
        feat) printf '%s' "$feat_file" ;;
        fix) printf '%s' "$fix_file" ;;
        perf) printf '%s' "$perf_file" ;;
        refactor) printf '%s' "$refactor_file" ;;
        docs) printf '%s' "$docs_file" ;;
        style) printf '%s' "$style_file" ;;
        revert) printf '%s' "$revert_file" ;;
        *) printf '%s' "$chore_file" ;;
    esac
}

reverted_commit_hash() {
    local hash=$1
    local body
    local target_hash
    local resolved_hash

    body=$(git show -s --format=%B "$hash")
    target_hash=$(printf '%s\n' "$body" |
        sed -nE 's/^This reverts commit ([0-9a-fA-F]{7,40})\.$/\1/p' |
        head -n 1)

    if [[ -z "$target_hash" ]]; then
        target_hash=$(printf '%s\n' "$body" |
            grep -Eoi '[0-9a-f]{7,40}' |
            head -n 1 || true)
    fi

    if [[ -z "$target_hash" ]]; then
        return
    fi

    resolved_hash=$(git rev-parse --verify "${target_hash}^{commit}" 2>/dev/null || true)
    printf '%s' "${resolved_hash:-$target_hash}"
}

record_hash_for() {
    local target_hash=$1

    awk -F $'\t' -v target="$target_hash" '
        $1 == target || index($1, target) == 1 || index(target, $1) == 1 {
            print $1
            exit
        }
    ' "$records_file"
}

reverted_subject_from_title() {
    local subject=$1
    local revert_regex='^Revert[[:space:]]+"(.*)"$'

    if [[ "$subject" =~ $revert_regex ]]; then
        printf '%s' "${BASH_REMATCH[1]}"
        return
    fi

    case "$subject" in
        回滚*|撤销*|取消*)
            printf '%s' "$subject" | sed -E 's/^(回滚|撤销|取消)[[:space:]:：]*//'
            ;;
    esac
}

normalize_revert_match_text() {
    local value=$1

    value=$(strip_commit_type_prefix "$value")
    value=$(printf '%s' "$value" |
        sed -E 's/^(新增|增加|添加|支持|引入|实现|修复|解决|恢复|纠正|修改|调整|优化|完善|重构|简化|清理|整理|将)[[:space:]:：]*//; s/(迁移为|迁移到|改为)[[:space:]]*//g')
    value=$(printf '%s' "$value" |
        sed -E 's/(的问题|问题|逻辑|优化|功能|选项|状态|改动|变更|同步|显示|隐藏|判定|异常|失效|不能|闪退)$//')
    value=$(printf '%s' "$value" |
        tr -d '[:space:]' |
        sed -E 's/[[:punct:]，。；：“”"'\''（）()、]//g')

    printf '%s' "$value"
}

revert_key_matches_candidate() {
    local target_key=$1
    local candidate_key=$2

    [[ -n "$target_key" && -n "$candidate_key" ]] || return 1

    if [[ "$target_key" == "$candidate_key" ]]; then
        return 0
    fi

    if (( ${#target_key} >= 6 && ${#candidate_key} >= 6 )); then
        [[ "$target_key" == *"$candidate_key"* || "$candidate_key" == *"$target_key"* ]]
        return
    fi

    return 1
}

mark_skip_pair() {
    local revert_hash=$1
    local target_hash=$2

    printf '%s\n%s\n' "$revert_hash" "$target_hash" >> "$skip_file"
}

detect_same_range_reverts() {
    local hash
    local subject
    local commit_type
    local target_hash
    local matched_hash
    local target_subject
    local target_key
    local candidate_hash
    local candidate_subject
    local candidate_type
    local candidate_key

    while IFS=$'\t' read -r hash subject commit_type; do
        [[ -n "$hash" ]] || continue
        [[ "$commit_type" == "revert" ]] || continue

        target_hash=$(reverted_commit_hash "$hash")
        matched_hash=""
        if [[ -n "$target_hash" ]]; then
            matched_hash=$(record_hash_for "$target_hash")
        fi
        if [[ -n "$matched_hash" ]]; then
            mark_skip_pair "$hash" "$matched_hash"
            continue
        fi

        target_subject=$(reverted_subject_from_title "$(strip_commit_type_prefix "$subject")")
        target_key=$(normalize_revert_match_text "$target_subject")
        if [[ -z "$target_key" || "${#target_key}" -lt 6 ]]; then
            continue
        fi

        while IFS=$'\t' read -r candidate_hash candidate_subject candidate_type; do
            [[ -n "$candidate_hash" ]] || continue
            [[ "$candidate_hash" == "$hash" ]] && continue
            git merge-base --is-ancestor "$candidate_hash" "$hash" 2>/dev/null || continue

            candidate_key=$(normalize_revert_match_text "$candidate_subject")
            if revert_key_matches_candidate "$target_key" "$candidate_key"; then
                mark_skip_pair "$hash" "$candidate_hash"
                break
            fi
        done < "$records_file"
    done < "$records_file"
}

commit_is_skipped() {
    local hash=$1

    awk -v target="$hash" '
        $1 == target || index($1, target) == 1 || index(target, $1) == 1 {
            found = 1
        }
        END {
            exit found ? 0 : 1
        }
    ' "$skip_file"
}

group_label() {
    local group_key=$1

    printf '%s' "${group_key#*:}"
}

aggregate_group_title() {
    local commit_type=$1
    local group_key=$2
    local titles_file=$3
    local title_count=$4
    local label

    if (( title_count <= 1 )); then
        head -n 1 "$titles_file"
        return
    fi

    label=$(group_label "$group_key")
    case "$label" in
        版本号)
            printf '更新版本号'
            return
            ;;
        Deb\ 构建配置)
            printf '调整 Deb 构建配置'
            return
            ;;
        页面入口隐藏\ Runtime\ Hook)
            printf '页面入口隐藏逻辑统一改用 Runtime Hook'
            return
            ;;
    esac

    case "$commit_type" in
        feat)
            printf '新增%s相关功能' "$label"
            ;;
        fix)
            printf '修正%s相关问题' "$label"
            ;;
        perf)
            printf '优化%s运行表现' "$label"
            ;;
        refactor)
            printf '整理%s相关逻辑' "$label"
            ;;
        docs)
            printf '更新%s相关说明' "$label"
            ;;
        style)
            printf '规范%s相关格式' "$label"
            ;;
        revert)
            printf '回滚%s相关变更' "$label"
            ;;
        *)
            printf '调整%s相关配置' "$label"
            ;;
    esac
}

aggregate_group_release_note() {
    local group_key=$1
    local title_count=$2

    if (( title_count <= 1 )); then
        return
    fi

    case "$group_key" in
        feature:页面入口隐藏\ Runtime\ Hook)
            printf '评论额外标签、合集与短剧入口、搜索键盘语音入口的隐藏逻辑已完成整合，相关 Hook 的职责边界进一步统一。'
            ;;
    esac
}

release_note_for_commit() {
    local hash=$1
    local commit_type=$2
    local allow_fallback=false

    case "$commit_type" in
        feat|fix|perf)
            allow_fallback=true
            ;;
    esac

    git show -s --format=%b "$hash" |
        awk -v allow_fallback="$allow_fallback" '
            function join_text(current, value, separator) {
                gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
                if (value == "") {
                    return current
                }
                separator = ""
                if (current != "" &&
                    current !~ /[，。；：！？、]$/ &&
                    value !~ /^[，。；：！？、]/) {
                    separator = " "
                }
                return current separator value
            }

            /^(Release-Note|发布说明):[[:space:]]*/ {
                capturing = 1
                value = $0
                sub(/^(Release-Note|发布说明):[[:space:]]*/, "", value)
                note = join_text(note, value)
                has_note = (note != "")
                next
            }

            capturing {
                if ($0 ~ /^[A-Za-z][A-Za-z0-9-]*:[[:space:]]*/ ||
                    $0 ~ /^发布说明:[[:space:]]*/) {
                    exit
                }
                if ($0 ~ /^[[:space:]]*$/) {
                    if (has_note) {
                        exit
                    }
                    next
                }
                note = join_text(note, $0)
                has_note = (note != "")
                next
            }

            allow_fallback == "true" && !fallback_done {
                if ($0 ~ /^[[:space:]]*$/) {
                    if (has_fallback) {
                        fallback_done = 1
                    }
                    next
                }
                if ($0 ~ /^[A-Za-z][A-Za-z0-9-]*:[[:space:]]*/ ||
                    $0 ~ /^This reverts commit [0-9a-fA-F]+\.$/) {
                    fallback_done = 1
                    next
                }
                fallback = join_text(fallback, $0)
                has_fallback = (fallback != "")
            }

            END {
                if (note != "" && note != "skip" && note != "none") {
                    print note
                } else if (allow_fallback == "true" && fallback != "") {
                    print fallback
                }
            }
        ' |
        sed -E 's/^为(.+)提供独立 Runtime Hook 与设置项，修复(.+)误挂 [^[:space:]]+ 导致无法隐藏的问题。$/新增\1的独立隐藏选项，并修复\2在部分场景无法隐藏的问题。/'
}

derived_release_note_for_commit() {
    local hash=$1
    local subject
    local content

    subject=$(git show -s --format=%s "$hash")
    content=$(strip_commit_type_prefix "$subject")

    # 优先从实际差异识别用户可感知的结果，不依赖某一条固定提交标题。
    if git show --format= --unified=0 "$hash" | grep -F 'AWEGeneralSearchAIBallButton' >/dev/null &&
       git show --format= --unified=0 "$hash" | grep -F 'AWEGeneralSearchAIModeButton' >/dev/null &&
       git show --format= --unified=0 "$hash" | grep -F 'DYYYHideKeyboardAI' >/dev/null; then
        printf '开启“隐藏键盘 AI”后，综合搜索结果页右下角的“继续追问”等 AI 浮钮也会一并隐藏，并避免入口先出现再消失。'
        return
    fi

    if git show --format= --unified=0 "$hash" | grep -F 'DYYYApplySpeedToVisibleAFDSlidesViews' >/dev/null &&
       git show --format= --unified=0 "$hash" | grep -F 'allowCachedController' >/dev/null &&
       git show --format= --unified=0 "$hash" | grep -F 'setAlbumFastPlay:useFastRate' >/dev/null; then
        printf '修复图文场景可能沿用上一个视频倍率状态的问题；切换倍率或恢复 1.0 倍速时，现在会正确作用于当前图文内容，并避免误触发长按快进转场。'
        return
    fi

    case "$content" in
        优化悬浮倍速与清屏按钮交互)
            if git show --format= --unified=0 "$hash" | grep -F 'DYYYAutoHideSpeedButtonTime' >/dev/null &&
               git show --format= --unified=0 "$hash" | grep -F 'DYYYClearButtonEdge' >/dev/null &&
               git show --format= --unified=0 "$hash" | grep -F 'DYYYSpeedButtonEdge' >/dev/null; then
                printf '悬浮倍速与清屏按钮现在支持沿屏幕四边拖动停靠并记忆位置；倍速按钮新增尺寸和自动隐藏时长设置，清屏切换后会按设置恢复显示状态。'
            fi
            ;;
        适配图集与富内容倍速控制)
            if git show --format= --unified=0 "$hash" | grep -F 'DYYYApplyImageAlbumPlaybackSpeed' >/dev/null &&
               git show --format= --unified=0 "$hash" | grep -F 'AFDSlidesView' >/dev/null; then
                printf '倍速控制扩展至图集与富内容场景，切换倍速时会同步更新图集播放计时与宿主速度状态。'
            fi
            ;;
        优化快捷倍速交互与图集播放)
            if git show --format= --unified=0 "$hash" | grep -F 'fast-play 状态会触发其长按快进转场' >/dev/null &&
               git show --format= --unified=0 "$hash" | grep -F 'dyyy_playTapFeedback' >/dev/null; then
                printf '调整倍速按钮的点击反馈，并避免图集单击切换倍速时误触发长按快进转场造成内容拉伸、停顿和回弹。'
            fi
            ;;
    esac
}

release_note_is_suppressed() {
    local hash=$1

    git show -s --format=%b "$hash" |
        awk '
            /^(Release-Note|发布说明):[[:space:]]*(skip|none)[[:space:]]*$/ {
                found = 1
                exit
            }
            END { exit found ? 0 : 1 }
        '
}

fallback_release_note_for_commit() {
    local hash=$1
    local commit_type=$2
    local summary_title=$3
    local subject
    local content
    local target

    subject=$(git show -s --format=%s "$hash")
    content=$(strip_commit_type_prefix "$subject")

    case "$commit_type" in
        feat)
            case "$content" in
                隐藏*)
                    target=${content#隐藏}
                    printf '开启对应隐藏选项后，%s将不再显示。' "$target"
                    ;;
                新增*|增加*|添加*|支持*|引入*|实现*)
                    target=$(printf '%s' "$content" |
                        sed -E 's/^(新增|增加|添加|支持|引入|实现)[[:space:]:：]*//')
                    printf '现在可以使用%s。' "${target:-$summary_title}"
                    ;;
                *)
                    printf '新增“%s”相关能力，可在对应使用场景中直接体验。' "$summary_title"
                    ;;
            esac
            ;;
        fix)
            case "$content" in
                修正*状态|修复*状态)
                    target=$(printf '%s' "$content" |
                        sed -E 's/^(修正|修复)[[:space:]:：]*//; s/状态$//')
                    printf '修复%s状态未按预期更新的问题，相关操作现在会正确作用于当前内容。' "${target:-$summary_title}"
                    ;;
                *)
                    printf '修复“%s”相关异常，受影响的操作现在会按预期工作。' "$summary_title"
                    ;;
            esac
            ;;
        perf)
            printf '优化“%s”的使用表现，相关操作现在更加流畅稳定。' "$summary_title"
            ;;
    esac
}

warn_release_note_fallback() {
    local hash=$1
    local subject=$2
    local short_hash=${hash:0:8}
    local message="${short_hash} ${subject} 未提供 Release-Note，已使用通用用户说明；建议在重要提交正文中补充 Release-Note:。"

    if [[ "${GITHUB_ACTIONS:-}" == "true" ]]; then
        printf '::warning title=Release note fallback::%s\n' "$message" >&2
    else
        printf 'warning: %s\n' "$message" >&2
    fi
}

append_grouped_entries_for_type() {
    local commit_type=$1
    local section_file=$2
    local group_key
    local title
    local hash
    local short_hash
    local title_count
    local hash_links
    local summary_title
    local titles_file
    local notes_file
    local release_note
    local group_release_note

    while IFS= read -r group_key; do
        [[ -n "$group_key" ]] || continue

        titles_file=$(mktemp)
        notes_file=$(mktemp)
        hash_links=""
        while IFS=$'\t' read -r title hash; do
            [[ -n "$hash" ]] || continue
            if ! grep -Fxq "$title" "$titles_file"; then
                printf '%s\n' "$title" >> "$titles_file"
            fi

            short_hash=${hash:0:8}
            if [[ -n "$hash_links" ]]; then
                hash_links+=", "
            fi
            hash_links+="[\`${short_hash}\`](${server_url}/${repository}/commit/${hash})"

            release_note=$(release_note_for_commit "$hash" "$commit_type")
            if [[ -z "$release_note" ]] && ! release_note_is_suppressed "$hash"; then
                release_note=$(derived_release_note_for_commit "$hash")
            fi
            if [[ -z "$release_note" ]] && ! release_note_is_suppressed "$hash"; then
                release_note=$(fallback_release_note_for_commit "$hash" "$commit_type" "$title")
                if [[ -n "$release_note" ]]; then
                    warn_release_note_fallback "$hash" "$(git show -s --format=%s "$hash")"
                fi
            fi
            if [[ -n "$release_note" ]] &&
               ! grep -Fxq "$release_note" "$notes_file"; then
                printf '%s\n' "$release_note" >> "$notes_file"
            fi
        done < <(
            awk -F $'\t' -v type="$commit_type" -v key="$group_key" '
                $1 == type && $2 == key { print $3 "\t" $4 }
            ' "$groups_file"
        )

        title_count=$(awk 'NF { count++ } END { print count + 0 }' "$titles_file")
        summary_title=$(aggregate_group_title "$commit_type" "$group_key" "$titles_file" "$title_count")
        group_release_note=$(aggregate_group_release_note "$group_key" "$title_count")
        if [[ -n "$group_release_note" ]] &&
           ! grep -Fxq "$group_release_note" "$notes_file"; then
            printf '%s\n' "$group_release_note" >> "$notes_file"
        fi
        rm -f "$titles_file"

        if [[ -n "$summary_title" && -n "$hash_links" ]]; then
            # 类型已由 Release 分区表达，条目只保留用户能理解的变更主题；提交链接
            # 作为可追溯证据，而非把 feat/fix/refactor 这类开发语法暴露给用户。
            printf -- '- **%s**（%s）\n' "$summary_title" "$hash_links" >> "$section_file"
            while IFS= read -r release_note; do
                [[ -n "$release_note" ]] || continue
                printf '\n  %s\n' "$release_note" >> "$section_file"
            done < "$notes_file"
            printf '\n' >> "$section_file"
        fi
        rm -f "$notes_file"
    done < <(
        awk -F $'\t' -v type="$commit_type" '
            $1 == type && !seen[$2]++ { print $2 }
        ' "$groups_file"
    )
}

commit_touches_control() {
    local hash=$1

    commit_touches_path "$hash" "control"
}

latest_release_tag() {
    local latest_tag

    if ! command -v gh >/dev/null 2>&1 ||
       [[ -z "$repository" ]]; then
        return
    fi

    # GitHub 公共仓库允许无 token 查询 Release。不能因为本地未注入 GH_TOKEN
    # 就直接退回可能过期的本地 tag，否则本地预览会把已发布提交重新列入下一版。
    latest_tag=$(gh api "repos/${repository}/releases/latest" \
        --jq '.tag_name // empty' 2>/dev/null || true)
    printf '%s' "$latest_tag"
}

tag_points_to_commit() {
    local tag=$1

    git cat-file -e "${tag}^{commit}" 2>/dev/null
}

ensure_release_tag_available() {
    local tag=$1

    if tag_points_to_commit "$tag"; then
        return 0
    fi

    git fetch --force --no-tags origin "refs/tags/${tag}:refs/tags/${tag}" \
        >/dev/null 2>&1 || return 1
    tag_points_to_commit "$tag"
}

contributor_for_commit() {
    local hash=$1
    local author_email
    local github_login
    local noreply_with_id='^[0-9]+\+([^@]+)@users\.noreply\.github\.com$'
    local noreply_plain='^([^@]+)@users\.noreply\.github\.com$'

    if command -v gh >/dev/null 2>&1 &&
       [[ -n "${GH_TOKEN:-}" && -n "$repository" ]]; then
        github_login=$(gh api "repos/${repository}/commits/${hash}" \
            --jq '.author.login // .committer.login // empty' 2>/dev/null || true)
        if [[ -n "$github_login" ]]; then
            printf '@%s' "$github_login"
            return
        fi
    fi

    author_email=$(git show -s --format=%ae "$hash")

    if [[ "$author_email" =~ $noreply_with_id ]]; then
        printf '@%s' "${BASH_REMATCH[1]}"
        return
    fi
    if [[ "$author_email" =~ $noreply_plain ]]; then
        printf '@%s' "${BASH_REMATCH[1]}"
        return
    fi
}

record_contributor_for_commit() {
    local hash=$1
    local contributor

    contributor=$(contributor_for_commit "$hash")
    if [[ -n "$contributor" ]] &&
       ! grep -Fxq -- "$contributor" "$contributors_file"; then
        printf '%s\n' "$contributor" >> "$contributors_file"
    fi
}

previous_tag=${RELEASE_PREVIOUS_TAG:-$(latest_release_tag)}
if [[ -n "$previous_tag" ]] &&
   ! ensure_release_tag_available "$previous_tag"; then
    previous_tag=""
fi

if [[ -z "$previous_tag" ]]; then
    previous_tag=$(git tag --list 'DYYY_*' --sort=-version:refname | head -n 1)
fi

if [[ -n "$previous_tag" ]] &&
   ! tag_points_to_commit "$previous_tag"; then
    previous_tag=""
fi

if [[ -n "$previous_tag" ]]; then
    commit_range="${previous_tag}..${head_sha}"
elif [[ -n "${PUSH_BEFORE:-}" && "$PUSH_BEFORE" != "$zero_sha" ]] &&
     git cat-file -e "${PUSH_BEFORE}^{commit}" 2>/dev/null; then
    commit_range="${PUSH_BEFORE}..${head_sha}"
else
    if git rev-parse "${head_sha}^" >/dev/null 2>&1; then
        commit_range="${head_sha}^..${head_sha}"
    else
        commit_range="$head_sha"
    fi
fi

while IFS=$'\t' read -r hash subject; do
    [[ -n "$hash" ]] || continue

    parent_count=$(git rev-list --parents -n 1 "$hash" | awk '{ print NF - 1 }')
    if (( parent_count > 1 )) || ! commit_affects_build "$hash"; then
        continue
    fi

    commit_type=$(canonical_commit_type "$subject")
    printf '%s\t%s\t%s\n' "$hash" "$subject" "$commit_type" >> "$records_file"
done < <(git log --reverse --format=$'%H\t%s' "$commit_range")

detect_same_range_reverts

relevant_count=0

while IFS=$'\t' read -r hash subject commit_type; do
    [[ -n "$hash" ]] || continue
    if commit_is_skipped "$hash"; then
        continue
    fi

    relevant_count=$((relevant_count + 1))
    summary_title=$(summarize_commit_title "$hash" "$subject" "$commit_type")
    summary_title=$(polish_release_title "$subject" "$commit_type" "$summary_title")
    group_key=$(summary_group_key "$hash" "$subject" "$commit_type" "$summary_title")
    summary_title=$(printf '%s' "$summary_title" | tr '\t' ' ')
    printf '%s\t%s\t%s\t%s\n' "$commit_type" "$group_key" "$summary_title" "$hash" >> "$groups_file"
    record_contributor_for_commit "$hash"
done < "$records_file"

append_grouped_entries_for_type "feat" "$feat_file"
append_grouped_entries_for_type "fix" "$fix_file"
append_grouped_entries_for_type "perf" "$perf_file"
append_grouped_entries_for_type "refactor" "$refactor_file"
append_grouped_entries_for_type "docs" "$docs_file"
append_grouped_entries_for_type "style" "$style_file"
append_grouped_entries_for_type "chore" "$chore_file"
append_grouped_entries_for_type "revert" "$revert_file"

cat > "$notes_file" <<EOF
## ${release_title} 更新日志
EOF

append_section() {
    local title=$1
    local section_file=$2

    if [[ -s "$section_file" ]]; then
        printf '\n### %s\n\n' "$title" >> "$notes_file"
        cat "$section_file" >> "$notes_file"
    fi
}

append_files_as_section() {
    local title=$1
    shift
    local section_file
    local has_entries=false

    for section_file in "$@"; do
        [[ -s "$section_file" ]] || continue
        if [[ "$has_entries" == "false" ]]; then
            if [[ "$release_section_written" == "true" ]]; then
                printf '%s\n' '---' >> "$notes_file"
            fi
            printf '\n### %s\n\n' "$title" >> "$notes_file"
            has_entries=true
            release_section_written=true
        fi
        cat "$section_file" >> "$notes_file"
    done
}

# 沿用用户指定的发布日志结构；PR 引用在 DYYY 中由对应 commit 链接替代。
release_section_written=false
append_files_as_section "新功能与体验改进" "$feat_file" "$perf_file"
append_files_as_section "Bug 修复" "$fix_file"
append_files_as_section "维护与发布流程" "$refactor_file" "$docs_file" "$style_file" "$chore_file"
append_files_as_section "变更回滚" "$revert_file"

contributor_count=$(awk 'NF { count++ } END { print count + 0 }' "$contributors_file")
if (( contributor_count >= 2 )); then
    printf '\n## Contributors\n\n' >> "$notes_file"
    first_contributor=true
    while IFS= read -r contributor; do
        [[ -n "$contributor" ]] || continue
        if [[ "$first_contributor" == "true" ]]; then
            first_contributor=false
        else
            printf ', ' >> "$notes_file"
        fi
        printf '%s' "$contributor" >> "$notes_file"
    done < "$contributors_file"
    printf '\n' >> "$notes_file"
fi

cat "$notes_file"
