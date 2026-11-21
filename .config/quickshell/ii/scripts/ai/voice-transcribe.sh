#!/usr/bin/env bash
set -euo pipefail
umask 077

if [[ ${1:-} == record ]]; then
    wav="$(mktemp --suffix=.wav "${XDG_RUNTIME_DIR:-/tmp}/qs-ai-voice.XXXXXXXX")"
    printf '%s\n' "$wav"
    exec pw-record --rate 16000 --channels 1 --format s16 "$wav"
fi

if [[ ${1:-} == discard ]]; then
    if [[ ${2:-} == "${XDG_RUNTIME_DIR:-/tmp}"/qs-ai-voice.????????.wav ]]; then
        rm -f -- "$2"
    fi
    exit
fi

if [[ ${1:-} != transcribe || -z ${2:-} ]]; then
    echo 'Usage: voice-transcribe.sh record | transcribe WAV | discard WAV' >&2
    exit 2
fi

wav="$2"
if [[ $wav == "${XDG_RUNTIME_DIR:-/tmp}"/qs-ai-voice.????????.wav ]]; then
    trap 'rm -f -- "$wav"' EXIT
fi
if [[ ! -s $wav ]]; then
    echo 'No audio was recorded.' >&2
    exit 1
fi

model="$HOME/.local/share/whisper.cpp/models/ggml-base.en.bin"
if [[ ! -r $model ]]; then
    echo 'The local English Whisper model is missing.' >&2
    exit 1
fi

cli="$HOME/.local/libexec/graphite-assistant/whisper-cli"
if [[ ! -x $cli ]]; then
    cli="$(command -v whisper-cli || true)"
fi
if [[ -z $cli ]]; then
    echo 'A local Whisper CLI is required for dictation.' >&2
    exit 1
fi

timeout 90s "$cli" --model "$model" --file "$wav" --no-gpu --language en \
    --no-timestamps --no-prints --threads 4 |
    sed 's/^[[:space:]]*//; /^$/d'
