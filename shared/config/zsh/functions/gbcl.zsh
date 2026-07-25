# Clean local branches that are merged or gone from origin.
# Skips branches with no upstream (never pushed). Removes matching worktrees too.
# Dry run by default. Pass -f to actually delete.
function gbcl() {
	if ! git rev-parse --git-dir >/dev/null 2>&1; then
		print -u2 "gbcl: not in a git repo"
		return 1
	fi

	# Colors (respect NO_COLOR + non-tty).
	local C_DIM C_BOLD C_RESET C_CYAN C_GREEN C_YELLOW C_RED C_MAGENTA
	if [[ -t 1 && -z "$NO_COLOR" ]]; then
		C_DIM=$'\e[2m'; C_BOLD=$'\e[1m'; C_RESET=$'\e[0m'
		C_CYAN=$'\e[36m'; C_GREEN=$'\e[32m'; C_YELLOW=$'\e[33m'
		C_RED=$'\e[31m'; C_MAGENTA=$'\e[35m'
	fi

	local force=0
	[[ "$1" == "-f" ]] && force=1

	printf "${C_DIM}  fetching…${C_RESET}\r"
	git fetch --all --prune >/dev/null 2>&1
	printf "          \r"

	local default_branch
	default_branch=$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null | sed 's@^origin/@@')
	if [[ -z "$default_branch" ]]; then
		for b in main master; do
			git show-ref --verify --quiet "refs/heads/$b" && { default_branch="$b"; break; }
		done
	fi
	[[ -z "$default_branch" ]] && default_branch="main"

	local current_branch
	current_branch=$(git branch --show-current)

	local -a gone_branches
	gone_branches=("${(@f)$(git for-each-ref --format='%(refname:short) %(upstream:track)' refs/heads | awk '$2=="[gone]"{print $1}')}")

	local -a merged_branches
	merged_branches=("${(@f)$(git for-each-ref --format='%(refname:short) %(upstream)' refs/heads | awk -v def="$default_branch" '$2!="" && $1!=def {print $1}')}")
	local -a merged_filtered
	for b in $merged_branches; do
		[[ -z "$b" ]] && continue
		git merge-base --is-ancestor "$b" "$default_branch" 2>/dev/null && merged_filtered+=("$b")
	done

	local -A seen
	local -a candidates
	for b in $gone_branches $merged_filtered; do
		[[ -z "$b" ]] && continue
		[[ "$b" == "$current_branch" ]] && continue
		[[ "$b" == "$default_branch" ]] && continue
		if [[ -z "${seen[$b]}" ]]; then
			seen[$b]=1
			candidates+=("$b")
		fi
	done

	local mode_label
	if (( force )); then
		mode_label="${C_RED}${C_BOLD}apply${C_RESET}"
	else
		mode_label="${C_YELLOW}dry-run${C_RESET}"
	fi
	print
	print "  ${C_BOLD}${C_MAGENTA}gbcl${C_RESET} ${C_DIM}·${C_RESET} $mode_label ${C_DIM}·${C_RESET} default ${C_CYAN}$default_branch${C_RESET}"
	print

	if (( ${#candidates} == 0 )); then
		print "  ${C_GREEN}✓${C_RESET} nothing to clean"
		print
		return 0
	fi

	# Branch -> worktree path.
	local -A wt_map
	local cur_path="" cur_branch=""
	while IFS= read -r line; do
		case "$line" in
			worktree\ *) cur_path="${line#worktree }" ;;
			branch\ refs/heads/*) cur_branch="${line#branch refs/heads/}"; wt_map[$cur_branch]="$cur_path" ;;
			"") cur_path=""; cur_branch="" ;;
		esac
	done < <(git worktree list --porcelain)

	# Compute branch column width.
	local maxw=0
	for b in $candidates; do (( ${#b} > maxw )) && maxw=${#b}; done
	(( maxw < 12 )) && maxw=12

	local wt_count=0
	for b in $candidates; do [[ -n "${wt_map[$b]}" ]] && (( wt_count++ )); done

	for b in $candidates; do
		local reason=""
		[[ " ${gone_branches[*]} " == *" $b "* ]] && reason="gone"
		[[ " ${merged_filtered[*]} " == *" $b "* ]] && reason="${reason:+$reason+}merged"
		local wt="${wt_map[$b]}"
		local wt_display="${wt/#$HOME/~}"
		[[ -z "$wt" ]] && wt_display="${C_DIM}—${C_RESET}"

		local reason_color="$C_YELLOW"
		[[ "$reason" == "gone" ]] && reason_color="$C_RED"
		[[ "$reason" == "merged" ]] && reason_color="$C_GREEN"

		if (( force )); then
			if [[ -n "$wt" ]]; then
				git worktree remove --force "$wt" >/dev/null 2>&1 \
					&& print "  ${C_GREEN}✓${C_RESET} worktree  ${C_DIM}${wt_display}${C_RESET}" \
					|| print "  ${C_RED}✗${C_RESET} worktree  ${wt_display} ${C_DIM}(remove failed)${C_RESET}"
			fi
			if git branch -D "$b" >/dev/null 2>&1; then
				printf "  ${C_GREEN}✓${C_RESET} branch    %-${maxw}s  ${reason_color}%s${C_RESET}\n" "$b" "$reason"
			else
				printf "  ${C_RED}✗${C_RESET} branch    %-${maxw}s  ${C_DIM}delete failed${C_RESET}\n" "$b"
			fi
		else
			printf "  ${C_DIM}•${C_RESET} %-${maxw}s  ${reason_color}%-13s${C_RESET}  ${C_DIM}%s${C_RESET}\n" "$b" "$reason" "$wt_display"
		fi
	done

	print
	if (( force )); then
		print "  ${C_GREEN}${C_BOLD}done${C_RESET} ${C_DIM}·${C_RESET} ${#candidates} branch$([[ ${#candidates} -ne 1 ]] && echo es), $wt_count worktree$([[ $wt_count -ne 1 ]] && echo s)"
	else
		print "  ${C_DIM}${#candidates} branch$([[ ${#candidates} -ne 1 ]] && echo es), $wt_count worktree$([[ $wt_count -ne 1 ]] && echo s) · re-run with${C_RESET} ${C_BOLD}gbcl -f${C_RESET} ${C_DIM}to apply${C_RESET}"
	fi
	print
}
