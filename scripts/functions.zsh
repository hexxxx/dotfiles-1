# $Id: $HOME/scripts/functions.zsh,v 2014/07/07 11:59:26 -tclover Exp $

# @FUNCTION: error
# @DESCRIPTION: hlper function, print message to stdout
# @USAGE: <string>
fuction error() {
	$LOG && logger -p $facility.err -t ${(%):-%1x}: $@
	print -P "${(%):-%1x}: ${(%):-%1x}: %B%F{red}*%b%f $@"
}

# @FUNCTION: die
# @DESCRIPTION: hlper function, print message and exit
# @USAGE: <string>
function die() {
  local ret=$?
  print -P "%F{red}*%f $@"
  exit $ret
}

# @FUNCTION: info
# @DESCRIPTION: hlper function, print message to stdout
# @USAGE: <string>
function info() {
	$LOG && logger -p $facility.err -t ${(%):-%1x}: $@
	print -P "${(%):-%1x}: %B%F{green}*%b%f $@"
}

# @FUNCTION: mktmp
# @DESCRIPTION: make tmp dir or file in ${TMPDIR:-/tmp}
# @ARG: -d|-f [-m <mode>] [-o <owner[:group]>] [-g <group>] TEMPLATE
function mktmp() {
	local type mode owner group tmp TMP=${TMPDIR:-/tmp}
	while [[ $# > 1 ]] {
		case $1 in
			-d) type=dir; shift;;
			-f) type=file; shift;;
			-m) mode=$2; shift 2;;
			-o) owner=$2; shitf 2;;
			-g) group=$2; shift 2;;
		 	*) tmp=$1; shift;;
		esac
	}
	[[ -n $tmp ]] && TMP+=/$tmp-XXXXXX ||
	die "mktmp: no $tmp TEMPLATE provided"
	if [[ $type == "dir" ]] {
		mkdir -p ${mode:+-m$mode} $TMP ||
		die "mktmp: failed to make $TMP"
	} else {
		mkdir -p $TMP:h &&
		echo >$TMP || die "mktmp: failed to make $TMP"
		[[ -n $mode ]] && chmod $mode $TMP
	}
	[[ -n $owner ]] && chown $owner $TMP
	[[ -n $group ]] && chgrp $group $TMP
	print "$TMP"
}

# vim:fenc=utf-8:ft=zsh:ci:pi:sts=0:sw=2:ts=2:
