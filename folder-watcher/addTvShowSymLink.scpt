property scriptPath : "~/dev/plex-hacks/folder-watcher/tvshow-symlinks.pl"

on adding folder items to this_folder after receiving these_items
	try
		repeat with i from 1 to number of items in these_items
			set this_item to item i of these_items
			set scriptSrc to scriptPath & " " & quoted form of POSIX path of this_item
			try
				do shell script scriptSrc
			on error
				display dialog "Error"
			end try
		end repeat
	on error error_message number error_number
		tell application "Finder"
			activate
			display dialog error_message buttons {"Cancel"} default button 1 giving up after 120
		end tell
	end try
end adding folder items to
