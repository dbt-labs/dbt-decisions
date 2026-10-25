#!/usr/bin/env python3
"""Deterministic mock of a Jev-compatible /v1/systemone decision server (no auth).

Adapted from pg-jev test/mock_api.py (see NOTICE). Rules:
  noul   -> 0.9 if row JSON contains "cancel" or "done" (case-insensitive) else 0.1
  choice -> keyword label if present among options, else options[len(row_json) % len(options)]
  score  -> (len(row_json) % (10*(n-1)+1)) / 10, in [0, n-1]; probabilities one-hot on round(score)
  choice/score answers carry confidence = round(0.5 + ((len(row_json) + n + (2 if score else 0)) % 5) / 10, 1), n = option/level count; noul has none
Fault modes via state.condition substrings: trigger500, trigger429, triggerbad, triggersleep.
Run: python3 server.py --port 8765 --log requests.jsonl
"""
import argparse
import json
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

KEYWORD_CHOICES = {"charged": "billing", "crash": "technical", "pricing": "sales"}
PATHS = ("/v1/systemone", "/local/v1/systemone")

_LOG_LOCK = threading.Lock()
LOG_PATH = None


def noul(row_json):
    t = row_json.lower()
    return 0.9 if any(k in t for k in ("cancel", "done")) else 0.1


def choice(row_json, options):
    t = row_json.lower()
    for kw, label in KEYWORD_CHOICES.items():
        if kw in t and label in options:
            return label
    return options[len(row_json) % len(options)]


def score(row_json, n):
    return (len(row_json) % (10 * (n - 1) + 1)) / 10


def confidence(row_json, kind, n):
    """kind is 'choice' or 'score'; n is the option / level count. Mixing both in makes a swapped column detectable."""
    return round(0.5 + ((len(row_json) + n + (2 if kind == 'score' else 0)) % 5) / 10, 1)


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"  # keep-alive

    def log_message(self, *a):
        pass

    def do_POST(self):
        try:
            length = int(self.headers.get("Content-Length", 0))
            if length < 0:
                raise ValueError
        except ValueError:
            self.close_connection = True
            return self._send(400, {"error": "invalid Content-Length header"})
        body = self.rfile.read(length)
        if self.path not in PATHS:
            return self._send(404, {"error": "not found"})
        try:
            req = json.loads(body)
        except ValueError as e:
            return self._send(400, {"error": f"invalid JSON body: {e}"})
        if not isinstance(req, dict) or not isinstance(req.get("state"), dict):
            return self._send(400, {"error": "missing or invalid 'state' object"})
        if not isinstance(req.get("questions"), dict):
            return self._send(400, {"error": "missing or invalid 'questions' object"})
        state, questions = req["state"], req["questions"]
        rows = state.get("rows", [])
        cond = state.get("condition", "")
        if not isinstance(rows, list):
            return self._send(400, {"error": "'state.rows' must be a list"})
        if not isinstance(cond, str):
            return self._send(400, {"error": "'state.condition' must be a string"})
        self._log(cond, rows, questions)
        if "trigger500" in cond:
            return self._send(500, {"error": "mock server error"})
        if "trigger429" in cond:
            return self._send(429, {"error": "mock rate limit"})
        if "triggerbad" in cond:
            return self._send_raw(200, b"<<not json>>")
        if "triggersleep" in cond:
            time.sleep(5)
        try:
            answers = self._answer(rows, questions)
        except ValueError as e:
            return self._send(400, {"error": str(e)})
        self._send(200, {"model": "jev-mock", "answers": answers,
                         "usage": {"input_tokens": len(body) // 4, "output_tokens": len(answers)}})

    def _answer(self, rows, questions):
        answers = {}
        for qid, q in questions.items():
            if not (isinstance(qid, str) and qid[:1] in ("q", "r") and qid[1:].isdecimal()):
                raise ValueError(f"bad question id {qid!r}: expected 'q<N>' or 'r<N>'")
            i = int(qid[1:])
            if i >= len(rows):
                raise ValueError(f"question {qid} refers to row {i} but only {len(rows)} rows given")
            if not isinstance(q, dict) or "type" not in q:
                raise ValueError(f"question {qid} missing 'type'")
            row_json = json.dumps(rows[i], sort_keys=True, ensure_ascii=False)
            if q["type"] == "noul":
                answers[qid] = {"type": "noul", "noul": noul(row_json)}
            elif q["type"] == "score":
                levels = q.get("criteria")
                if not isinstance(levels, list) or not levels:
                    raise ValueError(f"question {qid}: score criteria must be a non-empty list")
                s = score(row_json, len(levels))
                k = round(s)
                answers[qid] = {
                    "type": "score", "score": s,
                    "legend": {str(j): l for j, l in enumerate(levels)},
                    "probabilities": {str(j): (1.0 if j == k else 0.0) for j in range(len(levels))},
                    "confidence": confidence(row_json, "score", len(levels)),
                }
            elif q["type"] == "choice":
                if not isinstance(q.get("criteria"), dict) or not q.get("criteria"):
                    raise ValueError(f"question {qid}: choice criteria must be a non-empty object")
                opts = list(q.get("criteria").keys())
                c = choice(row_json, opts)
                answers[qid] = {
                    "type": "choice", "choice": c,
                    "probabilities": {o: (1.0 if o == c else 0.0) for o in opts},
                    "confidence": confidence(row_json, "choice", len(opts)),
                }
            else:
                raise ValueError(f"question {qid}: unknown type {q['type']!r}")
        return answers

    def _log(self, cond, rows, questions):
        if not LOG_PATH:
            return
        line = json.dumps({"path": self.path, "condition": cond, "n_rows": len(rows),
                           "rows": rows, "types": [q.get("type") if isinstance(q, dict) else None for q in questions.values()],
                           "instructions": [q.get("instructions") if isinstance(q, dict) else None for q in questions.values()]},
                          ensure_ascii=False)
        with _LOG_LOCK:
            with open(LOG_PATH, "a", encoding="utf-8") as f:
                f.write(line + "\n")

    def _send(self, code, obj):
        self._send_raw(code, json.dumps(obj).encode())

    def _send_raw(self, code, data):
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)


def main():
    global LOG_PATH
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--port", type=int, default=8765)
    ap.add_argument("--host", default="127.0.0.1")
    ap.add_argument("--log", default=None, help="append JSONL request log here")
    args = ap.parse_args()
    LOG_PATH = args.log
    ThreadingHTTPServer((args.host, args.port), Handler).serve_forever()


if __name__ == "__main__":
    main()
