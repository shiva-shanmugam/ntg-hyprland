"""Transport, attachment encoding and local history for the Assistant panel."""
import base64
import json
import mimetypes
import os
from pathlib import Path
import re
import stat
import sys
import tempfile
import urllib.error
import urllib.parse
import urllib.request

OLLAMA = "http://127.0.0.1:11434"
LOOPBACK = {"localhost", "127.0.0.1", "::1"}
TEXT_LIMIT = 128 * 1024
IMAGE_LIMIT = 8 * 1024 * 1024
CHAT_NAME = re.compile(r"[\w][\w .-]{0,79}", re.ASCII)


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, request, fp, code, msg, headers, newurl):
        return None


def client(local_only):
    handlers = [NoRedirect()]
    if local_only:
        handlers.append(urllib.request.ProxyHandler({}))
    return urllib.request.build_opener(*handlers)


def connect(endpoint, data=None, headers=None, local_only=False):
    url = urllib.parse.urlsplit(endpoint)
    if url.scheme not in {"http", "https"} or not url.hostname or url.username or url.password:
        raise ValueError("Invalid model endpoint.")
    if local_only and url.hostname.lower() not in LOOPBACK:
        raise ValueError("Only loopback endpoints are allowed in local mode.")
    if url.hostname.lower() not in LOOPBACK and url.scheme != "https":
        raise ValueError("Cloud model endpoints must use HTTPS.")
    body = None if data is None else json.dumps(data).encode()
    request = urllib.request.Request(
        endpoint, body, {"Content-Type": "application/json", **(headers or {})}
    )
    return client(local_only or url.hostname.lower() in LOOPBACK).open(request, timeout=45 if body else 4)


def discover():
    with connect(OLLAMA + "/api/tags", local_only=True) as response:
        tags = json.load(response).get("models", [])
    models = []
    for tag in tags:
        name = tag["name"]
        # Cloud-only Ollama entries must never be advertised as offline models.
        if name.endswith(("-cloud", ":cloud")) or tag.get("remote_host") or tag.get("remote_model"):
            continue
        try:
            with connect(OLLAMA + "/api/show", {"model": name}, local_only=True) as response:
                info = json.load(response)
        except (OSError, ValueError):
            continue
        model_info = info.get("model_info", {})
        if info.get("remote_host") or info.get("remote_model") or model_info.get("remote_host"):
            continue
        capabilities = info.get("capabilities", [])
        if "completion" in capabilities:
            fixed_reasoning = (
                name == "qwen3:4b" and "thinking" in capabilities
                and re.search(r"\$\.Think\b", info.get("template", "")) is None
            )
            models.append({"model": name, "capabilities": capabilities, "fixedReasoning": fixed_reasoning})
    print(json.dumps(models))


def read_attachment(path, supports_images):
    name = Path(path).name
    if not Path(path).is_absolute() or not Path(path).is_file():
        raise ValueError(f"Attachment is missing or is not a regular file: {name}")
    mime, _ = mimetypes.guess_type(name)
    image_mimes = {"image/png", "image/jpeg", "image/webp"}
    is_image = mime in image_mimes
    if is_image and not supports_images:
        raise ValueError(f"This model does not accept images: {name}")
    limit = IMAGE_LIMIT if is_image else TEXT_LIMIT
    fd = os.open(path, os.O_RDONLY | os.O_NONBLOCK)
    with os.fdopen(fd, "rb") as source:
        if not stat.S_ISREG(os.fstat(source.fileno()).st_mode):
            raise ValueError(f"Attachment is not a regular file: {name}")
        data = source.read(limit + 1)
    if len(data) > limit:
        raise ValueError(f"Attachment exceeds {limit // 1024} KiB: {name}")
    if is_image:
        valid = {
            "image/png": data.startswith(b"\x89PNG\r\n\x1a\n"),
            "image/jpeg": data.startswith(b"\xff\xd8\xff"),
            "image/webp": data.startswith(b"RIFF") and data[8:12] == b"WEBP",
        }
        if not valid[mime]:
            raise ValueError(f"Image contents do not match the file type: {name}")
        return mime, base64.b64encode(data).decode()
    try:
        text = data.decode("utf-8-sig")
        if "\0" in text:
            raise ValueError
    except ValueError:
        raise ValueError(f"Use a UTF-8 text file, PNG, JPEG, or WebP: {name}") from None
    return "", f"\n\nAttachment ({name}):\n{text}"


def attach(packet):
    data = packet["data"]
    provider = packet["provider"]
    for attachment in packet["attachments"]:
        mime, value = read_attachment(attachment["path"], packet["images"])
        index = attachment["index"]
        if provider == "gemini":
            part = {"inline_data": {"mime_type": mime, "data": value}} if mime else {"text": value}
            data["contents"][index]["parts"].append(part)
        else:
            message = data["messages"][index + 1]
            if not mime:
                message["content"] += value
            elif provider == "ollama":
                message["images"] = [value]
            else:
                message["content"] = [
                    {"type": "text", "text": message["content"]},
                    {"type": "image_url", "image_url": {"url": f"data:{mime};base64,{value}"}},
                ]


def request():
    packet = json.load(sys.stdin)
    endpoint = packet["endpoint"]
    provider = packet["provider"]
    local_only = packet["localOnly"]
    key = os.environ.get("ASSISTANT_API_KEY", "")
    headers = {}
    if provider == "gemini":
        endpoint += ("&" if "?" in endpoint else "?") + "alt=sse"
        if key:
            headers["x-goog-api-key"] = key
    elif key:
        headers["Authorization"] = "Bearer " + key
    attach(packet)
    try:
        with connect(endpoint, packet["data"], headers, local_only) as response:
            for line in response:
                print(line.decode("utf-8", errors="replace").rstrip("\r\n"), flush=True)
    except urllib.error.HTTPError as error:
        try:
            detail = json.loads(error.read(8192)).get("error", "")
            if isinstance(detail, dict):
                detail = detail.get("message", "")
        except (ValueError, OSError):
            detail = ""
        raise ValueError(f"HTTP {error.code}" + (f": {detail}" if detail else "")) from None


def history(operation, directory, name=""):
    directory = Path(directory)
    directory.mkdir(mode=0o700, parents=True, exist_ok=True)
    directory.chmod(0o700)
    if operation == "list":
        chats = []
        for path in directory.glob("*.json"):
            if path.is_symlink() or not path.is_file():
                continue
            path.chmod(0o600)
            if CHAT_NAME.fullmatch(path.stem):
                chats.append(path.stem)
        print(json.dumps(sorted(chats, key=str.casefold)))
        return
    if not CHAT_NAME.fullmatch(name):
        raise ValueError("Use a chat name with letters, numbers, spaces, periods, dashes, or underscores.")
    path = directory / (name + ".json")
    if operation == "load":
        fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
        with os.fdopen(fd, encoding="utf-8") as source:
            properties = os.fstat(source.fileno())
            if not stat.S_ISREG(properties.st_mode) or properties.st_size > 32 * 1024 * 1024:
                raise ValueError("Chat is not a regular file or is too large.")
            data = json.load(source)
        if not isinstance(data, list):
            raise ValueError("Chat file must contain a message list.")
        print(json.dumps(data))
    elif operation == "save":
        data = json.load(sys.stdin)
        with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8", dir=directory, delete=False) as file:
            temp_path = Path(file.name)
            try:
                json.dump(data, file, ensure_ascii=False)
                file.close()
                temp_path.replace(path)
            finally:
                temp_path.unlink(missing_ok=True)
    else:
        raise ValueError("Unknown history operation.")


if __name__ == "__main__":
    try:
        action = sys.argv[1]
        if action == "discover":
            discover()
        elif action == "request":
            request()
        elif action == "history":
            history(*sys.argv[2:])
        else:
            raise ValueError("Unknown Assistant action.")
    except (OSError, ValueError, KeyError) as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
