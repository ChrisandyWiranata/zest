#!/usr/bin/env python3
"""Generate MP3 audio for every distinct vocabulary reading (pre-generated TTS).

Alur:
  1. Baca API_URL/TOKEN/VOICEVOX_SPEAKER_ID dari .env.
  2. Query Turso: SELECT DISTINCT read FROM vocabularies.
  3. Untuk tiap bacaan: audio_query -> synthesis (VOICEVOX lokal, WAV) ->
     ffmpeg transkode MP3 64k => assets/audio/{sha}<12>.mp3.
  4. Tulis assets/audio/index.json: {"bacaan": "hash.mp3"}.  Resumable.

Butuh: VOICEVOX jalan (127.0.0.1:50021) + ffmpeg di PATH.
Contoh: python3 tool/generate_tts.py
"""

import hashlib
import json
import os
import subprocess
import sys
import tempfile
import urllib.error
import urllib.parse
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

VOICEVOX_BASE = os.environ.get("VOICEVOX_BASE_URL", "http://127.0.0.1:50021").strip()
VOICEVOX_BASE = VOICEVOX_BASE.rstrip("/")

ROOT = Path(__file__).resolve().parent.parent
ASSET_DIR = ROOT / "assets" / "audio"
INDEX_PATH = ASSET_DIR / "index.json"

WORKERS = 4


def load_env() -> dict:
    env: dict = {}
    path = ROOT / ".env"
    if not path.exists():
        print("!.env tidak ditemukan — berhenti")
        sys.exit(1)
    for line in path.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, _, value = line.partition("=")
        env[key.strip()] = value.strip()
    return env


def query_distinct_reads(api_url: str, token: str) -> list:
    body = {
        "requests": [
            {
                "type": "execute",
                "stmt": {
                    "sql": (
                        "SELECT DISTINCT read FROM vocabularies "
                        "WHERE read IS NOT NULL AND length(trim(read)) > 0"
                    )
                },
                "args": [],
            }
        ]
    }
    req = urllib.request.Request(
        api_url,
        data=json.dumps(body).encode(),
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
        },
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=30) as resp:
        data = json.load(resp)
    rows = data["results"][0]["response"]["result"]["rows"]
    return [r[0]["value"] for r in rows if r and r[0] and r[0].get("value")]


def http_json(path: str) -> dict:
    url = f"{VOICEVOX_BASE}{path}"
    req = urllib.request.Request(
        url, headers={"Content-Type": "application/json"}, method="POST"
    )
    with urllib.request.urlopen(req, timeout=30) as resp:
        return json.load(resp)


def http_bytes(path: str, payload: dict) -> bytes:
    url = f"{VOICEVOX_BASE}{path}"
    req = urllib.request.Request(
        url,
        data=json.dumps(payload).encode(),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=30) as resp:
        return resp.read()


def wav_to_mp3(wav: bytes) -> bytes:
    with tempfile.NamedTemporaryFile(suffix=".wav") as tmp:
        tmp.write(wav)
        tmp.flush()
        proc = subprocess.run(
            [
                "ffmpeg",
                "-y",
                "-loglevel",
                "error",
                "-i",
                tmp.name,
                "-codec:a",
                "libmp3lame",
                "-b:a",
                "64k",
                "-ar",
                "24000",
                "-ac",
                "1",
                "-f",
                "mp3",
                "pipe:1",
            ],
            capture_output=True,
            check=True,
        )
        return proc.stdout


def synth_mp3(text: str, speaker: int) -> bytes:
    query = http_json(f"/audio_query?text={urllib.parse.quote(text)}&speaker={speaker}")
    wav = http_bytes(f"/synthesis?speaker={speaker}", query)
    return wav_to_mp3(wav)


def main() -> None:
    env = load_env()
    api_url = env.get("API_URL", "")
    token = env.get("TOKEN", "")
    speaker = int(env.get("VOICEVOX_SPEAKER_ID", "2").strip() or 2)
    if not api_url or not token:
        print("!.env harus punya API_URL dan TOKEN")
        sys.exit(1)

    ASSET_DIR.mkdir(parents=True, exist_ok=True)
    index: dict = {}
    if INDEX_PATH.exists():
        index = json.loads(INDEX_PATH.read_text())

    readings = [r.strip() for r in query_distinct_reads(api_url, token) if r.strip()]
    todo = [r for r in readings if r not in index]
    print(f"total bacaan={len(readings)} sudah={len(readings) - len(todo)} belum={len(todo)}")
    if not todo:
        print("semua sudah tergenerate — selesai")
        return

    done = 0
    errors: list[str] = []

    def process(read: str) -> None:
        nonlocal done
        key = hashlib.sha256(read.encode()).hexdigest()[:12]
        mp3_path = ASSET_DIR / f"{key}.mp3"
        try:
            if not mp3_path.exists():
                mp3_path.write_bytes(synth_mp3(read, speaker))
            index[read] = f"{key}.mp3"
        except (urllib.error.HTTPError, urllib.error.URLError, subprocess.CalledProcessError) as e:
            errors.append(f"{read}: {e}")
        done += 1
        if done % 25 == 0 or done == len(todo):
            print(f"... {done}/{len(todo)} (error: {len(errors)})", flush=True)
            INDEX_PATH.write_text(json.dumps(index, ensure_ascii=False, indent=1, sort_keys=True))

    with ThreadPoolExecutor(max_workers=WORKERS) as pool:
        list(pool.map(process, todo))

    INDEX_PATH.write_text(json.dumps(index, ensure_ascii=False, indent=1, sort_keys=True))
    total_bytes = sum(p.stat().st_size for p in ASSET_DIR.glob("*.mp3"))
    print(f"selesai: {len(index)} kata, file={len(list(ASSET_DIR.glob('*.mp3')))} "
          f"total={total_bytes/1e6:.1f} MB, error={len(errors)}")
    if errors:
        print("contoh error:")
        for e in errors[:10]:
            print(" ", e)


if __name__ == "__main__":
    main()