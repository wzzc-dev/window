#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ALLOWLIST="$ROOT/docs/ffi-export-allowlist.txt"
WRAPPER_ALLOWLIST="$ROOT/docs/ffi-native-wrapper-allowlist.txt"
LINUX_ALLOWLIST="$ROOT/docs/ffi-linux-export-allowlist.txt"
WINDOWS_ALLOWLIST="$ROOT/docs/ffi-windows-export-allowlist.txt"

if [[ ! -f "$ALLOWLIST" ]]; then
  echo "missing allowlist: $ALLOWLIST" >&2
  exit 1
fi

if [[ ! -f "$WRAPPER_ALLOWLIST" ]]; then
  echo "missing wrapper allowlist: $WRAPPER_ALLOWLIST" >&2
  exit 1
fi

if [[ ! -f "$LINUX_ALLOWLIST" ]]; then
  echo "missing Linux allowlist: $LINUX_ALLOWLIST" >&2
  exit 1
fi

if [[ ! -f "$WINDOWS_ALLOWLIST" ]]; then
  echo "missing Windows allowlist: $WINDOWS_ALLOWLIST" >&2
  exit 1
fi

extract_exports() {
  perl -ne '
    if(/MOONBIT_FFI_EXPORT/){$w=1;next}
    if($w){
      next if /^\s*$/;
      if(/(mbw_[A-Za-z0-9_]+)\s*\(/){print "$1\n"; $w=0}
    }
  ' "$ROOT"/macos/native_*.m "$ROOT"/macos/native_*.c | sort -u
}

extract_exports_from() {
  perl -ne '
    if(/MOONBIT_FFI_EXPORT/){$w=1;next}
    if($w){
      next if /^\s*$/;
      if(/(mbw_[A-Za-z0-9_]+)\s*\(/){print "$1\n"; $w=0}
    }
  ' "$@" | sort -u
}

extract_exports_from_branch() {
  local branch="$1"
  shift
  perl -ne '
    BEGIN { $branch = shift @ARGV; $depth = 0; $section = "outside"; $want = 0 }
    if ($ARGV ne $file) {
      $file = $ARGV;
      $depth = 0;
      $section = "outside";
      $want = 0;
    }
    if (/^#(?:if|ifdef|ifndef)\b/) {
      if ($depth == 0 && /^#ifdef\s+(?:__linux__|_WIN32)\b/) {
        $section = "platform";
      }
      $depth++;
      next;
    }
    if (/^#else\b/) {
      if ($depth == 1 && ($section eq "platform" || $section eq "stub")) {
        $section = "stub";
      }
      next;
    }
    if (/^#endif\b/) {
      if ($depth == 1 && ($section eq "platform" || $section eq "stub")) {
        $section = "outside";
      }
      $depth-- if $depth > 0;
      next;
    }
    next unless $section eq $branch;
    if (/MOONBIT_FFI_EXPORT/) { $want = 1; next }
    if ($want) {
      next if /^\s*$/;
      if (/(mbw_[A-Za-z0-9_]+)\s*\(/) { print "$1\n"; $want = 0 }
    }
  ' "$branch" "$@" | sort -u
}

extract_export_signatures_from_branch() {
  local branch="$1"
  shift
  perl -ne '
    sub trim {
      my ($value) = @_;
      $value =~ s/^\s+|\s+$//g;
      return $value;
    }
    sub normalize_type {
      my ($value) = @_;
      $value = trim($value);
      $value =~ s/\s+/ /g;
      $value =~ s/\s*\*\s*/ */g;
      return trim($value);
    }
    sub parameter_type {
      my ($parameter) = @_;
      $parameter = normalize_type($parameter);
      return "void" if $parameter eq "" || $parameter eq "void";
      if ($parameter =~ /^(.*?)(\*?)\s*([A-Za-z_][A-Za-z0-9_]*)$/) {
        return normalize_type("$1$2");
      }
      return $parameter;
    }
    sub emit_signature {
      my ($signature) = @_;
      $signature =~ s/\s+/ /g;
      $signature = trim($signature);
      if ($signature =~ /^(.*?)\b(mbw_[A-Za-z0-9_]+)\s*\((.*)\)\s*$/) {
        my ($return_type, $symbol, $parameters) = ($1, $2, $3);
        my @parameter_types = map { parameter_type($_) } split /\s*,\s*/, $parameters;
        @parameter_types = ("void") if @parameter_types == 0;
        print "$symbol\t" . normalize_type($return_type) . " $symbol(" . join(", ", @parameter_types) . ")\n";
      }
    }

    BEGIN { $branch = shift @ARGV; $depth = 0; $section = "outside"; $want = 0; $signature = "" }
    if ($ARGV ne $file) {
      $file = $ARGV;
      $depth = 0;
      $section = "outside";
      $want = 0;
      $signature = "";
    }
    if (/^#(?:if|ifdef|ifndef)\b/) {
      if ($depth == 0 && /^#ifdef\s+(?:__linux__|_WIN32)\b/) {
        $section = "platform";
      }
      $depth++;
      next;
    }
    if (/^#else\b/) {
      if ($depth == 1 && ($section eq "platform" || $section eq "stub")) {
        $section = "stub";
      }
      next;
    }
    if (/^#endif\b/) {
      if ($depth == 1 && ($section eq "platform" || $section eq "stub")) {
        $section = "outside";
      }
      $depth-- if $depth > 0;
      next;
    }
    next unless $section eq $branch;
    if (/MOONBIT_FFI_EXPORT/) { $want = 1; $signature = ""; next }
    if ($want) {
      next if /^\s*$/ && $signature eq "";
      my $line = $_;
      $line =~ s/\{.*$//;
      $signature .= " " . $line;
      if (/\{/) {
        emit_signature($signature);
        $want = 0;
        $signature = "";
      }
    }
  ' "$branch" "$@" | sort -u
}

extract_mbw_bindings_from() {
  perl -0ne '
    while(/extern\s+"C"\s+fn\s+[A-Za-z0-9_]+.*?=\s*"(mbw_[A-Za-z0-9_]+)"/sg){
      print "$1\n";
    }
  ' "$@" | sort -u
}

check_export_allowlist() {
  local label="$1"
  local allowlist="$2"
  local current_exports="$3"
  local new_exports removed_exports

  new_exports="$(comm -13 "$allowlist" <(printf '%s\n' "$current_exports") || true)"
  if [[ -n "$new_exports" ]]; then
    echo "found newly introduced $label native export symbol(s):" >&2
    printf '%s\n' "$new_exports" >&2
    echo "update $allowlist only after explicit review" >&2
    exit 1
  fi

  removed_exports="$(comm -23 "$allowlist" <(printf '%s\n' "$current_exports") || true)"
  if [[ -n "$removed_exports" ]]; then
    echo "$label allowlist contains missing export symbol(s):" >&2
    printf '%s\n' "$removed_exports" >&2
    echo "sync $allowlist with current native exports" >&2
    exit 1
  fi
}

check_binding_exports() {
  local label="$1"
  local current_exports="$2"
  shift 2
  local current_bindings missing_exports

  current_bindings="$(extract_mbw_bindings_from "$@")"
  missing_exports="$(comm -23 <(printf '%s\n' "$current_bindings") <(printf '%s\n' "$current_exports") || true)"
  if [[ -n "$missing_exports" ]]; then
    echo "$label MoonBit extern binding(s) without reviewed native export symbol(s):" >&2
    printf '%s\n' "$missing_exports" >&2
    echo "add a matching MOONBIT_FFI_EXPORT native symbol or remove the stale binding" >&2
    exit 1
  fi
}

check_branch_exports() {
  local label="$1"
  shift
  local platform_exports stub_exports missing_in_stub missing_in_platform

  platform_exports="$(extract_exports_from_branch platform "$@")"
  stub_exports="$(extract_exports_from_branch stub "$@")"
  missing_in_stub="$(comm -23 <(printf '%s\n' "$platform_exports") <(printf '%s\n' "$stub_exports") || true)"
  if [[ -n "$missing_in_stub" ]]; then
    echo "$label native stub branch is missing export symbol(s):" >&2
    printf '%s\n' "$missing_in_stub" >&2
    echo "keep platform and non-host stub branches export-compatible" >&2
    exit 1
  fi

  missing_in_platform="$(comm -23 <(printf '%s\n' "$stub_exports") <(printf '%s\n' "$platform_exports") || true)"
  if [[ -n "$missing_in_platform" ]]; then
    echo "$label native platform branch is missing export symbol(s):" >&2
    printf '%s\n' "$missing_in_platform" >&2
    echo "keep platform and non-host stub branches export-compatible" >&2
    exit 1
  fi
}

check_branch_signatures() {
  local label="$1"
  shift
  local platform_signatures stub_signatures mismatches

  platform_signatures="$(extract_export_signatures_from_branch platform "$@")"
  stub_signatures="$(extract_export_signatures_from_branch stub "$@")"
  mismatches="$(
    perl -e '
      sub read_signatures {
        my ($path) = @_;
        open my $fh, "<", $path or die "cannot read $path: $!";
        my %signatures;
        while (my $line = <$fh>) {
          chomp $line;
          next if $line eq "";
          my ($symbol, $signature) = split /\t/, $line, 2;
          $signatures{$symbol} = $signature;
        }
        return \%signatures;
      }
      my ($platform_path, $stub_path) = @ARGV;
      my $platform = read_signatures($platform_path);
      my $stub = read_signatures($stub_path);
      my %symbols = map { $_ => 1 } (keys %{$platform}, keys %{$stub});
      for my $symbol (sort keys %symbols) {
        my $platform_signature = exists $platform->{$symbol} ? $platform->{$symbol} : "<missing signature>";
        my $stub_signature = exists $stub->{$symbol} ? $stub->{$symbol} : "<missing signature>";
        if ($platform_signature ne $stub_signature) {
          print "$symbol\n  platform: $platform_signature\n  stub:     $stub_signature\n";
        }
      }
    ' <(printf '%s\n' "$platform_signatures") <(printf '%s\n' "$stub_signatures") || true
  )"
  if [[ -n "$mismatches" ]]; then
    echo "$label native platform/stub export signature mismatch(es):" >&2
    printf '%s\n' "$mismatches" >&2
    echo "keep platform and non-host stub branches ABI-compatible" >&2
    exit 1
  fi
}

current_exports="$(extract_exports)"

if printf '%s\n' "$current_exports" | rg -q '^mbw_input_event_payload_'; then
  echo "found forbidden payload export symbol(s):" >&2
  printf '%s\n' "$current_exports" | rg '^mbw_input_event_payload_' >&2
  exit 1
fi

if rg -q 'native_input_event_payload_' "$ROOT/macos/ffi.mbt"; then
  echo "found forbidden payload binding(s) in macos/ffi.mbt" >&2
  rg -n 'native_input_event_payload_' "$ROOT/macos/ffi.mbt" >&2
  exit 1
fi

check_export_allowlist "macOS" "$ALLOWLIST" "$current_exports"

linux_exports="$(extract_exports_from "$ROOT/linux/native_wayland.c")"
check_export_allowlist "Linux" "$LINUX_ALLOWLIST" "$linux_exports"
check_binding_exports "Linux" "$linux_exports" "$ROOT"/linux/*.mbt
check_branch_exports "Linux" "$ROOT/linux/native_wayland.c"
check_branch_signatures "Linux" "$ROOT/linux/native_wayland.c"

windows_exports="$(extract_exports_from "$ROOT/windows/native_window.c" "$ROOT/windows/native_monitor.c")"
check_export_allowlist "Windows" "$WINDOWS_ALLOWLIST" "$windows_exports"
check_binding_exports "Windows" "$windows_exports" "$ROOT"/windows/*.mbt
check_branch_exports "Windows" "$ROOT/windows/native_window.c" "$ROOT/windows/native_monitor.c"
check_branch_signatures "Windows" "$ROOT/windows/native_window.c" "$ROOT/windows/native_monitor.c"

current_wrappers="$(
  perl -ne 'print "$1\n" if /^fn (native_[A-Za-z0-9_]+)\s*\(/' \
    "$ROOT/macos/ffi.mbt" | sort -u
)"

new_wrappers="$(comm -13 "$WRAPPER_ALLOWLIST" <(printf '%s\n' "$current_wrappers") || true)"
if [[ -n "$new_wrappers" ]]; then
  echo "found newly introduced native wrapper function(s) in macos/ffi.mbt:" >&2
  printf '%s\n' "$new_wrappers" >&2
  echo "ffi.mbt should keep only primitive bindings; update wrapper allowlist only after explicit review" >&2
  exit 1
fi

echo "FFI surface check passed"
