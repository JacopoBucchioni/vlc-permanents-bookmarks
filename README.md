# VLC Permanents Bookmarks 🏷️
This VLC extension allows you to save bookmarks for your media files and store them permanently.

## Overview
The default `Bookmark` of vlc cannot be stored permanently. If you close the media file, the bookmarks will disappear. So we need a bookmark management extension to store the bookmarks permanently.

## Installation
Create a directory 'extensions' at this location if it doesn't exists, then download the `vlc_permanets_bookmarks.lua` file and place it in:

- Windows (all users): `program_files\VideoLAN\VLC\lua\extensions\`
- Windows (current user): `%APPDATA%\vlc\lua\extensions\`
- Linux (all users): `/usr/lib/vlc/lua/extensions/`
- Linux (current user): `~/.local/share/vlc/lua/extensions/`
- Mac OS X (all users):`/Applications/VLC.app/Contents/MacOS/share/lua/extensions/`
- Mac OS X (current user): `/Users/user_name/Library/Application\ Support/org.videolan.vlc/lua/extensions/`

Change program_files to the path of your vlc program
change  `user_name` to your username.

## Usage
#### Start extension:
- Start vlc and your video
- Click on the menu `View > Bookmarks` or `VLC > Extension > Bookmarks` on Mac OS X
