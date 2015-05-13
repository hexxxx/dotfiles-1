#
# $Header: ${HOME}/functions.bash                       Exp $
# $Author: (c) 2011-015 -tclover <tokiclover@gmail.com> Exp $
# $License: MIT (or 2-clause/new/simplified BSD)        Exp $
# $Version: 2015/05/05 21:09:26                         Exp $
#

# @FUNCTION: hlper function, print error message to stdout
# @USAGE: <string>
function error {
	echo -e "\e[1;31m* \e[0m${0##*/}: $@" >&2

	[[ "$LOGGER" ]] && [[ "$facility" ]] && logger -p $facility "${0##*/}: $@"
}

# @FUNCTION: hlper function, print message and exit
# @USAGE: <string>
function die {
	local ret=$?
	error "$@"
	return $ret
}

# @FUNCTION: hlper function, print info message to stdout
# @USAGE: <string>
# @VERSION: 0.6
function info {
	echo -e "\e[1;32m \e[0m${0##*/}: $@"

	[[ "$LOGGER" ]] && [[ "$facility" ]] && logger -p $facility "${0##*/}: $@"
}

# @FUNCTION: Simple & Cheap checkpath/mktemp script
# @ARG: [-M] [-d|-f] [-m mode] [-o owner[:group]] TEMPLATE|DIR|FILE
function checkpath {
	function usage {
	cat <<-EOH
usage: checkpath [-p] [-d|-f] [-m mode] [-o owner[:group]] TEMPLATE|DIR|FILE
  -d, --dir           (Create a) directory
  -f, --file          (Create a) file
  -P, --pipe          (Create a) pipe (FIFO)
  -o, --owner <name>  Use owner name
  -g, --group <name>  Use group name
  -m, --mode <1700>   Use octal mode
  -c, --checkpath     Enable check mode
  -p, --tmpdir[=DIR]  Enable mktmp mode
  -q, --quiet         Enable quiet mode
  -h, --help          Help/Exit
EOH
return
}
	(( $# == 0 )) && usage
	local args temp=-XXXXXX type
	args="$(getopt \
		-o Pcdfg:hm:o:p::q \
		-l checkpath,dir,file,group:,tmpdir:: \
		-l help,mode:owner:,pipe,quiet \
		-s sh -n checkpath -- "$@")"
	(( $? == 0 )) || usage
	eval set -- $args
	args=

	local group mode owner task tmp quiet
	for (( ; $# > 1; )); do
		case $1 in
			(-c|--chec*) task=chk  ;;
			(-p|--tmpd*) task=tmp tmpdir="${2:-$TMPDIR}"; shift;;
			(-d|--dir) args=-d type=dir;;
			(-f|--file)  type=file ;;
			(-P|--pipe)  type=pipe ;;
			(-h|--help)  usage     ;;
			(-m|--mode)  mode="$2" ; shift;;
			(-o|--owner) owner="$2"; shift;;
			(-g|-group)  group="$2"; shift;;
			(-q|--quiet) quiet=true;;
			(*) shift; break       ;;
		esac
		shift
	done

	if ! [ $# -eq 1 -a -n "$1" ]; then
		die "Invalid argument(s)/TEMPLATE"
		return
	fi
	case "$task" in
		(tmp)
		quiet= tmpdir="${tmpdir:-${TEMPLATE:-/tmp}}"
		case "$1" in
			(*$temp) ;;
			(*) die "Invalid TEMPLATE"; return;;
		esac
		if type -p mktemp >/dev/null 2>&1; then
			tmp="$(mktemp -p "$tmpdir" $args "$1")"
		else
			type -p uuidgen >/dev/null 2>&1 && temp=$(uuidgen --random)
			tmp="$tmpdir/${1%-*}-$(echo "$temp" | cut -c-6)"
		fi
		;;
		(*)
		tmp="$1"
		;;
	esac
	case "$type" in
		(dir)
		[[ -d "$tmp" ]] || mkdir -p "$tmp"
		;;
		(*)
		[[ -e "$tmp" ]] || mkdir -p "${tmp%/*}" && break
		case "$type" in
			(pipe) mkfifo $tmp;;
			(file) touch  $tmp;;
		esac
		;;
	esac

	((  $? == 0 )) || { die "Failed to create ${tmp}"; return; }
	[[ -h "$tmp" ]] && return
	[[ "$owner" ]] && chown "$owner" "$tmp"
	[[ "$group" ]] && chgrp "$group" "$tmp"
	[[ "$mode"  ]] && chmod "$mode"  "$tmp"
	[[ "$quiet" ]] || echo "$tmp"
}

# ANSI color codes for bash_prompt function
declare -a COLORS CHARS
COLOR=(black red green yellow blue magenta cyan white)
SGR07=(reset bold faint italic underline sblink rblink inverse)

# @USAGE: bash_prompt [4-color]
# if 256 colors is suported, color can be in [0-255] range check out
# ref: http://www.calmar.ws/vim/256-xterm-24bit-rgb-color-chart.html
function bash_prompt {
	# Initialize colors arrays
	declare -A BG FG FB
	local B C E="\e[" F
	if (( $(tput colors) >= 256 )); then
		B="${E}48;5;"
		F="${E}1;38;5;"
		C="57 77 69 124"
	else
		B="${E}4"
		F="${E}1;3"
		C="4 6 5 2"
	fi

	(( $# >= 4 )) && C="$@"
	for (( c=1; c<5; c++ )); do
		BG[$c]="${B}${i}m"
		FG[$c]="${F}${i}m"
	done
	for (( i=0; i<8; i++ )); do
		FB[${SGR07[$i]}]="\e[${i}m"
	done

	# Check PWD length
	local PROMPT LENGTH TTY=$(tty | cut -b6-)
	PROMPT="---($USER$(uname -n):${TTY}---()---"
	if (( ${COLUMNS:-0} <= (${#PROMPT}+${#NPWD}+13) )); then
		PROMPT_DIRTRIM=$((${COLUMNS}-${#PROMPT}-16))
	fi

	# And the prompt
	case $TERM in
	(*xterm*|*rxvt*|linux|*term*)
		PS1="${FB[bold]}${FG[2]}-${FG[1]}(${FG[4]}\$·${FG[1]}${FG[4]}\h:$TTY${FG[1]}·\D{%m/%d}·${FG[4]}\t${FG[4]})${FG[1]}\
		(${FG[4]}\w${FG[1]})${FB[bold]}${FG[1]}${FG[2]}${FB[bold]}${FG[1]}${FG[3]}${FB[reset]}-» "

		PS2="${FG[1]}-» ${FB[reset]}"
		TITLEBAR="\$:\w"
	;;
	(*)
		PS1="${FG[1]}(${FG[4]}\$·${FG[1]}\D{%m/%d}${FG[4]}\h:$TTY:\w${FG[1]}${FG[4]}${FG[1]})${FB[reset]} "
	
		PS2="${FG[1]}-» ${FB[reset]}"
	;;
	esac
}
# @ENV_VARIABLE: bash prompt command
PROMPT_COMMAND=bash_prompt

# @FUNCTION: little helpter to retrieve Kernel Module Parameters
function kmod-pa {
	local c d line m mc mod md de n=/dev/null o
	c=$(tput op) o=$(echo -en "\n$(tput setaf 2)-*- $(tput op)")
	if [[ -n "$*" ]]
	then
		mod=($*)
	else
		while read line
		do
			mod+=( ${line%% *})
		done </proc/modules
	fi
	for m in ${mod[@]}
	do
		md=/sys/module/$m/parameters
		[[ ! -d $md ]] && continue
		d=$(modinfo -d $m 2>$n | tr '\n' '\t')
		echo -en "$o$m$c ${d:+:$d}"
		echo
		pushd $md >$n 2>&1
		for mc in *
		do
			de=$(modinfo -p $m 2>$n | grep ^$mc 2>$n | sed "s/^$mc=//" 2>$n)
			echo -en "\t$mc=$(cat $mc 2>$n) ${de:+ -$de}"
			echo
		done
		popd >$n 2>&1
	done
}

# @FUNCTION: colorful helper to retrieve Kernel Module Parameters
function kmod-pc {
	local green yellow cyan reset
	if [[ "$(tput colors)" -ge 8 ]]
	then
		green="\e[1;32m"
		yellow="\e[1;33m"
		cyan="\e[1;36m"
		reset="\e[0m"
	fi
	newline='
'

	local d line m mc md mod n=/dev/null
	if [[ -n "$*" ]]
	then
		mod=($*)
	else
		while read line
		do
			mod+=( ${line%% *})
		done </proc/modules
	fi
	for m in ${mod[@]}
	do
		md=/sys/module/$m/parameters
		[[ ! -d $md ]] && continue
		d="$(modinfo -d $m 2>$n | tr '\n' '\t')"
		echo -en "$green$m$reset"
		[[ ${#d} -gt 0 ]] && echo -n " - $d"
		echo
		declare pnames=() pdescs=() pvals=()
		local add_desc=false p pdesc pname
		while IFS="$newline" read p
		do
			if [[ $p =~ ^[[:space:]] ]]
			then
				pdesc+="$newline	$p"
			else
				$add_desc && pdescs+=("$pdesc")
				pname="${p%%:*}"
				pnames+=("$pname")
				pdesc=("	${p#*:}")
				pvals+=("$(cat $md/$pname 2>$n)")
			fi
			add_desc=true
		done < <(modinfo -p $m 2>$n)
		$add_desc && pdescs+=("$pdesc")
		for ((i=0; i<${#pnames[@]}; i++))
		do
			[[ -z ${pnames[i]} ]] && continue
			printf "\t$cyan%s$reset = $yellow%s$reset\n%s\n" \
			${pnames[i]} \
			"${pvals[i]}" \
			"${pdescs[i]}"
		done
		echo
	done
}

# @FUNCTION: generate a random password using openssl to stdout
function genpwd {
	openssl rand -base64 48
}

# @FUNCION: simple xev key code
function xev-key-code {
	xev | grep -A2 --line-buffered '^KeyRelease' | \
	sed -nre '/keycode /s/^.*keycode ([0-9]*).* (.*, (.*)).*$/\1 \2/p'
}

#
# vim:fenc=utf-8:ft=sh:ci:pi:sts=2:sw=2:ts=2:
#
