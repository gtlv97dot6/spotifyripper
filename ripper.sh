#!/bin/bash

script_dir=$(dirname $(readlink -f $0))
buffer_file=tmp.mp3

if [[ -z $1 ]]; then
  musicdir="."
else
  musicdir=$1
fi

# Get the client index of Spotify
spotify=$(pactl list sink-inputs | while read line; do
  [[ -n $(echo $line | grep "Sink Input #") ]] && index=$line
  [[ -n $(echo $line | grep Spotify) ]] && echo $index && exit
done | cut -d# -f2)

if [[ -z $spotify ]]; then
  echo "Spotify is not running"
  exit
fi

# Determine if spotify.monitor is already set up
if [[ -z $(pactl list short | grep spotify.monitor) ]]; then
  pactl load-module module-null-sink 'sink_name=spotify'
fi

# Move Spotify sound output back to default at exit
# pasink=$(pactl stat | grep Sink | cut -d: -f2)
pasink=$(pactl get-default-sink)
trap 'pactl move-sink-input $spotify $pasink' EXIT

# Move Spotify to its own sink so recorded output will not get corrupted
pactl move-sink-input $spotify spotify

$script_dir/notify.sh 2>/dev/null | while read line
do
  if [[ $line == "__SWITCH__" ]]; then
    killall ffmpeg 2>/dev/null
    killall parec 2>/dev/null

    if [[ -n $title ]]; then
      # Sanitize filenames
      saveto="$musicdir/${artist//\/ /}/${album//\/ /}"
      echo "Saved song $title by $artist to $saveto/${title//\/ /}.ogg"
      if [[ ! -a $saveto ]]; then
        mkdir -p "$saveto"
      fi
      ffmpeg -i $buffer_file -metadata "artist=$artist" -metadata "album=$album" \
            -metadata "title=$title" -metadata "tracknumber=$tracknumber" \
            "$saveto/${title//\/ /}.mp3"
      rm $buffer_file
      if [[ -s cover.jpg ]] && [[ ! -a "$saveto/cover.jpg" ]]; then
        mv cover.jpg "$saveto/cover.jpg"
      fi
      artist=""
      album=""
      title=""
      tracknumber=""
      rm -f cover.jpg
    fi
    echo "RECORDING"
    parec -d spotify.monitor | ffmpeg -y -ac 2 -f s16le -i pipe: -b:a 320k $buffer_file \
      &disown
    trap 'pactl move-sink-input $spotify $pasink && killall ffmpeg && killall parec' EXIT

  else
    variant=$(echo "$line"|cut -d= -f1)
    string=$(echo "$line"|cut -d= -f2)
    if [[ $variant == "artist" ]]; then
      artist="$string"
      echo "Artist = $string"
    elif [[ $variant == "title" ]]; then
      title="$string"
      echo "Title = $string"
    elif [[ $variant == "album" ]]; then
      album="$string"
      echo "Album = $string"
    elif [[ $variant == "url" ]]; then
      # Get the track number and download the coverart using an outside script
      tracknumber="$($script_dir/trackify.sh $string)"
      echo "Track number = $tracknumber"
    fi
  fi
done
