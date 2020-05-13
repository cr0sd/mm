#!/bin/bash

source ./bin/include
source ./bin/open

# Read this last, to overwrite settings
[ -f ./.mmrc ] && source ./.mmrc

# Config
check_dependencies
mm_init
useargs=0
[ $# -gt 0 ] && useargs=1

# MM main loop
main()
{

	# Open most recent archive
	open_archive "./arc/$(ls -t -1 ./arc | head -1)"

	# Menu loop
	while true; do

		# Don't use args
		if [ $useargs -eq 0 ]; then
			# Choose
			dialog --title "Memo Menu" --menu "Main Menu" $def_h $def_w 15 \
				New "" Edit "" Archive "" Search "" Config "" Quit "" \
				2> $tmpfile
			if [ $? -eq 0 ]; then
				retval=$(cat $tmpfile)
			else
				quit
			fi
		else
			# Arguments
			retval=$1
		fi

		useargs=0

		# Parse menu choice
		case $retval in

			# Create new file with path log/YY/DDD
			"new")
				;&
			"New")
				fndir=$logdir/"$(date +'%y')"
				[ ! -d $fndir ] && mkdir $fndir
				fn=$logdir/"$(date +'%y/%j')"
				z=1

				# Decide whether to open file
				if [ -f $fn ] ; then
					warn "Regular file $fn already exists. Open anyway?"
					[ $? -ne 0 ] && z=0
				fi

				# Open file
				if [ $z -eq 1 ]; then
					touch $fn
					prefix=""
					edit_file $fn
					spellcheck_file $fn
					#dialog --title "Spellcheck" --msgbox "Running spellcheck" $def_h $def_w
					#aspell check $fn
				#else
					#dialog --title "New file" --msgbox "File opening cancelled" $def_h $def_w
				fi

				;;

			# Find, edit already existing file
			"edit")
				;&
			"Edit")
				ls logs
				choose_open_file ./logs
				;;

			# Quit now
			"quit")
				;&
			"Quit")
				quit
				;;

			# Create archive of current logs/memos
			"archive")
				;&
			"Archive")
				datenow=$(date +'%s')
				fnbase="$arcdir/$logdir-$datenow"
				z=1

				# Warn if archive already exists
				if [ -f $fnbase.tar.gz ]; then
					warn "Archive '$fnbase.tar.gz' already exists. Overwrite?"
					if [ $? -eq 1 ]; then
						z=0
					else
						rm -f $fnbase.tar.gz
					fi
				fi

				# Create archive
				if [ $z -eq 1 ]; then

					# Output archiving process to dialog
					{
						echo "*Adding files to archive...";

						# Add all appropriate files to archive before compressing
						find logs -regex '.*[0-9]+' -type f -exec tar rfv $fnbase.tar {} + 2>&1;

						echo "";
						echo "*Compressing archive...";

						# Compress archive
						gzip -v $fnbase.tar 2>/dev/null >/dev/null;
						gzip -l $fnbase.tar.gz;

						echo "";
						echo "*Verifying archive...";

						# Verify file, keep only 10
						if [ -f $fnbase.tar.gz ]; then
							echo "Archive '$fnbase.tar.gz' created";

							echo "";
							echo "*Removing old archives...";

							# Remove extra archives
							arc_keep 10;

						else
							die "error: failed to create archive '$fnbase.tar.gz'";
						fi

						echo ""
						echo "Done.";

					}| dialog --title "Archive" --programbox "Archiving..." $def_h $def_w

					# Encrypt file if it exists
					echo "encrypting file yo"
					if [ -f $fnbase.tar.gz ]; then
						dialog --title "Archive" --msgbox "Encrypting '$fnbase.tar.gz' ==> '$fnbase.tar.gz.gpg'" $def_h $def_w
						gpg -c $fnbase.tar.gz
						rm $fnbase.tar.gz
					fi

				else
					dialog --title "Archive" --msgbox "Archive NOT created" \
							$def_h $def_w
				fi
				;;

			search)
				;&
			Search)

				dialog --title "Search" --inputbox "Search" $def_h $def_w "" 2> $tmpfile
				if [ $? -eq 0 ]; then

					searchterm=$(cat $tmpfile)

					files=$(find $logdir -type f -regex '.*[0-9]+' -exec grep -m 1 -lF "$searchterm" {} +) #| cut -c 1-32 | sed 's/\s\+/_/' > $tmpfile
					echo $files

					list=""
					for x in $files; do
						list+="$x "
						list+="$(grep -m 1 "$searchterm" $x|sed 's/\s\+/_/g'|cut -c 1-20) "
						list+="$x "
					done

					#quit 0

					if [ "$list" != "" ] && [ "$searchterm" != "" ]; then
						dialog --title "Search" --checklist "Search results" $def_h $def_w 15 $list 2> $tmpfile
						if [ $? -eq 0 ]; then
							$prefix=""
							$m=""
							fn="$(cat $tmpfile)"
							edit_file $fn
							spellcheck_file $fn
							#dialog --title "Spellcheck" --msgbox "Running spellcheck" $def_h $def_w
							#aspell check $fn
						#else
							#warn "Search cancelled!"
						fi
					else
						warn "No results!"
					fi
				#else
					#warn "Search cancelled"
				fi
				;;

			config)
				;&
			Config)

				cancel=0
				new_editor=""

				while true; do
					# Config menu
					dialog --title "Config" --menu "Config Menu" $def_h $def_w 15 \
						"Set editor" "$editor" "Logs directory" "'$logdir'" "Archive directory" "'$arcdir'" \
						"Toggle spellcheck" "$spellcheck" "Save settings" ""\
						2> $tmpfile
					[ $? -ne 0 ] && break

					# Choose editor
					if [ "$(cat $tmpfile)" = "Set editor" ]; then
						dialog --title "Config" --inputbox "Set editor" $def_h $def_w "$editor" 2> $tmpfile
						[ $? -ne 0 ] && cancel=1
						new_editor=$(cat $tmpfile | sed 's/\s/_/g')

						# Validate input
						while [ $cancel -eq 0 ]; do

							which "$new_editor" 2>&1 > /dev/null
							if [ $? -ne 0 ]; then
								# Did not find editor exe file
								dialog --title "Config" --inputbox "Error: Cannot find '$new_editor'. Set editor" \
									$def_h $def_w "$new_editor" 2> $tmpfile && new_editor=$(cat $tmpfile | sed 's/\s/_/g')
								if [ $? -ne 0 ]; then
									cancel=1
									break
								fi
							else
								# Found exe file for new_editor
								break
							fi
						done

						# Confirm choice
						if [ $cancel -eq 0 ]; then
							dialog --title "Config" --msgbox "Set editor from $editor to $new_editor" $def_h $def_w
							[ $? -ne 0 ] && cancel=1
							editor=$new_editor;
						else
							dialog --title "Config" --msgbox "Did not set editor. Reverting to $editor" $def_h $def_w
							[ $? -ne 0 ] && cancel=1
						fi

					# Menu entry: Change logfile directory
					elif [ "$(cat $tmpfile)" = "Logs directory" ]; then

						# Validate input
						while true; do

							dialog --title "Config" --inputbox "Set logs directory" \
								$def_h $def_w "$logdir" 2> $tmpfile

							# User exited, no change
							if [ $? -ne 0 ]; then
								dialog --title "Config" --msgbox "Did not set logs directory. Reverting to '$logdir'" $def_h $def_w
								break
							fi

							new_logdir="$(cat $tmpfile)"

							# New directory exists, change directory name
							if [ -d "$new_logdir" ] && [ "$new_logdir" != "" ]; then
								dialog --title "Config" --msgbox "Changing logfile directory from '$logdir' to '$new_logdir'" $def_h $def_w
								logdir=$new_logdir
								break
							fi
						done

					# Menu entry: Change logfile directory
					elif [ "$(cat $tmpfile)" = "Archive directory" ]; then

						# Validate input
						while true; do

							dialog --title "Config" --inputbox "Set archive directory" \
								$def_h $def_w "$arcdir" 2> $tmpfile

							# User exited, no change
							if [ $? -ne 0 ]; then
								dialog --title "Config" --msgbox "Did not set archive directory. Reverting to '$arcdir'" $def_h $def_w
								break
							fi

							new_arcdir="$(cat $tmpfile)"

							# New directory exists, change directory name
							if [ -d "$new_arcdir" ] && [ "$new_arcdir" != "" ]; then
								dialog --title "Config" --msgbox "Changing archive directory from '$arcdir' to '$new_arcdir'" $def_h $def_w
								arcdir=$new_arcdir
								break
							fi
						done

					# Menu entry: Save current config settings to .mmrc
					elif [ "$(cat $tmpfile)" = "Save settings" ]; then
						dialog --title "Config" --msgbox "Saving settings" $def_h $def_w
						echo "editor=$editor" > .mmrc
						echo "logdir="\""$logdir"\" >> .mmrc
						echo "arcdir="\""$arcdir"\" >> .mmrc
						echo "spellcheck="\""$spellcheck"\" >> .mmrc

					# Menu entry: Toggle spellcheck
					elif [ "$(cat $tmpfile)" = "Toggle spellcheck" ]; then
						if [ $spellcheck = "true" ]; then spellcheck="false"
						else spellcheck="true"; fi
					fi
				done

				;;

			help)
				;&
			Help)
				echo "usage: mm [new|edit|archive|config] [ARCHIVE]"
				quit 0
				;;

			*)
				if [ -f $1 ]; then
					#dialog --title "Open archive" --msgbox "'$1'" $def_h $def_w

					# Attempt to open file as archive
					open_archive $1
				else
					echo "error: unknown command or archive file '$1'"
					quit 1
				fi
				;;
		esac
	done
}

# Entry point
main $*
rem_logs
