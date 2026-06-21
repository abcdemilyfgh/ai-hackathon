# chris 🎬

A desktop chatbot for video creators. Point it at a folder of clips and it
indexes them in the background — transcribing, auto-tagging, summarizing, and
flagging editing issues (filler words, repeated phrases) — then lets you chat
naturally to find and reason about your footage.

## What it does
- 📁 Point at a folder — reads videos in place (nothing uploaded/copied)
- 🎙 Auto-transcribes every clip with Deepgram
- 🏷 Auto-tags + summarizes each clip with Claude
- ⚠️ Flags filler words and repeated phrases
- 🔍 Searchable list (filename, tag, summary)
- 💬 Chat that reasons across the whole clip index
- 📄 Detail view with inline-highlighted transcript
- ⚡ On-disk caching for instant relaunches

## Architecture
macOS SwiftUI app → Cloudflare Worker proxy → Claude (/chat) + Deepgram (/transcribe).
API keys live as Cloudflare secrets, never in the app or repo.

## Tech
SwiftUI · Cloudflare Workers · Anthropic Claude · Deepgram · ffmpeg
