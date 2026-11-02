# A `php` stand-in for builds whose PHP cannot run on the build machine, such as cross builds.
#
# ext-php-rs's build script runs `$PHP -i` for the PHP version, API version, thread safety and debug
# mode, and some extensions ask `php -r` whether PHP is a debug or ZTS build. The shim answers those
# from the headers that `$PHP_CONFIG --include-dir` (or `php-config` on PATH) points to.
{
  writeShellScriptBin,
  gnused,
}:

writeShellScriptBin "php" ''
  set -eu

  include="$(''${PHP_CONFIG:-php-config} --include-dir)"

  define() {
    ${gnused}/bin/sed -n "s/^#define $1 \(.*\)$/\1/p" "$include/$2" | ${gnused}/bin/sed -e '1!d' -e 's/"//g'
  }

  version="$(define PHP_VERSION main/php_version.h)"
  api="$(define PHP_API_VERSION main/php.h)"

  if [ "$(define ZTS main/php_config.h)" = 1 ]; then
    thread_safety=enabled
    zts_suffix=-zts
  else
    thread_safety=disabled
    zts_suffix=
  fi

  if [ "$(define ZEND_DEBUG main/php_config.h)" = 1 ]; then
    debug=yes
    debug_suffix=-debug
  else
    debug=no
    debug_suffix=
  fi

  case "$*" in
    -i | --info)
      printf 'PHP Version => %s\nPHP API => %s\nDebug Build => %s\nThread Safety => %s\n' \
        "$version" "$api" "$debug" "$thread_safety"
      ;;
    -v | --version)
      printf 'PHP %s (cli)\n' "$version"
      ;;
    '-n -r echo PHP_DEBUG ? "-debug" : "";')
      printf '%s\n' "$debug_suffix"
      ;;
    '-n -r echo ZEND_THREAD_SAFE ? "-zts" : "";')
      printf '%s\n' "$zts_suffix"
      ;;
    *)
      printf 'php shim: unsupported invocation (PHP cannot run on the build machine): php %s\n' "$*" >&2
      exit 1
      ;;
  esac
''
