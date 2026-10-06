"""One feed, decoded on its own.

Each feed gets its own ffmpeg that turns the HLS stream into raw 720p frames
and PCM. A feed that stalls or dies only takes its own ffmpeg with it: the
compositor keeps getting frames from everything else, and this feed's tile
shows its last frame, then a slate, while it is restarted.
"""

import collections
import os
import subprocess
import threading
import time

FRAME_W = 1280
FRAME_H = 720
FRAME_BYTES = FRAME_W * FRAME_H * 3 // 2
AUDIO_RATE = 48000
AUDIO_BYTES_PER_SECOND = AUDIO_RATE * 4

TICK = 0.25
# Last frame stays up this long before the tile says it's reconnecting
FREEZE_SECONDS = 3
# No frames for this long and the ffmpeg is replaced
RESTART_AFTER = 6
STARTUP_TIMEOUT = 20
MAX_BACKOFF = 15
# A run that lasted this long resets the backoff
STABLE_SECONDS = 20
VIDEO_QUEUE = 3
# Audio beyond this is latency, not buffer: trim back to keep lips in sync
AUDIO_MAX_SECONDS = 0.3
AUDIO_TRIM_SECONDS = 0.1

_NO_AUDIO_MARKERS = ("matches no streams", "does not contain any stream")


def build_command(ffmpeg, source, audio_fd, fps):
    cmd = [ffmpeg, "-hide_banner", "-nostdin", "-loglevel", "error"]
    if source.startswith(("http://", "https://")):
        cmd += ["-rw_timeout", "10000000"]
    cmd += [
        "-live_start_index", "-3",
        "-fflags", "+genpts+discardcorrupt",
        "-re",
        "-i", source,
        "-map", "0:v:0",
        "-vf", (f"scale={FRAME_W}:{FRAME_H}:force_original_aspect_ratio=decrease,"
                f"pad={FRAME_W}:{FRAME_H}:(ow-iw)/2:(oh-ih)/2,setsar=1,fps={fps},format=yuv420p"),
        "-an", "-f", "rawvideo", "pipe:1",
    ]
    if audio_fd is not None:
        cmd += [
            "-map", "0:a:0", "-vn",
            "-af", "aresample=async=1000", "-ac", "2", "-ar", str(AUDIO_RATE),
            "-f", "s16le", f"pipe:{audio_fd}",
        ]
    return cmd


class Ingest:
    def __init__(self, source, settings, name="feed", popen=subprocess.Popen, clock=time.monotonic):
        self.source = source
        self.name = name
        self._ffmpeg = settings.get("ffmpeg", "ffmpeg")
        self._fps = settings.get("fps", 30)
        self._popen = popen
        self._clock = clock

        self.status = "starting"  # starting | live | reconnecting
        self.error = ""
        self.restarts = 0
        self.has_audio = True

        self._frames = collections.deque(maxlen=VIDEO_QUEUE)
        self._audio = bytearray()
        self._lock = threading.Lock()
        self._stop = threading.Event()
        self._proc = None
        self._run_started = 0.0
        self._last_frame_at = None
        self._ever_live = False
        self._failures = 0
        self._next_start = 0.0
        self._stderr = collections.deque(maxlen=8)
        self._thread = threading.Thread(target=self._run, name=f"ingest-{name}", daemon=True)

    # ------------------------------------------------------------------

    def start(self):
        self._thread.start()

    def stop(self):
        self._stop.set()
        if self._thread.is_alive() and threading.current_thread() is not self._thread:
            self._thread.join(timeout=5)
        self._kill()

    def take_video(self):
        """The next decoded frame, or None when nothing new has arrived."""
        with self._lock:
            return self._frames.popleft() if self._frames else None

    def take_audio(self, size):
        """Exactly size bytes of PCM, padded with silence when short."""
        with self._lock:
            chunk = bytes(self._audio[:size])
            del self._audio[:size]
        if len(chunk) < size:
            chunk += bytes(size - len(chunk))
        return chunk

    def showing_live(self):
        """Whether the tile should show this feed's picture (live or briefly frozen)."""
        last = self._last_frame_at
        return last is not None and self._clock() - last < FREEZE_SECONDS

    # ------------------------------------------------------------------

    def _run(self):
        try:
            while not self._stop.is_set():
                self._tick()
                self._stop.wait(TICK)
        finally:
            self._kill()

    def _tick(self):
        now = self._clock()
        proc = self._proc
        if proc is None:
            if now >= self._next_start:
                self._launch()
        elif proc.poll() is not None:
            self._proc = None
            self._on_exit(proc.returncode)
        else:
            if self._last_frame_at is None or self._last_frame_at < self._run_started:
                if now - self._run_started > STARTUP_TIMEOUT:
                    self._fail("no picture from the feed")
            elif now - self._last_frame_at > RESTART_AFTER:
                self._fail("feed stalled")

        if self.showing_live():
            self.status = "live"
            self._ever_live = True
            self.error = ""
        elif self._ever_live or self.restarts:
            self.status = "reconnecting"

    def _launch(self):
        audio_r = audio_w = None
        if self.has_audio:
            audio_r, audio_w = os.pipe()
        cmd = build_command(self._ffmpeg, self.source, audio_w, self._fps)
        self._stderr.clear()
        try:
            proc = self._popen(cmd, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
                               stderr=subprocess.PIPE, pass_fds=(audio_w,) if audio_w is not None else ())
        except OSError as exc:
            for fd in (audio_r, audio_w):
                if fd is not None:
                    os.close(fd)
            self.error = f"could not start ffmpeg: {exc}"
            self._schedule_retry()
            return
        if audio_w is not None:
            os.close(audio_w)
        self._proc = proc
        self._run_started = self._clock()
        threading.Thread(target=self._read_video, args=(proc,), daemon=True).start()
        threading.Thread(target=self._read_stderr, args=(proc,), daemon=True).start()
        if audio_r is not None:
            threading.Thread(target=self._read_audio, args=(audio_r,), daemon=True).start()

    def _on_exit(self, code):
        tail = " | ".join(self._stderr)
        if self.has_audio and any(marker in tail for marker in _NO_AUDIO_MARKERS):
            self._log("no audio stream; decoding picture only")
            self.has_audio = False
            self._next_start = self._clock()
            return
        self._log(f"ffmpeg exited ({code}){': ' + tail if tail else ''}")
        self.error = self._stderr[-1] if self._stderr else f"ffmpeg exited with code {code}"
        self._schedule_retry()

    def _fail(self, reason):
        self._log(f"{reason}; restarting")
        self.error = reason
        self._kill()
        self._schedule_retry()

    def _schedule_retry(self):
        now = self._clock()
        if self._run_started and now - self._run_started >= STABLE_SECONDS:
            self._failures = 0
        self._failures += 1
        self.restarts += 1
        self._next_start = now + min(MAX_BACKOFF, 2 ** (self._failures - 1))

    def _kill(self):
        proc = self._proc
        self._proc = None
        if proc is None or proc.poll() is not None:
            return
        proc.kill()
        try:
            proc.wait(timeout=4)
        except subprocess.TimeoutExpired:
            pass

    # ------------------------------------------------------------------

    def _read_video(self, proc):
        stream = proc.stdout
        try:
            while True:
                frame = stream.read(FRAME_BYTES)
                if len(frame) < FRAME_BYTES:
                    break
                with self._lock:
                    self._frames.append(frame)
                self._last_frame_at = self._clock()
        except (OSError, ValueError):
            pass
        finally:
            stream.close()

    def _read_audio(self, fd):
        limit = int(AUDIO_MAX_SECONDS * AUDIO_BYTES_PER_SECOND) // 4 * 4
        keep = int(AUDIO_TRIM_SECONDS * AUDIO_BYTES_PER_SECOND) // 4 * 4
        try:
            while True:
                data = os.read(fd, 65536)
                if not data:
                    break
                with self._lock:
                    self._audio += data
                    if len(self._audio) > limit:
                        del self._audio[:len(self._audio) - keep]
        except OSError:
            pass
        finally:
            os.close(fd)

    def _read_stderr(self, proc):
        try:
            for raw in proc.stderr:
                line = raw.decode("utf-8", "replace").strip()
                if line:
                    self._stderr.append(line)
        except (OSError, ValueError):
            pass
        finally:
            proc.stderr.close()

    def _log(self, message):
        print(f"[ingest {self.name}] {message}", flush=True)
