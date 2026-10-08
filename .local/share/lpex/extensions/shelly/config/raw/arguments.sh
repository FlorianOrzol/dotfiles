#!/bin/bash
# ==============================================================================
# @meta_name        : arguments.sh
# @desc_short       : CLI argument definitions for 'shelly config raw'.
# ==============================================================================

# --- function arguments ---
# @desc_short  : Registers device, request and the RPC parameters.
# @usage       : lpex shelly config raw <device> <request> [--params <json>]
#
# @options     : <device>  | id, MAC or IP (positional, fzf)
#                <request> | Gen1: path with query, e.g. "/settings/relay/0?auto_off=60"
#                            Gen2+: RPC method, e.g. "Switch.SetConfig"
#                --params  | Gen2+: parameters as JSON, e.g. '{"id":0,"config":{"auto_off":true}}'
# @notes       : API references: shelly-api-docs.shelly.cloud (gen1 / gen2).
#                Read-only examples: Gen1 "/settings", Gen2 "Shelly.GetDeviceInfo".
# ==============================================================================
function arguments {
    arg_direct @device  --description "Device (id, MAC or IP)" --fzf --option-cmd "get_shelly_devices"
    arg_direct @request --description "Gen1 path (/settings/...?k=v) or Gen2 RPC method"
    arg_value  @params  --description "Gen2+: RPC parameters as JSON"
}
