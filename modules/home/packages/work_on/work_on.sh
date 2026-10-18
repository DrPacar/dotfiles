set -euo pipefail

LOCAL_DIR="$HOME/.local/share/typst/packages/local"
NO_VIEWER=0
INTERACTIVE_TEMPLATE=0
TEMPLATE=""
POSITIONAL=()

# --- Help Function ---
show_help() {
  cat <<EOF
Usage: work_on [OPTIONS] <document[.typ]> [template]

Create, compile, watch, and edit Typst documents.

Options:
  -l, --list-templates    List available local templates
  -t, --template [NAME]   Specify template or select interactively with fzf
  -n, --no-viewer         Do not launch the PDF viewer (zathura)
  -h, --help              Show this help message and exit

Examples:
  work_on assignment1 uni      Create/open assignment1.typ with uni template
  work_on notes privat         Create/open notes.typ with privat template
  work_on -t notes             Interactively choose template for notes.typ
  work_on -n document          Open document.typ without launching PDF viewer
  work_on document             Create/open with default document layout
EOF
}

# --- List Available Templates ---
list_templates() {
  if [ -d "$LOCAL_DIR" ]; then
    for pkg in "$LOCAL_DIR"/*; do
      if [ -d "$pkg" ]; then
        basename "$pkg"
      fi
    done
  fi
}

# --- Argument Parsing ---
while [[ $# -gt 0 ]]; do
  case "$1" in
  -h | --help)
    show_help
    exit 0
    ;;
  -l | --list-templates)
    echo "Available Typst templates:"
    templates=$(list_templates)
    if [ -n "$templates" ]; then
      echo "$templates" | sed 's/^/  • /'
    else
      echo "  No templates found in $LOCAL_DIR"
    fi
    exit 0
    ;;
  -n | --no-viewer)
    NO_VIEWER=1
    shift
    ;;
  -t | --template)
    if [[ -n ${2:-} && $2 != -* ]]; then
      TEMPLATE="$2"
      shift 2
    else
      INTERACTIVE_TEMPLATE=1
      shift
    fi
    ;;
  -*)
    echo "Error: Unknown option '$1'"
    echo
    show_help
    exit 1
    ;;
  *)
    POSITIONAL+=("$1")
    shift
    ;;
  esac
done

if [[ ${#POSITIONAL[@]} -eq 0 ]]; then
  echo "Error: No document specified."
  echo
  show_help
  exit 1
fi

DOC_ARG="${POSITIONAL[0]}"

# If template was not set by -t, check 2nd positional argument
if [[ -z $TEMPLATE && ${#POSITIONAL[@]} -ge 2 ]]; then
  TEMPLATE="${POSITIONAL[1]}"
fi

# Interactive template selection if requested
if [[ $INTERACTIVE_TEMPLATE -eq 1 && -z $TEMPLATE ]]; then
  templates=$(list_templates)
  if [[ -z $templates ]]; then
    echo "Info: No local templates available in $LOCAL_DIR."
  else
    if command -v fzf >/dev/null 2>&1; then
      TEMPLATE=$(echo "$templates" | fzf \
        --prompt="📝 Select template: " \
        --border=rounded \
        --layout=reverse \
        --info=hidden \
        --header=" Typst Templates " || true)
      if [[ -z $TEMPLATE ]]; then
        echo "No template selected. Aborting."
        exit 0
      fi
    fi
  fi
fi

# If a template is specified, verify it exists
if [ -n "$TEMPLATE" ]; then
  PKG_DIR="$LOCAL_DIR/$TEMPLATE"
  if [ ! -d "$PKG_DIR" ]; then
    echo "❌ Error: Template '$TEMPLATE' not found."
    echo "Available templates:"
    templates=$(list_templates)
    if [ -n "$templates" ]; then
      echo "$templates" | sed 's/^/  • /'
    else
      echo "  (None found in $LOCAL_DIR)"
    fi
    exit 1
  fi
fi

# Determine absolute path and target file
TARGET="$(realpath -m "$DOC_ARG")"
if [[ $TARGET != *.typ ]]; then
  TARGET="${TARGET}.typ"
fi

DIR="$(dirname "$TARGET")"
if [ -n "$DIR" ] && [ ! -d "$DIR" ]; then
  mkdir -p "$DIR"
fi

# Initialize file if it does not exist
if [ ! -f "$TARGET" ]; then
  if [ -n "$TEMPLATE" ]; then
    PKG_DIR="$LOCAL_DIR/$TEMPLATE"
    CONTENT_FILE="$(find "$PKG_DIR" -name "content.typ" 2>/dev/null | head -n 1)"

    if [ -n "$CONTENT_FILE" ] && [ -f "$CONTENT_FILE" ]; then
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

# Document-specific logfile for parallel instances
DOC_NAME="$(basename "$TARGET" .typ)"
LOGFILE="/tmp/typst-watch-${DOC_NAME}-${USER}.log"

# Initial compilation so the PDF exists before the viewer opens
if ! typst compile "$TARGET" "$PDF" 2>"$LOGFILE"; then
  echo "⚠️ Warning: Initial compilation failed. See $LOGFILE"
fi

# Start typst watch in background
typst watch "$TARGET" "$PDF" >>"$LOGFILE" 2>&1 &
TYPST_PID=$!

# Viewer logic
VIEWER_PID=""
if [ "$NO_VIEWER" -eq 0 ]; then
  ACTIVE_WIN=""
  if command -v hyprctl >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
    ACTIVE_WIN="$(hyprctl activewindow -j 2>/dev/null | jq -r '.address // empty' 2>/dev/null || true)"
  fi

  if command -v zathura >/dev/null 2>&1; then
    zathura "$PDF" >/dev/null 2>&1 &
    VIEWER_PID=$!
  elif command -v xdg-open >/dev/null 2>&1; then
    xdg-open "$PDF" >/dev/null 2>&1 &
    VIEWER_PID=$!
  fi

  # Refocus editor terminal in Hyprland if applicable
  if [ -n "$ACTIVE_WIN" ]; then
    (sleep 0.2 && hyprctl dispatch focuswindow "address:$ACTIVE_WIN" >/dev/null 2>&1) &
  fi
fi

# Cleanup handler: kill both typst watch and PDF viewer on exit
cleanup() {
  if [ -n "${TYPST_PID:-}" ]; then
    kill "$TYPST_PID" 2>/dev/null || true
  fi
  if [ -n "${VIEWER_PID:-}" ]; then
    kill "$VIEWER_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT INT TERM

# Open editor
"${EDITOR:-nvim}" "$TARGET"
