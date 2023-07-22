#!/bin/bash

metadata=0
variant=""
spotify_sender_id=""

dbus-monitor "path=/org/mpris/MediaPlayer2,member=PropertiesChanged"|while read line
do
    >&2 echo "---$line"
    is_signal=$(echo "$line" | grep -ce "^signal")

    if (( $is_signal )); then
        sender_id=$(echo "$line" | grep -oE "sender=[^ ]+" | cut -d= -f2)

        if [[ -n $spotify_sender_id ]]; then
            if [[ $sender_id = $spotify_sender_id ]]; then
                >&2 echo "caught signal from spotify"
                is_spotify=1
            else
                >&2 echo "caught signal from other sender"
                is_spotify=0
            fi
        elif [[ -z $spotify_sender_id ]]; then
            >&2 echo "caught signal from '$sender_id', cannot check if from spotify, \$spotify_sender_id is empty"
            is_spotify=1
        fi
    fi

    if (( ! $is_spotify )); then
        continue
    fi

    col=$(echo "$line" | awk -F '"' '{print $2}')
    if [[ "$col" == "org.mpris.MediaPlayer2.Player" ]]; then
        metadata=1
        variant=""
        echo "__SWITCH__"
    elif (($metadata)); then
        if [[ -n $(echo "$line"|grep "dict entry") ]]; then
            # emptying variant since we're entering a dict entry
            variant=""
        elif [[ -n $variant ]] && [[ $variant != 0 ]]; then
            if [[ -z $spotify_sender_id && $variant = "mpris:trackid" && -n $(echo $col | grep "spotify") ]]; then
                >&2 echo "track is from spotify, setting \$spotify_sender_id to $sender_id"
                spotify_sender_id=$sender_id
            fi

            if [[ -n $col ]]; then
                simplevariant=$(echo "$variant" | cut -d: -f2)
                echo "$simplevariant=$col"
                variant=0
            fi
        elif [[ -n $col ]]; then
            variant="$col"
            # echo "variant = $col"
        fi
    fi
done
