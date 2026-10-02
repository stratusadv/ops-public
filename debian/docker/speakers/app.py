import hmac
import os
import subprocess
import tempfile
import threading

import numpy
import torch

from typing import BinaryIO

from fastapi import Depends, FastAPI, Header, HTTPException, UploadFile
from pyannote.audio import Pipeline
from pyannote.core import Annotation


AUDIO_SECONDS_MAX = 6 * 60 * 60
MODEL_NAME = 'pyannote/speaker-diarization-community-1'
SAMPLE_RATE_HZ = 16000
TURN_COUNT_MAX = AUDIO_SECONDS_MAX * 10
UPLOAD_BYTES_MAX = 2 * 1024 * 1024 * 1024
UPLOAD_CHUNK_BYTES = 1024 * 1024
UPLOAD_CHUNK_COUNT_MAX = UPLOAD_BYTES_MAX // UPLOAD_CHUNK_BYTES

api_key = os.environ.get('VLLM_API_KEY', '')
app = FastAPI()
pipeline = Pipeline.from_pretrained(MODEL_NAME, token=os.environ.get('HF_TOKEN') or None)
pipeline_lock = threading.Lock()

pipeline.to(torch.device('cuda'))


def api_key_verify(authorization: str = Header(default='')) -> None:
    if not api_key:
        return

    expected = f'Bearer {api_key}'

    if not hmac.compare_digest(authorization.encode(), expected.encode()):
        message = 'The API key is missing or wrong.'
        raise HTTPException(status_code=401, detail=message)


@app.post('/v1/audio/diarization', dependencies=[Depends(api_key_verify)])
def diarization(file: UploadFile) -> dict[str, list[dict[str, float | int]]]:
    with tempfile.NamedTemporaryFile() as upload:
        diarization_upload_copy(source=file.file, target=upload)
        upload.flush()

        waveform = diarization_waveform_decode(upload.name)

    with pipeline_lock:
        audio = {'waveform': waveform, 'sample_rate': SAMPLE_RATE_HZ}
        output = pipeline(audio)

    turns = diarization_turns(output.exclusive_speaker_diarization)

    return {'turns': turns}


def diarization_turns(annotation: Annotation) -> list[dict[str, float | int]]:
    if len(annotation) > TURN_COUNT_MAX:
        message = f'invariant violated: {len(annotation)} turns exceed {TURN_COUNT_MAX}'
        raise RuntimeError(message)

    labels = {}
    turns = []

    for segment, speaker in annotation:
        if segment.start < 0.0:
            message = f'invariant violated: a turn starts before zero: {segment.start}'
            raise RuntimeError(message)

        if segment.end <= segment.start:
            message = f'invariant violated: a turn ends before it starts: {segment}'
            raise RuntimeError(message)

        speaker_index = labels.setdefault(speaker, len(labels))
        start_seconds = round(segment.start, 3)
        end_seconds = round(segment.end, 3)
        turn = {'speaker': speaker_index, 'start': start_seconds, 'end': end_seconds}
        turns.append(turn)

    return turns


def diarization_upload_copy(*, source: BinaryIO, target: BinaryIO) -> None:
    if target.tell() != 0:
        message = f'invariant violated: the upload target starts at byte {target.tell()}'
        raise RuntimeError(message)

    size_bytes = 0

    for _ in range(UPLOAD_CHUNK_COUNT_MAX + 1):
        chunk = source.read(UPLOAD_CHUNK_BYTES)

        if not chunk:
            return

        size_bytes += len(chunk)

        if size_bytes > UPLOAD_BYTES_MAX:
            message = f'The upload is larger than {UPLOAD_BYTES_MAX} bytes.'
            raise HTTPException(status_code=413, detail=message)

        written_bytes = target.write(chunk)

        if written_bytes != len(chunk):
            message = f'invariant violated: wrote {written_bytes} of {len(chunk)} bytes'
            raise RuntimeError(message)

    message = f'invariant violated: the upload ran past {UPLOAD_CHUNK_COUNT_MAX} chunks'
    raise RuntimeError(message)


def diarization_waveform_decode(path: str) -> torch.Tensor:
    if not os.path.isfile(path):
        message = f'invariant violated: the upload is not a file: {path}'
        raise RuntimeError(message)

    command = [
        'ffmpeg',
        '-nostdin',
        '-v',
        'error',
        '-i',
        path,
        '-t',
        str(AUDIO_SECONDS_MAX + 1),
        '-ac',
        '1',
        '-ar',
        str(SAMPLE_RATE_HZ),
        '-f',
        'f32le',
        '-',
    ]

    completed = subprocess.run(command, capture_output=True, check=False)

    if completed.returncode != 0:
        message = 'The upload is not audio that ffmpeg can read.'
        raise HTTPException(status_code=400, detail=message)

    samples = numpy.frombuffer(completed.stdout, dtype=numpy.float32)

    if samples.size == 0:
        message = 'The upload holds no audio.'
        raise HTTPException(status_code=400, detail=message)

    if samples.size > AUDIO_SECONDS_MAX * SAMPLE_RATE_HZ:
        message = f'The recording is longer than {AUDIO_SECONDS_MAX // 3600} hours.'
        raise HTTPException(status_code=413, detail=message)

    return torch.from_numpy(samples.copy()).unsqueeze(0)


@app.get('/health')
def health() -> dict[str, str]:
    return {'status': 'ok'}
