#!/bin/bash
# ==============================================================================
# @meta_name        : arguments.sh
# @desc_short       : CLI argument definitions for 'kb'.
# ==============================================================================

# --- function arguments ---
# @desc_short  : Registers CLI arguments.
# @usage       : kb [<topic/name> | new|edit|rm <topic/name> | search <text…> | list]
#
# @first       : <topic/name>  | Show this entry (positional)
#                new|edit|rm   | Action on the entry in the second position
#                search|list   | Full text search / overview
# @second      : <topic/name>  | Entry for new, edit, rm — search text for search
# ==============================================================================
function arguments {
    # Actions and entries share the first position — entries always contain a '/'
    arg_direct @first --description "Action or entry (topic/name)" --option-cmd "kb_complete_first"

    # Entry for new/edit/rm, search text for search
    arg_direct @second --description "Entry (topic/name) or search text" --option-cmd "kb_entries"
}
