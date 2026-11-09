#!/usr/bin/env python3
"""Servidor falso do Roblox Open Cloud para testar o ideias.sh sem chave real.

Valida o que o Roblox exige de verdade: cabeçalho x-api-key, Content-Type
coerente com o conteúdo (rbxl binário x rbxlx XML), corpo não vazio, JSON da
tarefa Luau com o campo "script". Registra tudo em mock_log.json.
"""
import json
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer

KEY = sys.argv[2] if len(sys.argv) > 2 else "chave-de-teste"
LOG = []
STATE = {"version": 4, "polls": 0}


class H(BaseHTTPRequestHandler):
    def log_message(self, *a):
        pass

    def _send(self, code, obj):
        body = json.dumps(obj).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _body(self):
        n = int(self.headers.get("Content-Length", "0"))
        return self.rfile.read(n) if n else b""

    def _auth(self):
        if self.headers.get("x-api-key") != KEY:
            self._send(401, {"code": "Unauthorized", "message": "Invalid API Key"})
            return False
        return True

    def do_POST(self):
        body = self._body()
        entry = {"method": "POST", "path": self.path, "ctype": self.headers.get("Content-Type"), "size": len(body)}
        LOG.append(entry)
        json.dump(LOG, open("mock_log.json", "w"), indent=1)
        if not self._auth():
            return
        if "/versions?versionType=" in self.path:
            binary = body.startswith(b"<roblox!")
            ctype = self.headers.get("Content-Type", "")
            if len(body) == 0 or (binary and ctype != "application/octet-stream") or (not binary and ctype != "application/xml"):
                return self._send(400, {"code": "InvalidRequest", "message": "Invalid Content stream"})
            STATE["version"] += 1
            return self._send(200, {"versionNumber": STATE["version"]})
        if self.path.endswith("/luau-execution-session-tasks"):
            data = json.loads(body)
            if "script" not in data or len(data["script"]) < 10:
                return self._send(400, {"message": "script vazio"})
            entry["script_bytes"] = len(data["script"])
            json.dump(LOG, open("mock_log.json", "w"), indent=1)
            base = self.path.split("/cloud/v2/")[1].replace("/luau-execution-session-tasks", "")
            return self._send(200, {"path": base + "/luau-execution-sessions/s1/tasks/t1", "state": "QUEUED"})
        self._send(404, {"message": "rota desconhecida"})

    def do_PATCH(self):
        body = self._body()
        LOG.append({"method": "PATCH", "path": self.path, "ctype": self.headers.get("Content-Type"), "size": len(body), "has_request": b'"published": false' in body})
        json.dump(LOG, open("mock_log.json", "w"), indent=1)
        if not self._auth():
            return
        self._send(200, {"path": "operations/op123"})

    def do_GET(self):
        LOG.append({"method": "GET", "path": self.path})
        json.dump(LOG, open("mock_log.json", "w"), indent=1)
        if not self._auth():
            return
        if self.path.endswith("/logs"):
            return self._send(200, {"luauExecutionSessionTaskLogs": [{"messages": ["[nuvem] interpretador: 2454 ok / 0 falhas"]}]})
        if "/tasks/t1" in self.path:
            STATE["polls"] += 1
            if STATE["polls"] < 2:
                return self._send(200, {"state": "PROCESSING"})
            return self._send(200, {"state": "COMPLETE", "output": {"results": [{"ok": True, "interpretador": {"passou": 2454, "falhou": 0}}]}})
        if self.path.endswith("/operations/op123"):
            return self._send(200, {"path": "operations/op123", "done": True, "response": {"path": "assets/1", "revisionId": "7", "isPublished": False}})
        self._send(404, {"message": "rota desconhecida"})


if __name__ == "__main__":
    HTTPServer(("127.0.0.1", int(sys.argv[1])), H).serve_forever()
