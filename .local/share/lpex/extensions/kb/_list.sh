#!/bin/bash
# ==============================================================================
# @meta_name        : _list.sh
# @desc_short       : Overview of all entries grouped by topic.
# ==============================================================================

# --- _kb_action_list ---
# @desc_short       : Prints every topic with its entries and their titles.
# @usage            : _kb_action_list
# ================================================================================
function _kb_action_list {
    local name_entry
    local topic_current=""
    local topic

    # Empty knowledge base: point to the first step
    if [[ -z "$(kb_entries)" ]]; then
        INFO "The knowledge base is empty. Create the first entry with: kb new <topic/name>"
        return 0
    fi

    # Entries come sorted, so a topic change starts a new block
    while IFS= read -r name_entry; do
        topic="${name_entry%%/*}"
        # Header once per topic
        if [[ "$topic" != "$topic_current" ]]; then
            printf '%b\n' "${FONT_BOLD}${FONT_BLUE}${topic}/${FONT_RESET}"
            topic_current="$topic"
        fi
        printf '%b\n' "  ${name_entry#*/}  ${FONT_GRAY}$(kb_title "$name_entry")${FONT_RESET}"
    done < <(kb_entries)
}
