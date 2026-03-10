#!/usr/bin/env bash
# ai-backends CLI wrapper with tab completion.
#
# Run directly:          ./run.sh -p "Describe this" photo.jpg
# Register completion:   source ./run.sh  (or add to ~/.bashrc)

# ── Bash tab completion ────────────────────────────────────────────────────────
_ai_backends_complete() {
    local cur="${COMP_WORDS[COMP_CWORD]}"
    local prev="${COMP_WORDS[COMP_CWORD-1]}"

    case "$prev" in
        -b|--backend)
            COMPREPLY=($(compgen -W "gemini openai anthropic github-api copilot-cli cursor" -- "$cur"))
            return ;;
        -q|--quality|--tier)
            COMPREPLY=($(compgen -W "low fast normal default high slow" -- "$cur"))
            return ;;
        -p|--prompt|-m|--model|--tier)
            # these take free-form text / handled separately, no completion
            return ;;
    esac

    if [[ "$cur" == -* ]]; then
        COMPREPLY=($(compgen -W \
            "--prompt -p --backend -b --model -m --quality --tier -q \
             --vision --list-models --refresh-models --verbose -v" \
            -- "$cur"))
    else
        # complete file paths for context files
        COMPREPLY=($(compgen -f -- "$cur"))
    fi
}

complete -F _ai_backends_complete ai-backends

# ── Forward to ai-backends if run directly (not sourced) ──────────────────────
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    exec ai-backends "$@"
fi
