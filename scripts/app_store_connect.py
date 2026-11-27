#!/usr/bin/env python3
"""Dependency-free App Store Connect API helpers for TestFlight uploads."""

import argparse
import base64
import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Optional, Tuple

API_BASE = "https://api.appstoreconnect.apple.com"
DEFAULT_BUNDLE_ID = "bar.pourstl.app"


def b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).decode().rstrip("=")


def der_integer(data: bytes, offset: int) -> Tuple[bytes, int]:
    if offset + 2 > len(data) or data[offset] != 0x02:
        raise ValueError("Invalid ECDSA DER signature: expected integer")
    length = data[offset + 1]
    start = offset + 2
    end = start + length
    if end > len(data):
        raise ValueError("Invalid ECDSA DER signature: truncated integer")
    return data[start:end].lstrip(b"\x00"), end


def der_to_raw_ecdsa(signature: bytes, size: int = 32) -> bytes:
    """Convert OpenSSL's DER ECDSA signature to the raw R||S form JWS uses."""
    if len(signature) < 8 or signature[0] != 0x30:
        raise ValueError("Invalid ECDSA DER signature: expected sequence")
    if signature[1] + 2 != len(signature):
        raise ValueError("Invalid ECDSA DER signature: bad sequence length")
    r, offset = der_integer(signature, 2)
    s, offset = der_integer(signature, offset)
    if offset != len(signature) or len(r) > size or len(s) > size:
        raise ValueError("Invalid ECDSA DER signature")
    return r.rjust(size, b"\x00") + s.rjust(size, b"\x00")


class AppStoreConnectClient:
    def __init__(self, key_id: str, issuer_id: str, key_path: str):
        self.key_id = key_id
        self.issuer_id = issuer_id
        self.key_path = key_path
        self._token = None
        self._token_created = 0.0

    def token(self) -> str:
        # Apple permits up to 20 minutes. Refresh after 10 during long polling.
        if self._token and time.time() - self._token_created < 600:
            return self._token
        now = int(time.time())
        header = {"alg": "ES256", "kid": self.key_id, "typ": "JWT"}
        payload = {"iss": self.issuer_id, "iat": now, "exp": now + 900, "aud": "appstoreconnect-v1"}
        encode = lambda value: b64url(json.dumps(value, separators=(",", ":")).encode())
        signing_input = f"{encode(header)}.{encode(payload)}".encode()
        result = subprocess.run(
            ["openssl", "dgst", "-sha256", "-sign", self.key_path],
            input=signing_input,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
            timeout=30,
        )
        if result.returncode != 0:
            detail = result.stderr.decode(errors="replace").strip()
            raise RuntimeError(f"Could not sign the App Store Connect JWT with openssl: {detail}")
        self._token = signing_input.decode() + "." + b64url(der_to_raw_ecdsa(result.stdout))
        self._token_created = time.time()
        return self._token

    def request(self, method: str, path: str, body=None, expected=(200,)):
        data = None if body is None else json.dumps(body, separators=(",", ":")).encode()
        request = urllib.request.Request(API_BASE + path, data=data, method=method)
        request.add_header("Authorization", f"Bearer {self.token()}")
        request.add_header("Accept", "application/json")
        if body is not None:
            request.add_header("Content-Type", "application/json")
        try:
            with urllib.request.urlopen(request, timeout=60) as response:
                status = response.status
                raw = response.read()
        except urllib.error.HTTPError as error:
            detail = error.read().decode(errors="replace")[:1200]
            raise RuntimeError(f"App Store Connect API {method} {path} failed with HTTP {error.code}: {detail}") from error
        if status not in expected:
            raise RuntimeError(f"App Store Connect API {method} {path} returned HTTP {status}, expected {expected}")
        return json.loads(raw) if raw else {}


def client_from_environment() -> AppStoreConnectClient:
    missing = [name for name in ("ASC_KEY_ID", "ASC_ISSUER_ID", "ASC_PRIVATE_KEY") if not os.environ.get(name)]
    if missing:
        raise RuntimeError("Missing required environment variables: " + ", ".join(missing))
    default_dir = Path.home() / ".appstoreconnect" / "private_keys"
    key_directory = Path(os.environ.get("ASC_KEY_DIR", str(default_dir)))
    key_directory.mkdir(mode=0o700, parents=True, exist_ok=True)
    key_path = key_directory / f"AuthKey_{os.environ['ASC_KEY_ID']}.p8"
    if not key_path.exists() or os.environ.get("ASC_REWRITE_KEY") == "1":
        private_key = os.environ["ASC_PRIVATE_KEY"]
        if not private_key.endswith("\n"):
            private_key += "\n"
        key_path.write_text(private_key, encoding="utf-8")
        key_path.chmod(0o600)
    return AppStoreConnectClient(os.environ["ASC_KEY_ID"], os.environ["ASC_ISSUER_ID"], str(key_path))


def query(params: dict) -> str:
    return urllib.parse.urlencode(params)


def find_app(client: AppStoreConnectClient, bundle_id: str) -> dict:
    payload = client.request("GET", "/v1/apps?" + query({"filter[bundleId]": bundle_id, "limit": 10}))
    apps = payload.get("data", [])
    if not apps:
        raise RuntimeError(
            f"No App Store Connect app record exists for bundle ID {bundle_id}. "
            "Create it manually in App Store Connect first; Apple's public API does not create app records."
        )
    if len(apps) > 1:
        raise RuntimeError(f"More than one App Store Connect app record matched bundle ID {bundle_id}")
    return apps[0]


def list_builds(client: AppStoreConnectClient, app_id: str, version: Optional[str] = None) -> list:
    params = {"filter[app]": app_id, "sort": "-uploadedDate", "limit": 200}
    if version is not None:
        params["filter[version]"] = version
    return client.request("GET", "/v1/builds?" + query(params)).get("data", [])


def numeric_build_versions(builds: list) -> list:
    versions = []
    for build in builds:
        version = str((build.get("attributes") or {}).get("version", ""))
        if version.isdecimal():
            versions.append(int(version))
    return versions


def resolve_build_number(client: AppStoreConnectClient, bundle_id: str, requested: Optional[str]) -> int:
    app = find_app(client, bundle_id)
    latest = max(numeric_build_versions(list_builds(client, app["id"])), default=0)
    if requested:
        if not requested.isdecimal() or int(requested) < 1:
            raise RuntimeError("Build number must be a positive integer")
        number = int(requested)
        if number <= latest:
            raise RuntimeError(f"Build number {number} is not higher than the latest App Store Connect build {latest}")
        return number
    return latest + 1


def list_beta_groups(client: AppStoreConnectClient, app_id: str) -> list:
    params = {"filter[app]": app_id, "fields[betaGroups]": "name,isInternalGroup,hasAccessToAllBuilds", "limit": 200}
    return client.request("GET", "/v1/betaGroups?" + query(params)).get("data", [])


def find_or_create_beta_group(client: AppStoreConnectClient, app_id: str, name: str, internal: bool, create: bool) -> dict:
    groups = list_beta_groups(client, app_id)
    named_groups = [group for group in groups if (group.get("attributes") or {}).get("name") == name]
    for group in named_groups:
        if (group.get("attributes") or {}).get("isInternalGroup") is internal:
            return group
    if named_groups:
        group_type = "internal" if internal else "external"
        raise RuntimeError(f"No {group_type} TestFlight beta group named {name!r}. A group of another type uses that name.")
    if not create:
        names = ", ".join(sorted((group.get("attributes") or {}).get("name", "") for group in groups)) or "none"
        raise RuntimeError(f"No TestFlight beta group named {name!r}. Existing groups: {names}")
    attributes = {
        "name": name,
        "isInternalGroup": internal,
        "hasAccessToAllBuilds": False,
        "feedbackEnabled": True,
    }
    if not internal:
        attributes["publicLinkEnabled"] = False
        attributes["publicLinkLimitEnabled"] = False
    body = {
        "data": {
            "type": "betaGroups",
            "attributes": attributes,
            "relationships": {"app": {"data": {"type": "apps", "id": app_id}}},
        }
    }
    return client.request("POST", "/v1/betaGroups", body=body, expected=(201,)).get("data", {})


def build_already_in_group(client: AppStoreConnectClient, group_id: str, build_id: str) -> bool:
    payload = client.request("GET", f"/v1/betaGroups/{group_id}/relationships/builds?limit=200")
    return any(item.get("id") == build_id for item in payload.get("data", []))


def wait_for_build(client: AppStoreConnectClient, app_id: str, version: str, timeout_minutes: int) -> dict:
    deadline = time.time() + timeout_minutes * 60
    while time.time() < deadline:
        matches = list_builds(client, app_id, version=version)
        if matches:
            build = matches[0]
            state = (build.get("attributes") or {}).get("processingState", "unknown")
            if state == "VALID":
                return build
            if state in {"FAILED", "INVALID"}:
                raise RuntimeError(f"App Store Connect build {version} finished with processing state {state}")
            print(f"Build {version} is {state}; waiting...", flush=True)
        else:
            print(f"Build {version} is not visible yet; waiting...", flush=True)
        time.sleep(30)
    raise RuntimeError(f"Timed out waiting for App Store Connect build {version} to finish processing")


def wait_and_assign(args) -> None:
    client = client_from_environment()
    app = find_app(client, args.bundle_id)
    build = wait_for_build(client, app["id"], str(args.build_number), args.timeout_minutes)
    group = find_or_create_beta_group(client, app["id"], args.beta_group, internal=args.internal, create=args.create_group)
    if not group.get("id"):
        raise RuntimeError(f"Could not resolve beta group {args.beta_group!r}")
    if (group.get("attributes") or {}).get("hasAccessToAllBuilds"):
        print(f"Build {args.build_number} is automatically available to TestFlight group {args.beta_group}.")
        return
    if build_already_in_group(client, group["id"], build["id"]):
        print(f"Build {args.build_number} is already assigned to {args.beta_group}.")
        return
    body = {"data": [{"type": "builds", "id": build["id"]}]}
    client.request("POST", f"/v1/betaGroups/{group['id']}/relationships/builds", body=body, expected=(204,))
    print(f"Build {args.build_number} is assigned to TestFlight group {args.beta_group}.")


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    subcommands = parser.add_subparsers(dest="command", required=True)

    check = subcommands.add_parser("check-app", help="Verify that the App Store Connect app record exists")
    check.add_argument("--bundle-id", default=DEFAULT_BUNDLE_ID)

    resolve = subcommands.add_parser("resolve-build-number", help="Print the requested or next integer build number")
    resolve.add_argument("--bundle-id", default=DEFAULT_BUNDLE_ID)
    resolve.add_argument("--build-number")

    assign = subcommands.add_parser("wait-and-assign", help="Wait for processing and assign a build to a beta group")
    assign.add_argument("--bundle-id", default=DEFAULT_BUNDLE_ID)
    assign.add_argument("--build-number", required=True)
    assign.add_argument("--beta-group", default="App Store Connect Users")
    assign.add_argument("--timeout-minutes", type=int, default=45)
    assign.add_argument("--create-group", action="store_true")
    assign.add_argument("--internal", action=argparse.BooleanOptionalAction, default=True)

    args = parser.parse_args(argv)
    try:
        if args.command == "check-app":
            app = find_app(client_from_environment(), args.bundle_id)
            attrs = app.get("attributes") or {}
            print(f"Found app {attrs.get('name', '(unnamed)')} ({args.bundle_id}), App Store ID {app['id']}.")
        elif args.command == "resolve-build-number":
            print(resolve_build_number(client_from_environment(), args.bundle_id, args.build_number))
        elif args.command == "wait-and-assign":
            wait_and_assign(args)
    except (RuntimeError, ValueError) as error:
        print(f"error: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
