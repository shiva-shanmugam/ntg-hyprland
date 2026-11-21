#!/usr/bin/env bash
PIDFILE="/tmp/qs-ai-voice.pid"
WAVFILE="/tmp/qs-ai-voice.wav"

case "$1" in
  start)
    rm -f "$WAVFILE"
    pw-record --rate 16000 --channels 1 "$WAVFILE" &
    echo $! > "$PIDFILE"
    ;;
  stop)
    if [ -f "$PIDFILE" ]; then
      kill -INT "$(cat "$PIDFILE")" 2>/dev/null
      wait "$(cat "$PIDFILE")" 2>/dev/null
      rm -f "$PIDFILE"
    fi
    sleep 0.3
    [ -s "$WAVFILE" ] || exit 1
    curl -s http://127.0.0.1:8090/inference \
      -F file=@"$WAVFILE" \
      -F response_format=json \
      | python3 -c "import sys,json;print(json.load(sys.stdin).get('text','').strip())"
    ;;
esac
