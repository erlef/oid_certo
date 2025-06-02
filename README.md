<p align="center">
  <img src="assets/logo.svg" alt="OIDCerto logo" width="240">
</p>

# OIDCerto – OpenID Connect Certification Automation

*Self‑certify OpenID Connect Relying‑Party (client) implementations locally or
in a CI.*

## Table of contents
1. [Quick start](#quick-start)  
2. [Installation](#installation)  
3. [CLI reference](#cli-reference)  
4. [Implementation contract](#implementation-contract-stdin--stdout-protocol)  
5. [UI expectations](#ui-expectations)  
6. [Exit codes & logging](#exit-codes--logging)  
9. [License](#license)  

## Quick start

```bash
# 1. Download the latest binary
curl -L -o oid_certo https://github.com/erlef/oid_certo/releases/download/vX.Y.Z/oid_certo_$(uname -s)_$(uname -m)
gh attestation verify \
  --repo erlef/oid_certo \
  --source-ref "vX.Y.Z"
chmod +x oid_certo

# 2. Create a new plan on the OpenID Conformance service
./oid_certo create-plan \
  my-first-plan \
  '{
     "client_registration": "static_client",
     "client_auth_type": "client_secret_basic"
   }' \
  '{
     "client": {
       "client_id": "my_rp",
       "client_secret": "s3cret"
     }
   }'

# 3. Execute that plan against *your* binary
./oid_certo execute-plan \
  --implementation ./my_oidc_client \
  --output-directory ./oidcerto-results \
  <PLAN_ID_FROM_STEP_2>
```

When the run finishes you will have (`[OUT_DIRECTORY]/[PLAN_NAME]/[ID]/[TEST_NAME]`):

* Screenshots from the Headless Browser `screenshot_*.png`
* Logs from the implementation `implementation.[DEVICE].log`
  (STDIN, STDOUT, STDERR)
* Test Logs from the certification tool as JSON and HTML


## Installation

| Environment        | How                                                                                                            |
| ------------------ | -------------------------------------------------------------------------------------------------------------- |
| **Local / CI**     | Download an asset from the [GitHub Releases](https://github.com/erlef/oid_certo/releases) page and `chmod +x`. |
| **GitHub Actions** | `uses: erlef/oid_certo@v1` – work in progress.                                                                 |


## CLI reference

All commands share a unified set of **global options**:

| Option                     | Env‑fallback   | Default                                | Purpose                                                             |
| -------------------------- | -------------- | -------------------------------------- | ------------------------------------------------------------------- |
| `-a`, `--api-base-url`     | `API_BASE_URL` | `https://www.certification.openid.net` | Conformance API root                                                |
| `-t`, `--api-token`        | `API_TOKEN`    | *none* (required)                      | Your personal API token                                             |
| `-i`, `--implementation`   | –              | *required*                             | Path to the binary you want OIDCerto to drive                       |
| `-o`, `--output-directory` | –              | System TMP Diretory                    | Where artifacts (logs, screenshots, JUnit) are written              |

### Commands

| Command             | Purpose                                                         | Key args                                                                    |
| ------------------- | --------------------------------------------------------------- | --------------------------------------------------------------------------- |
|                     | Create and execute plans based on config                        | `config_file` – string |
| **`create-plan`**   | Create a new test plan on the conformance service               | `plan_name` – string<br>`variant` – JSON or path<br>`config` – JSON or path |
| **`execute-plan`**  | Run *all* tests of an existing plan                             | `plan_id` – ID returned by `create-plan`                                    |
| **`execute-test`**  | Run a *single* test from a plan (handy for debugging)           | `plan_id`, `test_name`                                                      |
| **`cleanup-plans`** | Delete all *unpublished* plans belonging to the current account | *(no args)*                                                                 |

Each subcommand accepts the global options listed earlier (plus its own).

### Examples

```bash
# Execute just the "oidcc-client-test-idtoken-sig-rs256" test
./oid_certo execute-test \
  --implementation ./my_oidc_client \
  --output-directory ./tmp/results \
  12345678 \
  oidcc-client-test-idtoken-sig-rs256

# Purge abandoned plans
./oid_certo cleanup-plans
```

## Implementation contract (STDIN / STDOUT protocol)

OIDCerto launches *your* process, then streams **JSON‐line commands** over `STDIN`.
You must respond on `STDOUT` with `ACK` or `NACK`.
Log freely to `STDERR`; it is never parsed—only captured.

### Life‑cycle

| Phase                               | You receive                    | You reply                                                    | Notes                             |
| ----------------------------------- | ------------------------------ | ------------------------------------------------------------ | --------------------------------- |
| **Init**                            | `CMD {"action":"init", …}`         | `{"status":"ACK","url":"http://127.0.0.1:4000","port":4000}` | Decide listening port, seed state |
| **(optional)** dynamic registration | `CMD {"action":"register_client"}` | credentials or `NACK`                                        | Only for dynamic variants         |
| **Run**                             | `CMD {"action":"start_server", …}` | `{"status":"ACK"}`                                           | Start redirect‑handling server    |
| **EOF**                             | –                              | –                                                            | Exit **0**                        |

Any fatal problem → write reason to `STDERR`, exit **≠ 0**.

## UI expectations

OIDCerto drives a headless browser and asserts that specific elements exist:

| Page    | Required element     | ARIA label |
| ------- | -------------------- | ---------- |
| Landing | Login button/link    | `Login`    |
| Success | **sub** claim        | `sub`      |
|         | Raw ID token         | `token`    |
|         | `/userinfo` response | `userinfo` |
|         | Refresh button/link  | `Refresh`  |
|         | Logout button/link   | `Logout`   |
| Failure | Error summary        | `error`    |

You may keep elements hidden/off‑screen; presence in the DOM is enough.

## Exit codes & logging

| Code     | Meaning                                         |
| -------- | ----------------------------------------------- |
| `0`      | Normal shutdown after `EOF`.                    |
| `>0`     | Internal or protocol error.                     |
| `STDERR` | Copied verbatim to `implementation.stderr.log`. |


## License

    Copyright 2025 Erlang Ecosystem Foundation

    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

        http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.