set -u

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  echo "Usage: work_on <document[.typ]> [template]"
  echo ""
  echo "Options:"
  echo "  -l, --list-templates    List available templates"
  echo ""
  echo "Examples:"
  echo "  work_on assignment1 uni   Create/open assignment1.typ with uni template"
  echo "  work_on notes privat      Create/open notes.typ with privat template"
  echo "  work_on document          Create/open with default document layout"
  exit 0
fi

if [ "${1:-}" = "-l" ] || [ "${1:-}" = "--list-templates" ]; then
  echo "Available Typst templates:"
  LOCAL_DIR="$HOME/.local/share/typst/packages/local"
  if [ -d "$LOCAL_DIR" ]; then
    for pkg in "$LOCAL_DIR"/*; do
      if [ -d "$pkg" ]; then
        name="$(basename "$pkg")"
        version="$(ls "$pkg" 2>/dev/null | head -n 1)"
        echo "  • $name -> #import \"@local/$name:$version\": *"
      fi
    done
  else
    echo "  No templates found."
  fi
  exit 0
fi

if [ $# -eq 0 ]; then
  echo "Usage: work_on <document[.typ]> [template]"
  echo "Help: work_on --help | work_on --list-templates"
  exit 1
fi

# Determine absolute path and target file
TARGET="$(realpath -m "$1")"
if [[ $TARGET != *.typ ]]; then
  TARGET="${TARGET}.typ"
fi

TEMPLATE="${2:-}"

# If a template is specified, verify it exists; otherwise print info message and exit
LOCAL_DIR="$HOME/.local/share/typst/packages/local"
if [ -n "$TEMPLATE" ]; then
  PKG_DIR="$LOCAL_DIR/$TEMPLATE"
  if [ ! -d "$PKG_DIR" ]; then
    echo "Info: Template '$TEMPLATE' not found."
    exit 0
  fi
fi

DIR="$(dirname "$TARGET")"
if [ -n "$DIR" ] && [ ! -d "$DIR" ]; then
  mkdir -p "$DIR"
fi

# Initialize file if it does not exist
if [ ! -f "$TARGET" ]; then
  if [ -n "$TEMPLATE" ]; then
    PKG_DIR="$LOCAL_DIR/$TEMPLATE"
    VER="$(ls "$PKG_DIR" 2>/dev/null | head -n 1)"
    CONTENT_FILE="$PKG_DIR/$VER/content.typ"

    if [ -f "$CONTENT_FILE" ]; then
      cat "$CONTENT_FILE" >"$TARGET"
      chmod u+w "$TARGET"
    else
      touch "$TARGET"
    fi
  else
    DOC_TITLE="$(basename "$TARGET" .typ | tr '_-' ' ')"
    cat <<EOF >"$TARGET"
#set page(paper: "a4", margin: 2.5cm)
#set text(font: "Libertinus Serif", size: 11pt, lang: "de")

= $DOC_TITLE

EOF
  fi
fi

# Ensure user has write permissions on the document
if [ -f "$TARGET" ] && [ -O "$TARGET" ]; then
  chmod u+w "$TARGET" 2>/dev/null || true
fi

PDF="${TARGET%.typ}.pdf"

# Initial compilation so the PDF exists before the viewer opens
typst compile "$TARGET" "$PDF" 2>/dev/null || true

# Start typst watch in background
LOGFILE="/tmp/typst-watch-$USER.log"
typst watch "$TARGET" "$PDF" >"$LOGFILE" 2>&1 &
TYPST_PID=$!

# Save active window in Hyprland to restore focus to Neovim
ACTIVE_WIN=""
if command -v hyprctl >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
  ACTIVE_WIN="$(hyprctl activewindow -j 2>/dev/null | jq -r '.address // empty' 2>/dev/null || true)"
fi

# Start PDF viewer (zathura preferred)
VIEWER_PID=""
if command -v zathura >/dev/null 2>&1; then
  zathura "$PDF" >/dev/null 2>&1 &
  VIEWER_PID=$!
elif command -v xdg-open >/dev/null 2>&1; then
  xdg-open "$PDF" >/dev/null 2>&1 &
  VIEWER_PID=$!
fi

# Refocus Neovim terminal in Hyprland if applicable
if [ -n "$ACTIVE_WIN" ]; then
  (sleep 0.2 && hyprctl dispatch focuswindow "address:$ACTIVE_WIN" >/dev/null 2>&1) &
fi

# Cleanup handler: kill both typst watch and PDF viewer on exit
cleanup() {
  if [ -n "$TYPST_PID" ]; then
    kill "$TYPST_PID" 2>/dev/null || true
  fi
  if [ -n "$VIEWER_PID" ]; then
    kill "$VIEWER_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT INT TERM

# Open Neovim
nvim "$TARGET"
