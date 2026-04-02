#!/usr/bin/env bash
# Interactive installer for Claude Code skills plugin
# Lets the user select individual components to install
set -euo pipefail

trap 'echo; exit 130' INT

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_DIR"

CLAUDE_HOME="${HOME}/.claude"

# Parallel arrays (Bash 3.2 compatible)
ITEMS=()
CATEGORIES=()
SOURCES=()
SELECTED=()

# Discovery
for f in commands/*.md; do
  [[ -f "$f" ]] || continue
  name=$(basename "$f" .md)
  ITEMS+=("$name")
  CATEGORIES+=("Command")
  SOURCES+=("$f")
  SELECTED+=("1")
done

for f in agents/*.md; do
  [[ -f "$f" ]] || continue
  name=$(basename "$f" .md)
  ITEMS+=("$name")
  CATEGORIES+=("Agent")
  SOURCES+=("$f")
  SELECTED+=("1")
done

for d in skills/*/; do
  [[ -f "$d/SKILL.md" ]] || continue
  name=$(basename "$d")
  ITEMS+=("$name")
  CATEGORIES+=("Skill")
  SOURCES+=("$d")
  SELECTED+=("1")
done

total=${#ITEMS[@]}
if [[ $total -eq 0 ]]; then
  echo "No components found to install."
  exit 0
fi

print_menu() {
  printf '\033c'
  echo "Claude Code Skills Installer"
  echo "============================="

  local current_cat=""
  for i in "${!ITEMS[@]}"; do
    if [[ "${CATEGORIES[$i]}" != "$current_cat" ]]; then
      current_cat="${CATEGORIES[$i]}"
      echo ""
      echo "  ${current_cat}s"
      echo "  --------"
    fi
    local mark=" "
    [[ "${SELECTED[$i]}" == "1" ]] && mark="x"
    printf "   [%s] %2d) %s\n" "$mark" $((i + 1)) "${ITEMS[$i]}"
  done

  echo ""
  echo "  a) select all    n) deselect all"
  echo "  i) install       q) quit"
  echo ""
}

# Selection loop
while true; do
  print_menu
  printf "  Toggle items (e.g. \"3\" or \"1 4 7\"): "
  read -r input

  case "$input" in
    a|A)
      for i in "${!SELECTED[@]}"; do SELECTED[$i]=1; done
      ;;
    n|N)
      for i in "${!SELECTED[@]}"; do SELECTED[$i]=0; done
      ;;
    q|Q)
      echo "Cancelled."
      exit 0
      ;;
    i|I)
      break
      ;;
    *)
      for token in $input; do
        if [[ "$token" =~ ^[0-9]+$ ]] && (( token >= 1 && token <= total )); then
          idx=$((token - 1))
          if [[ "${SELECTED[$idx]}" == "1" ]]; then
            SELECTED[$idx]=0
          else
            SELECTED[$idx]=1
          fi
        fi
      done
      ;;
  esac
done

# Install selected items
count=0
echo ""
echo "Will install:"
for i in "${!ITEMS[@]}"; do
  if [[ "${SELECTED[$i]}" == "1" ]]; then
    echo "  - ${CATEGORIES[$i]}: ${ITEMS[$i]}"
    count=$((count + 1))
  fi
done

if [[ $count -eq 0 ]]; then
  echo "  (nothing selected)"
  exit 0
fi

echo ""
printf "Proceed? [Y/n] "
read -r confirm
if [[ "$confirm" =~ ^[nN] ]]; then
  echo "Cancelled."
  exit 0
fi

echo ""
for i in "${!ITEMS[@]}"; do
  [[ "${SELECTED[$i]}" == "1" ]] || continue
  src="${SOURCES[$i]}"
  cat="${CATEGORIES[$i]}"

  if [[ "$cat" == "Skill" ]]; then
    dest_dir="$CLAUDE_HOME/skills/${ITEMS[$i]}"
    mkdir -p "$dest_dir"
    rsync -av "$src" "$dest_dir/"
  else
    dir=$(dirname "$src")
    mkdir -p "$CLAUDE_HOME/$dir"
    rsync -av "$src" "$CLAUDE_HOME/$src"
  fi
done

echo ""
echo "Done. Installed $count item(s) to $CLAUDE_HOME"
