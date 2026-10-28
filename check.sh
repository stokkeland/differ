#!/usr/bin/env bash
#
# DIƒƒER deployment check for Apache httpd on Ubuntu/Debian.
# Read-only: reports problems, changes nothing.
#
# Usage: bash check.sh        (run with sudo for the most complete check)
#

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WEB_USER="${WEB_USER:-www-data}"
HOST="${HOST:-localhost}"

FAILS=0
WARNS=0

ok()   { printf '  \033[32m[ OK ]\033[0m %s\n' "$*"; }
warn() { printf '  \033[33m[WARN]\033[0m %s\n' "$*"; WARNS=$((WARNS + 1)); }
fail() { printf '  \033[31m[FAIL]\033[0m %s\n' "$*"; FAILS=$((FAILS + 1)); }
info() { printf '         %s\n' "$*"; }

echo "Checking DIƒƒER in $APP_DIR"
echo

# --- Apache ---------------------------------------------------------------
echo "Apache"

APACHECTL="$(command -v apache2ctl || command -v apachectl || true)"
if [ -z "$APACHECTL" ]; then
  fail "Apache is not installed"
  info "sudo apt install apache2"
else
  VERSION="$("$APACHECTL" -v 2>/dev/null | sed -n 's/.*Apache\/\([0-9.]*\).*/\1/p')"
  case "$VERSION" in
    2.4.*) ok "Apache $VERSION installed" ;;
    "")    warn "Apache installed, but could not read its version" ;;
    *)     fail "Apache $VERSION found, 2.4 or newer is required" ;;
  esac

  if command -v systemctl >/dev/null 2>&1; then
    if systemctl is-active --quiet apache2; then
      ok "apache2 service is running"
    else
      fail "apache2 service is not running"
      info "sudo systemctl enable --now apache2"
    fi
  fi

  MODULES="$("$APACHECTL" -M 2>/dev/null)"
  if [ -n "$MODULES" ]; then
    for mod in authz_core dir mime; do
      if echo "$MODULES" | grep -q "${mod}_module"; then
        ok "module $mod enabled"
      else
        fail "module $mod is not enabled"
        info "sudo a2enmod $mod && sudo systemctl reload apache2"
      fi
    done
  else
    warn "could not list Apache modules (try running with sudo)"
  fi
fi
echo

# --- Files ----------------------------------------------------------------
echo "Files"

REQUIRED="
index.html
.htaccess
client/css/main.css
client/css/vendor/diff2html.min.css
client/css/vendor/micromodal.min.css
client/css/vendor/pure.min.css
client/img/icon.svg
client/js/utils.js
client/js/editor.js
client/js/main.js
client/js/vendor/diff.min.js
client/js/vendor/diff2html-ui.min.js
client/js/vendor/diff2html.min.js
client/js/vendor/micromodal.min.js
"
MISSING=0
for f in $REQUIRED; do
  if [ ! -f "$APP_DIR/$f" ]; then
    fail "missing $f"
    MISSING=1
  fi
done
[ "$MISSING" -eq 0 ] && ok "all required files present"

if [ "$(id -u)" -eq 0 ] && id "$WEB_USER" >/dev/null 2>&1; then
  UNREADABLE=0
  for f in $REQUIRED; do
    [ -f "$APP_DIR/$f" ] || continue
    if ! su -s /bin/sh "$WEB_USER" -c "test -r '$APP_DIR/$f'"; then
      fail "$WEB_USER cannot read $f"
      UNREADABLE=1
    fi
  done
  if [ "$UNREADABLE" -eq 0 ]; then
    ok "$WEB_USER can read all required files"
  else
    info "sudo chmod -R a+rX '$APP_DIR'"
  fi
else
  BAD="$(find "$APP_DIR" -path "$APP_DIR/.git" -prune -o \( -type f ! -perm -o=r -o -type d ! -perm -o=x \) -print 2>/dev/null | head -5)"
  if [ -n "$BAD" ]; then
    warn "some files are not world-readable (Apache may not be able to read them):"
    echo "$BAD" | while read -r p; do info "$p"; done
    info "sudo chmod -R a+rX '$APP_DIR'"
  else
    ok "files are world-readable"
  fi
fi
echo

# --- HTTP -----------------------------------------------------------------
echo "HTTP"

DOCROOT=""
if [ -n "$APACHECTL" ]; then
  DOCROOT="$("$APACHECTL" -S 2>/dev/null | sed -n 's/^Main DocumentRoot: "\(.*\)"/\1/p')"
fi
DOCROOT="${DOCROOT:-/var/www/html}"
DOCROOT="$(cd "$DOCROOT" 2>/dev/null && pwd || echo "$DOCROOT")"

case "$APP_DIR/" in
  "$DOCROOT"/*) URL_PATH="${APP_DIR#"$DOCROOT"}/" ;;
  *)            URL_PATH="" ;;
esac

if [ -z "$URL_PATH" ]; then
  warn "$APP_DIR is not under the DocumentRoot ($DOCROOT)"
  info "copy the folder there, e.g. sudo cp -r '$APP_DIR' $DOCROOT/differ"
  info "or set up an Alias/VirtualHost for it, then re-run this check"
elif ! command -v curl >/dev/null 2>&1; then
  warn "curl not installed, skipping HTTP checks (sudo apt install curl)"
else
  BASE="http://$HOST$URL_PATH"
  status() { curl -s -o /dev/null -w '%{http_code}' "$BASE$1"; }

  for p in "" "client/js/main.js" "client/css/main.css"; do
    code="$(status "$p")"
    if [ "$code" = "200" ]; then
      ok "GET /${URL_PATH#/}$p -> $code"
    else
      fail "GET /${URL_PATH#/}$p -> $code (expected 200)"
    fi
  done

  HTACCESS_OK=1
  for p in "README.md" ".htaccess" ".git/HEAD" "content/logo.png" "client/"; do
    [ -e "$APP_DIR/$p" ] || continue
    code="$(status "$p")"
    case "$code" in
      403|404) ok "GET /${URL_PATH#/}$p -> $code (blocked)" ;;
      *)       fail "GET /${URL_PATH#/}$p -> $code (should be blocked)"; HTACCESS_OK=0 ;;
    esac
  done

  if [ "$HTACCESS_OK" -eq 0 ]; then
    info ".htaccess is not being applied. Add this to your Apache config"
    info "(e.g. /etc/apache2/sites-available/000-default.conf) and reload:"
    info ""
    info "  <Directory $APP_DIR>"
    info "      AllowOverride All"
    info "  </Directory>"
    info ""
    info "sudo systemctl reload apache2"
  fi
fi
echo

# --- Summary --------------------------------------------------------------
if [ "$FAILS" -gt 0 ]; then
  echo "$FAILS problem(s), $WARNS warning(s) found."
  exit 1
fi
[ -n "$URL_PATH" ] && echo "All good. Open http://<your-server>$URL_PATH" || echo "No problems found ($WARNS warning(s))."
exit 0
