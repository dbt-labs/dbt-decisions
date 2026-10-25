import json
import socket
import subprocess
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

import pytest

SERVER = Path(__file__).parent / "server.py"


def _free_port():
    with socket.socket() as s:
        s.bind(("127.0.0.1", 0))
        return s.getsockname()[1]


@pytest.fixture
def server(tmp_path):
    port = _free_port()
    log = tmp_path / "log.jsonl"
    proc = subprocess.Popen(
        [sys.executable, str(SERVER), "--port", str(port), "--log", str(log)]
    )
    try:
        deadline = time.time() + 10
        while True:
            try:
                socket.create_connection(("127.0.0.1", port), timeout=0.2).close()
                break
            except OSError:
                if proc.poll() is not None or time.time() > deadline:
                    raise RuntimeError("mock server did not start")
                time.sleep(0.05)
        yield {"url": f"http://127.0.0.1:{port}", "log": log}
    finally:
        proc.terminate()
        try:
            proc.wait(timeout=5)
        except subprocess.TimeoutExpired:
            proc.kill()
            proc.wait()


def post(srv, payload, path="/v1/systemone"):
    req = urllib.request.Request(
        srv["url"] + path,
        data=json.dumps(payload).encode(),
        headers={"Content-Type": "application/json"},
    )
    with urllib.request.urlopen(req, timeout=15) as r:
        return r.status, r.read()


def ask(srv, rows, questions, condition="c", path="/v1/systemone"):
    qs = {f"q{i}": q for i, q in enumerate(questions)}
    _, body = post(srv, {"state": {"condition": condition, "rows": rows}, "questions": qs}, path)
    return json.loads(body)


def test_noul(server):
    rows = [{"t": "please cancel"}, {"t": "hello"}, {"t": "all DONE"}]
    r = ask(server, rows, [{"type": "noul", "criteria": "x"}] * 3)
    assert r["model"] == "jev-mock"
    assert [r["answers"][f"q{i}"]["noul"] for i in range(3)] == [0.9, 0.1, 0.9]
    assert r["answers"]["q0"]["type"] == "noul"


def test_choice(server):
    opts = {"billing": "b", "technical": "t", "sales": "s"}
    q = {"type": "choice", "criteria": opts}
    r = ask(server, [{"t": "I was charged twice"}, {"t": "it will crash"}, {"t": "zzz"}], [q] * 3)
    a = r["answers"]
    assert a["q0"]["choice"] == "billing"
    assert a["q1"]["choice"] == "technical"
    row_json = json.dumps({"t": "zzz"}, sort_keys=True, ensure_ascii=False)
    exp = list(opts)[len(row_json) % 3]
    assert a["q2"]["choice"] == exp
    assert a["q2"]["probabilities"] == {o: 1.0 if o == exp else 0.0 for o in opts}
    assert a["q2"]["confidence"] == round(0.5 + ((len(row_json) + 3) % 5) / 10, 1)
    # keyword label not among options -> fallback
    r = ask(server, [{"t": "charged"}], [{"type": "choice", "criteria": {"x": "", "y": ""}}])
    assert r["answers"]["q0"]["choice"] in ("x", "y")


def test_score_range_and_fractional(server):
    for n in (2, 3, 10):
        rows = [{"t": "x" * i} for i in range(60)]
        q = {"type": "score", "criteria": [f"l{j}" for j in range(n)]}
        r = ask(server, rows, [q] * len(rows))
        scores = [r["answers"][f"q{i}"]["score"] for i in range(len(rows))]
        assert all(0 <= s <= n - 1 for s in scores)
        if n > 2:
            assert any(s != int(s) for s in scores)
        a = r["answers"]["q5"]
        k = round(a["score"])
        assert a["probabilities"][str(k)] == 1.0
        assert sum(a["probabilities"].values()) == 1.0
        assert a["legend"]["0"] == "l0"


def test_confidence_varies_with_row_and_noul_has_none(server):
    rows = [{"t": "zzz"}, {"t": "a much longer row of text"}]
    lens = [len(json.dumps(r, sort_keys=True, ensure_ascii=False)) for r in rows]
    exp = [round(0.5 + ((n + 2) % 5) / 10, 1) for n in lens]  # choice, 2 options
    exp_s = [round(0.5 + ((n + 3 + 2) % 5) / 10, 1) for n in lens]  # score, 3 levels
    assert exp[0] != exp[1] and exp != exp_s
    qs = [{"type": "choice", "criteria": {"a": "", "b": ""}}] * 2
    a = ask(server, rows, qs)["answers"]
    assert [a["q0"]["confidence"], a["q1"]["confidence"]] == exp
    qs = [{"type": "score", "criteria": ["l0", "l1", "l2"]}] * 2
    a = ask(server, rows, qs)["answers"]
    assert [a["q0"]["confidence"], a["q1"]["confidence"]] == exp_s
    assert all(0.0 <= c <= 1.0 for c in exp)
    a = ask(server, rows, [{"type": "noul", "criteria": "x"}] * 2)["answers"]
    assert all("confidence" not in a[k] for k in a)


def test_faults(server):
    for cond, code in (("trigger500", 500), ("trigger429", 429)):
        with pytest.raises(urllib.error.HTTPError) as e:
            post(server, {"state": {"condition": cond, "rows": [{}]},
                          "questions": {"q0": {"type": "noul", "criteria": ""}}})
        assert e.value.code == code
    status, body = post(server, {"state": {"condition": "triggerbad", "rows": [{}]},
                                 "questions": {"q0": {"type": "noul", "criteria": ""}}})
    assert status == 200
    with pytest.raises(ValueError):
        json.loads(body)
    t = time.time()
    r = ask(server, [{}], [{"type": "noul", "criteria": ""}], condition="triggersleep")
    assert time.time() - t >= 4.9
    assert "q0" in r["answers"]


def test_log_and_paths(server):
    q = {"type": "noul", "criteria": ""}
    ask(server, [{"a": 1}], [q], condition="one")
    ask(server, [{"a": 1}, {"a": 2}], [q, {"type": "score", "criteria": ["a", "b"]}],
        condition="two", path="/local/v1/systemone")
    with pytest.raises(urllib.error.HTTPError):
        post(server, {"state": {}, "questions": {}}, "/other")
    with pytest.raises(urllib.error.HTTPError):
        ask(server, [{}], [q], condition="trigger500")
    lines = [json.loads(x) for x in server["log"].read_text().splitlines()]
    assert [l["n_rows"] for l in lines] == [1, 2, 1]  # fault request logged too
    assert lines[1]["path"] == "/local/v1/systemone"
    assert lines[1]["condition"] == "two"
    assert lines[1]["types"] == ["noul", "score"]
    assert lines[1]["rows"] == [{"a": 1}, {"a": 2}]


def test_alignment(server):
    rows = [{"t": "cancel"}, {"t": "x"}, {"t": "done"}, {"t": "y"}]
    r = ask(server, rows, [{"type": "noul", "criteria": ""}] * 4)
    assert [r["answers"][f"q{i}"]["noul"] for i in range(4)] == [0.9, 0.1, 0.9, 0.1]


def _raw(srv, data, path="/v1/systemone"):
    req = urllib.request.Request(srv["url"] + path, data=data,
                                 headers={"Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=15) as r:
            return r.status, r.read()
    except urllib.error.HTTPError as e:
        return e.code, e.read()


def _good(srv):
    r = ask(srv, [{"t": "cancel"}], [{"type": "noul", "criteria": ""}])
    assert r["answers"]["q0"]["noul"] == 0.9


def _st(rows, questions):
    return json.dumps({"state": {"condition": "c", "rows": rows}, "questions": questions}).encode()


NOUL = {"type": "noul", "criteria": ""}
BAD_REQUESTS = {
    "invalid_json": b"{not json",
    "missing_state": json.dumps({"questions": {}}).encode(),
    "missing_questions": json.dumps({"state": {"condition": "c", "rows": []}}).encode(),
    "bad_question_id": _st([{}], {"x0": NOUL}),
    "row_out_of_range": _st([{}], {"q1": NOUL}),
    "missing_type": _st([{}], {"q0": {"criteria": ""}}),
    "missing_choice_criteria": _st([{}], {"q0": {"type": "choice"}}),
    "missing_score_criteria": _st([{}], {"q0": {"type": "score"}}),
    "unicode_digit_id": _st([{}], {"q\u0663": NOUL}),
    "empty_choice": _st([{}], {"q0": {"type": "choice", "criteria": {}}}),
    "empty_score": _st([{}], {"q0": {"type": "score", "criteria": []}}),
    "unknown_type": _st([{}], {"q0": {"type": "bogus", "criteria": ""}}),
}


@pytest.mark.parametrize("name", list(BAD_REQUESTS))
def test_bad_requests_return_400(server, name):
    status, body = _raw(server, BAD_REQUESTS[name])
    assert status == 400
    assert json.loads(body)["error"]
    _good(server)


@pytest.mark.parametrize("q", [{"type": "noul"}, {"type": "noul", "criteria": None}])
def test_noul_criteria_optional(server, q):
    status, body = _raw(server, _st([{"t": "cancel"}], {"q0": q}))
    assert status == 200
    assert json.loads(body)["answers"]["q0"]["noul"] == 0.9


def test_bad_content_length(server):
    host, port = server["url"].replace("http://", "").split(":")
    with socket.create_connection((host, int(port)), timeout=5) as s:
        s.sendall(b"POST /v1/systemone HTTP/1.1\r\nHost: x\r\nContent-Length: abc\r\n\r\n")
        data = s.recv(4096)
    assert data.startswith(b"HTTP/1.1 400")
    _good(server)


def test_real_extension_request_shape(server):
    """The real DuckDB jev extension sends ids r<N>, no criteria on noul, 'instructions' text, a 'model' field."""
    req = {"model": "jev-latest", "state": {"condition": "Is it?", "rows": ["cancel it", "fine"]},
           "questions": {"r0": {"type": "noul", "instructions": "x"}, "r1": {"type": "noul", "instructions": "x"}}}
    status, body = _raw(server, json.dumps(req).encode())
    assert status == 200
    a = json.loads(body)["answers"]
    assert a["r0"]["noul"] == 0.9 and a["r1"]["noul"] == 0.1


def test_log_records_instructions(server):
    req = {"state": {"rows": ["x"]}, "questions": {"r0": {"type": "choice", "instructions": "Pick Q", "criteria": {"a": None}}}}
    status, _ = _raw(server, json.dumps(req).encode())
    assert status == 200
    line = json.loads(server["log"].read_text().splitlines()[-1])
    assert line["instructions"] == ["Pick Q"] and line["types"] == ["choice"]
