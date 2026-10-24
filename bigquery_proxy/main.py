"""BigQuery remote-function proxy for the Jev System One API.

Adapted from the Snowflake handler (functions/snowflake/decisions_ask_json.py; Jevflake, MIT, see NOTICE).

BigQuery POSTs {"calls": [[state, questions], ...], ...} and expects {"replies": [...]} with one entry per
call (measured: docs/superpowers/notes/2026-10-bigquery-probe.md). Each reply is {"answers": {...}}, or null
for a NULL state. The Jev key is read from the environment variable TYPESAFE_API_KEY (a Secret Manager secret).

The proxy's own request deadline (240 s, `DECISIONS_REQUEST_DEADLINE_SECONDS`) is below the service timeout
(300 s) so BigQuery gets a reply instead of a retry; concurrency 4 x 8 workers x max-instances 3 stays well
under TypeSafe's cap per Jevflake's docs.
"""

import json
import os
import random
import threading
import time
from concurrent.futures import ThreadPoolExecutor
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

import requests
from requests.adapters import HTTPAdapter

MODEL = "jev-1.13.0"
JEV_URL = os.environ.get("DECISIONS_JEV_URL", "https://api.typesafe.ai/v1/systemone")
CONCURRENCY = int(os.environ.get("DECISIONS_CONCURRENCY", "8"))
DEADLINE_SECONDS = float(os.environ.get("DECISIONS_REQUEST_DEADLINE_SECONDS", "240"))
MAX_RETRIES = 6
TIMEOUT_SECONDS = 30
BACKOFF_CAP_SECONDS = 20
RETRYABLE = (408, 429, 500, 502, 503, 504, 529)
AUTH_FAILED = (401, 403)

session = requests.Session()
session.mount("https://", HTTPAdapter(pool_connections=CONCURRENCY, pool_maxsize=CONCURRENCY))
session.mount("http://", HTTPAdapter(pool_connections=CONCURRENCY, pool_maxsize=CONCURRENCY))


class KeyRejected(Exception):
    pass


def pause(attempt, response=None, deadline=None):
    delay = min(BACKOFF_CAP_SECONDS, 2 ** attempt) * (0.5 + random.random() / 2)
    header = response.headers.get("retry-after") if response is not None else None
    if header:
        try:
            delay = max(delay, min(BACKOFF_CAP_SECONDS, float(header)))
        except ValueError:
            pass
    if deadline is not None:
        delay = min(delay, max(0.0, deadline - time.monotonic()))
    time.sleep(delay)


def post(payload, key, deadline=None):
    """Returns (body, None) or (None, error text). Raises KeyRejected on 401/403.

    No attempt starts after the deadline (time.monotonic value); pause never sleeps past it."""
    if deadline is None:
        deadline = time.monotonic() + DEADLINE_SECONDS
    headers = {"Authorization": "Bearer " + key, "Content-Type": "application/json"}
    detail = "no response"
    for attempt in range(MAX_RETRIES + 1):
        last = attempt == MAX_RETRIES
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            if attempt == 0:
                return None, "deadline reached before this row was sent; no Jev call made"
            return None, "deadline reached after %d attempt(s); last: %s" % (attempt, detail)
        try:
            response = session.post(JEV_URL, headers=headers, json=payload, timeout=min(TIMEOUT_SECONDS, remaining))
        except requests.RequestException as e:
            detail = "request failed: " + type(e).__name__
            if last:
                return None, detail
            pause(attempt, None, deadline)
            continue
        if response.status_code == 200:
            try:
                body = response.json()
            except ValueError:
                body = None
            if not isinstance(body, dict):
                return None, "HTTP 200: invalid JSON body: " + response.text[:500]
            return body, None
        detail = "HTTP %d: %s" % (response.status_code, response.text[:500])
        if response.status_code in AUTH_FAILED:
            raise KeyRejected("Jev rejected the API key (" + detail + ")")
        if response.status_code in RETRYABLE and not last:
            pause(attempt, response, deadline)
            continue
        return None, detail
    return None, detail


def finish(answers, reported=None):
    for answer in answers.values():
        answer.setdefault("model", reported or MODEL)
    return answers


def failed(questions, message):
    return finish({name: {"type": "error", "error": message} for name in questions})


def answer_call(call, key, deadline=None, stop=None):
    state, questions = call[0], call[1]
    if state is None or questions is None:
        return None
    try:
        if stop is not None and stop.is_set():
            return {"answers": failed(questions, "not sent: the Jev key was rejected; no Jev call made")}
        if not isinstance(state, (str, dict, list)):
            state = json.dumps(state)
        body, error = post({"model": MODEL, "state": state, "questions": questions}, key, deadline)
        if error:
            return {"answers": failed(questions, error)}
        return {"answers": finish(body.get("answers", {}), body.get("model"))}
    except KeyRejected:
        raise
    except Exception as e:
        try:
            return {"answers": failed(questions, "proxy error for this row: %s: %s" % (type(e).__name__, e))}
        except Exception:
            return {"answers": {}}


def handle_calls(calls, key, deadline=None):
    if deadline is None:
        deadline = time.monotonic() + DEADLINE_SECONDS
    stop = threading.Event()
    pool = ThreadPoolExecutor(max_workers=CONCURRENCY)
    futures = [pool.submit(answer_call, call, key, deadline, stop) for call in calls]
    try:
        return [f.result() for f in futures]
    except KeyRejected:
        stop.set()
        pool.shutdown(wait=True, cancel_futures=True)
        raise
    finally:
        pool.shutdown(wait=True)


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def send_json(self, status, obj):
        out = json.dumps(obj).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(out)))
        self.end_headers()
        self.wfile.write(out)

    def do_POST(self):
        deadline = time.monotonic() + DEADLINE_SECONDS
        try:
            calls = json.loads(self.rfile.read(int(self.headers.get("Content-Length", 0))))["calls"]
            if not isinstance(calls, list) or not all(isinstance(c, list) and len(c) >= 2 for c in calls):
                raise ValueError("calls must be a list of [state, questions]")
        except (ValueError, KeyError, TypeError) as e:
            return self.send_json(400, {"errorMessage": "bad request: " + str(e)})
        print(json.dumps({"n_calls": len(calls)}), flush=True)
        key = os.environ.get("TYPESAFE_API_KEY")
        if not key:
            return self.send_json(500, {"errorMessage": "TYPESAFE_API_KEY is not set on the proxy (mount the Secret Manager secret as that environment variable)"})
        try:
            replies = handle_calls(calls, key, deadline)
        except KeyRejected as e:
            return self.send_json(500, {"errorMessage": str(e)})
        except Exception as e:
            return self.send_json(500, {"errorMessage": "proxy error: %s: %s" % (type(e).__name__, e)})
        self.send_json(200, {"replies": replies})


def make_server(port):
    return ThreadingHTTPServer(("", port), Handler)


if __name__ == "__main__":
    make_server(int(os.environ.get("PORT", "8080"))).serve_forever()
