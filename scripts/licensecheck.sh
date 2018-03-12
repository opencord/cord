#!/usr/bin/env sh

# licensecheck.sh
# checks for copyright/license headers on files
# excludes filename extensions where this check isn't pertinent

# this could be rewritten with better form. Currently is a cut/paste from the
# Jenkins job with minimal changes (BSD/OS X xargs params compat, sort of
# excluded file extensions).

find . -name ".git" -prune -o -type f \
  -name "*.*" \
  ! -name "*.PNG" \
  ! -name "*.asc" \
  ! -name "*.bat" \
  ! -name "*.cfg" \
  ! -name "*.cnf" \
  ! -name "*.conf" \
  ! -name "*.cql" \
  ! -name "*.crt" \
  ! -name "*.csr" \
  ! -name "*.csv" \
  ! -name "*.ctmpl" \
  ! -name "*.curl" \
  ! -name "*.db" \
  ! -name "*.der" \
  ! -name "*.diff" \
  ! -name "*.dnsmasq" \
  ! -name "*.do" \
  ! -name "*.docx" \
  ! -name "*.eot" \
  ! -name "*.gif" \
  ! -name "*.gpg" \
  ! -name "*.graffle" \
  ! -name "*.iml" \
  ! -name "*.in" \
  ! -name "*.inc" \
  ! -name "*.j2" \
  ! -name "*.jar" \
  ! -name "*.jks" \
  ! -name "*.jpg" \
  ! -name "*.json" \
  ! -name "*.key" \
  ! -name "*.list" \
  ! -name "*.local" \
  ! -name "*.log" \
  ! -name "*.mak" \
  ! -name "*.md" \
  ! -name "*.mk" \
  ! -name "*.oar" \
  ! -name "*.p12" \
  ! -name "*.patch" \
  ! -name "*.pcap" \
  ! -name "*.pem" \
  ! -name "*.png" \
  ! -name "*.properties" \
  ! -name "*.proto" \
  ! -name "*.pyc" \
  ! -name "*.repo" \
  ! -name "*.robot" \
  ! -name "*.rst" \
  ! -name "*.rules" \
  ! -name "*.service" \
  ! -name "*.svg" \
  ! -name "*.swp" \
  ! -name "*.tar" \
  ! -name "*.tar.gz" \
  ! -name "*.toml" \
  ! -name "*.ttf" \
  ! -name "*.txt" \
  ! -name "*.woff" \
  ! -name "*.xproto" \
  ! -name "*.xtarget" \
  ! -name "*ignore" \
  ! -name "*rc" \
  ! -name "Dockerfile" \
  ! -name "Dockerfile.*" \
  ! -name "Makefile" \
  ! -name "Makefile.*" \
  ! -name "README" \
  ! -path "*/vendor/*.go" \
  ! -path "*conf*" \
  ! -path "*git*" \
  ! -path "*swagger*" \
  -print0 |   \
  xargs -0 -n1 sh -c 'if ! grep -q "Copyright\|Apache License" $0; then echo "ERROR: $0 does not contain Copyright header"; exit 1; fi;'

