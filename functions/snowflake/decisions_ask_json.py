"""Vectorized Snowflake Python UDF: calls the Jev System One API.

Adapted from the Jevflake handler (MIT, Luke Kranz); see NOTICE.

Wire format: POST {"model", "state", "questions"} to URL with a Bearer key
(from the Snowflake secret "api_key"). Input frame column 0 is the state JSON,
column 1 the questions JSON. Output is a Series of '{"answers": {...}}' JSON
strings, or None for rows whose state is NULL or JSON null. Number and boolean
states are sent as their JSON text (a bare number or boolean state is rejected by the service).
"""

import json
import random
import time
from concurrent.futures import ThreadPoolExecutor

import pandas
import requests
from requests.adapters import HTTPAdapter

import _snowflake
from _snowflake import vectorized

MODEL = "jev-1.13.0"
ROWS_PER_REQUEST = 1
CONCURRENCY = 8
MAX_BATCH_SIZE = 64
MAX_RETRIES = 6
TIMEOUT_SECONDS = 30
URL = "https://api.typesafe.ai/v1/systemone"
BACKOFF_CAP_SECONDS = 20
RETRYABLE = (408, 429, 500, 502, 503, 504, 529)
REJECTED = (400, 413, 422)

session = requests.Session()
session.mount("https://", HTTPAdapter(pool_connections=CONCURRENCY, pool_maxsize=CONCURRENCY))


def pause(attempt, response=None):
    delay = min(BACKOFF_CAP_SECONDS, 2 ** attempt) * (0.5 + random.random() / 2)
    header = response.headers.get("retry-after") if response is not None else None
    if header:
        try:
            delay = max(delay, min(BACKOFF_CAP_SECONDS, float(header)))
        except ValueError:
            pass
    time.sleep(delay)


def post(payload, key):
    headers = {"Authorization": "Bearer " + key, "Content-Type": "application/json"}
    for attempt in range(MAX_RETRIES + 1):
        last = attempt == MAX_RETRIES
        try:
            response = session.post(URL, headers=headers, json=payload, timeout=TIMEOUT_SECONDS)
        except requests.RequestException:
            if last:
                raise
            pause(attempt)
            continue
        if response.status_code == 200:
            return response.json(), None
        detail = "HTTP %d: %s" % (response.status_code, response.text[:500])
        if response.status_code in REJECTED:
            return None, detail
        if response.status_code in RETRYABLE and not last:
            pause(attempt, response)
            continue
        raise RuntimeError("Jev request failed with " + detail)


def finish(answers, reported=None):
    for answer in answers.values():
        answer.setdefault("model", reported or MODEL)
    return answers


def failed(questions, message):
    return finish({name: {"type": "error", "error": message} for name in questions})


def ask_row(state, questions, key):
    body, error = post({"model": MODEL, "state": state, "questions": questions}, key)
    if error:
        return failed(questions, error)
    return finish(body.get("answers", {}), body.get("model"))


def scoped_question(question, index):
    scope = "Judge only the record at `rows.row_%d`." % index
    instructions = question.get("instructions")
    scoped = dict(question)
    if isinstance(instructions, str):
        scoped["instructions"] = scope + " " + instructions
    else:
        scoped["instructions"] = {"scope": scope, "task": instructions}
    return scoped


def ask_rows(states, questions, key):
    if len(states) == 1:
        return [ask_row(states[0], questions, key)]
    packed_state = {"rows": {"row_%d" % index: state for index, state in enumerate(states)}}
    packed_questions = {}
    for index in range(len(states)):
        for name, question in questions.items():
            packed_questions["row_%d__%s" % (index, name)] = scoped_question(question, index)
    body, error = post({"model": MODEL, "state": packed_state, "questions": packed_questions}, key)
    if error:
        return [ask_row(state, questions, key) for state in states]
    answers = body.get("answers", {})
    results = []
    for index in range(len(states)):
        row = {}
        for name in questions:
            missing = {"type": "error", "error": "Jev returned no answer for this row"}
            row[name] = answers.get("row_%d__%s" % (index, name), missing)
        results.append(finish(row, body.get("model")))
    return results


def run_job(job, key):
    questions, rows = job
    return ask_rows([state for _, state in rows], questions, key)


@vectorized(input=pandas.DataFrame, max_batch_size=MAX_BATCH_SIZE)
def main(frame):
    try:
        key = _snowflake.get_generic_secret_string("api_key")
    except Exception:
        raise RuntimeError(
            "dbt_decisions: decisions_ask_json has no secret attached (the dispatch stanza is probably "
            "missing from the root dbt_project.yml; add it, run dbt build, then dbt run-operation "
            "dbt_decisions.doctor)"
        ) from None
    results = [None] * len(frame)
    groups = {}
    for position, (state_json, questions_json) in enumerate(zip(frame[0], frame[1])):
        if pandas.isna(state_json) or pandas.isna(questions_json):
            continue
        state = json.loads(state_json)
        if state is None:
            continue
        if not isinstance(state, (str, dict, list)):
            state = json.dumps(state)
        groups.setdefault(questions_json, []).append((position, state))
    jobs = []
    for questions_json, rows in groups.items():
        questions = json.loads(questions_json)
        for start in range(0, len(rows), ROWS_PER_REQUEST):
            jobs.append((questions, rows[start:start + ROWS_PER_REQUEST]))
    with ThreadPoolExecutor(max_workers=CONCURRENCY) as pool:
        outcomes = pool.map(lambda job: run_job(job, key), jobs)
        for (questions, rows), answers in zip(jobs, outcomes):
            for (position, _), answer in zip(rows, answers):
                results[position] = json.dumps({"answers": answer})
    return pandas.Series(results, dtype="object")
