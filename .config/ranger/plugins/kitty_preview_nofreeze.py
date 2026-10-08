# ==============================================================================
# @usage            : Loaded automatically by ranger from ~/.config/ranger/plugins/
#
# @meta_name        : kitty_preview_nofreeze.py
# @meta_author      : Florian Orzol <florian.orzol@gmail.com>
# @meta_version     : 1.0.2
# @meta_date        : 2026-10-03
#
# @desc_short       : Prevents ranger from freezing on kitty image previews.
# @desc_detailed    : ranger 1.9.4 waits for kitty's reply after every image with a
# @desc_detailed    : blocking, untimed read on the tty. A lost reply (e.g. after
# @desc_detailed    : dragon-drop or the rename console) freezes ranger forever.
# @desc_detailed    : This plugin draws images with q=2 (kitty sends no reply at all)
# @desc_detailed    : and guards the remaining one-time startup query with a timeout.
#
# @req_packages     : ranger 1.9.4, python-pillow, kitty
#
# @notes            : Temp files carry 'tty-graphics-protocol' in their name, otherwise
# @notes            : kitty does not delete them and they pile up in /tmp.
# ==============================================================================
from __future__ import absolute_import, division, print_function

import base64
import ctypes
import curses
import os
import select
import sys
import warnings
from tempfile import NamedTemporaryFile

from ranger.ext.img_display import ImageDisplayError, KittyImageDisplayer

# ==============================================================================
# --- User Configuration ---
# Adjust these to change timeout and temp file naming.
# ==============================================================================
TIMEOUT_KITTY_REPLY = 1.0                                       # seconds to wait for a reply byte
FILENAME_THUMB_PREFIX = 'ranger_thumb_tty-graphics-protocol_'   # kitty only deletes files with this marker

# ==============================================================================
# --- Script Internals ---
# ==============================================================================
LIBC = ctypes.CDLL(None)    # gives access to fflush() for curses' C stdio buffer


# ==============================================================================
# --- Timed tty reader ---
# Replaces the buffered stdin reader of the kitty displayer. Reads unbuffered,
# so no keystrokes get trapped in Python's buffer, and gives up after a timeout.
# ==============================================================================

# --- TimedTtyReader ---
# @desc_short       : File-like reader with read(1) that times out instead of blocking.
# @usage            : TimedTtyReader().read(1)
# ================================================================================
class TimedTtyReader(object):

    # --- read ---
    # @desc_short       : Reads up to size bytes from stdin, raises on timeout.
    # @usage            : reader.read(size)
    # @parameter        : size | int | Maximum number of bytes to read.
    # ================================================================================
    def read(self, size=1):
        fd_stdin = sys.stdin.fileno()   # raw tty file descriptor

        # Wait until the terminal has sent something, but never forever
        ready_fds, _, _ = select.select([fd_stdin], [], [], TIMEOUT_KITTY_REPLY)

        # No reply within the timeout -> abort the preview instead of freezing
        if not ready_fds:
            raise ImageDisplayError('kitty did not reply within {}s'.format(TIMEOUT_KITTY_REPLY))

        # Read unbuffered so following keystrokes stay in the tty for curses
        return os.read(fd_stdin, size)


# ==============================================================================
# --- Patched draw ---
# Copy of KittyImageDisplayer.draw from ranger 1.9.4 with these changes:
# q=2 suppresses kitty's reply, and the reply read loop is removed.
# C=1 keeps kitty from moving the cursor behind the image, and the cursor is
# saved/restored in the same stream as the image. Otherwise console
# input (e.g. rename) is typed next to the preview instead of the bottom line.
# ==============================================================================

# --- draw_without_reply ---
# @desc_short       : Draws an image in kitty without waiting for a reply.
# @usage            : displayer.draw(path, start_x, start_y, width, height)
# @parameter        : path    | str | Image file to display.
# @parameter        : start_x | int | Left cell of the preview area.
# @parameter        : start_y | int | Top cell of the preview area.
# @parameter        : width   | int | Width of the preview area in cells.
# @parameter        : height  | int | Height of the preview area in cells.
# ================================================================================
def draw_without_reply(self, path, start_x, start_y, width, height):
    self.image_id += 1
    cmds = {'a': 'T', 'i': self.image_id, 'q': 2, 'C': 1}    # q=2: no reply, C=1: cursor stays put

    # Finish initialization on the first call (startup query, backend, cell size)
    if self.needs_late_init:
        self._late_init()

    # Open the image, ignoring pillow's decompression bomb warning like upstream
    with warnings.catch_warnings(record=True):
        warnings.simplefilter('ignore', self.backend.DecompressionBombWarning)
        image = self.backend.open(path)

    box = (width * self.pix_row, height * self.pix_col)   # preview area in pixels

    # Downscale images that do not fit into the preview area
    if image.width > box[0] or image.height > box[1]:
        scale = min(box[0] / image.width, box[1] / image.height)
        image = image.resize((int(scale * image.width), int(scale * image.height)),
                             self.backend.LANCZOS)

    # kitty only understands RGB/RGBA bitmaps or PNG
    if image.mode != 'RGB' and image.mode != 'RGBA':
        image = image.convert('RGB')

    # Remote terminal: embed the raw pixel data as base64
    if self.stream:
        cmds.update({'t': 'd', 'f': len(image.getbands()) * 8,
                     's': image.width, 'v': image.height, })
        payload = base64.standard_b64encode(
            bytearray().join(map(bytes, image.getdata())))
    # Local terminal: hand over a temp PNG that kitty reads and deletes
    else:
        cmds.update({'t': 't', 'f': 100, })
        with NamedTemporaryFile(prefix=FILENAME_THUMB_PREFIX, suffix='.png', delete=False) as tmpf:
            image.save(tmpf, format='png', compress_level=0)
            payload = base64.standard_b64encode(tmpf.name.encode(self.fsenc))

    # Push out pending curses output first, so the saved cursor position is current
    LIBC.fflush(None)

    # Save the cursor in the same stream as the image (upstream uses curses.putp,
    # whose C buffer reaches the tty out of order, so the restore got lost)
    self.stdbout.write(curses.tigetstr('sc'))

    # Jump to the top-left cell of the preview area
    self.stdbout.write(curses.tparm(curses.tigetstr('cup'), int(start_y), int(start_x)))

    # Large payloads are split into several protocol chunks
    for cmd_str in self._format_cmd_str(cmds, payload=payload):
        self.stdbout.write(cmd_str)

    # Restore the cursor to where curses expects it and push everything out at once
    self.stdbout.write(curses.tigetstr('rc'))
    self.stdbout.flush()


# ==============================================================================
# --- Apply patches ---
# Swap the reader (used by the one-time startup query) and the draw method.
# ==============================================================================
KittyImageDisplayer.stdbin = TimedTtyReader()
KittyImageDisplayer.draw = draw_without_reply
