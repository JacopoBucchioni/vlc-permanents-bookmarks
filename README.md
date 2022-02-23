# VLC Permanents Bookmarks
This VLC extension allows you to save bookmarks for your media files and store them permanently.

## Overview
The default `Custom Bookmarks` of vlc cannot be stored permanently without save a playlist file. If you close the media file, the bookmarks will disappear. So we need a bookmark management extension to store them permanently.

## Installation
Create a directory 'extensions' at this location if it doesn't exists, then download the `vlc_permanets_bookmarks.lua` file and place it in:

- Windows (all users): `program_files\VideoLAN\VLC\lua\extensions\`
- Windows (current user): `%APPDATA%\vlc\lua\extensions\`
- Linux (all users): `/usr/lib/vlc/lua/extensions/`
- Linux (current user): `~/.local/share/vlc/lua/extensions/`
- Mac OS X (all users):`/Applications/VLC.app/Contents/MacOS/share/lua/extensions/`
- Mac OS X (current user): `/Users/user_name/Library/Application\ Support/org.videolan.vlc/lua/extensions/`

Change `program_files` to the path of your vlc program
change  `user_name` to your username.

## Usage
#### Start extension:
- Start vlc and open a media like video, audio and even network stream
- Click on the menu `View > Bookmarks` or `VLC > Extension > Bookmarks` on Mac OS X
- And start adding bookmarks like the default `Custom Bookmarks` of vlc but permanently stored on file closure

## Feature
- The extension use an hash algorithm to associate bookmarks to the media files, so it works even if the files are moved or renamed, as long as their contents are not changed
