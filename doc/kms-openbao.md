# OpenBao KMS local testing

This guide tests the server's OpenBao KMS adapter with AES-256-GCM. The adapter
reads a hex-encoded `key` field from a KV v2 secret at `<mount>/data/<keyId>`.
The broker retrieves the key and performs encryption locally; OpenBao Transit
is not used. Key creation and deletion are managed outside the broker.

## Prerequisites

- Install the [OpenBao CLI](https://openbao.org/docs/install/) (`bao`).
- Have sibling checkouts of `crypto-broker-server` and `crypto-broker-cli-go`
  containing KMS support, plus the Go toolchain required by their `go.mod` files.
- Run the server and CLI as the same local user. Stop any other broker using
  `/tmp/open-crypto-broker/crypto-broker-server.sock` before testing.

Run the following commands from this deployment repository unless indicated
otherwise. This setup uses an in-memory development server and a public test
token; use it only for local testing. Stopping OpenBao discards its secrets.

## 1. Start OpenBao

In a separate terminal, leave this process running:

```sh
bao server -dev -dev-root-token-id=dev-only-token \
  -dev-listen-address=127.0.0.1:8200
```

In your main terminal, configure the CLI and create a KV v2 mount:

```sh
export BAO_ADDR=http://127.0.0.1:8200
export BAO_TOKEN=dev-only-token
bao status
bao secrets enable -path=mykeys kv-v2
```

Enable the mount once per fresh dev server. If it already exists, check
`bao secrets list -detailed` and confirm that its version is `2`.
See the OpenBao [dev server guide](https://openbao.org/docs/get-started/developer-qs/)
and [KV v2 documentation](https://openbao.org/docs/secrets/kv/kv-v2/).

## 2. Add test keys

Store this example 32-byte AES-256 key as hex (for testing only):

```sh
bao kv put -mount=mykeys secret-key key="000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f"
bao kv get -mount=mykeys secret-key
```

The field must be named `key`, and its value must be hex, without a `0x` prefix.
AES-128, AES-192, and AES-256 require 16, 24, and 32 bytes respectively; the key
length must match the profile's `KeySize`.

Use `secret-key` as the request's key ID, not `mykeys/data/secret-key`. The adapter
adds the mount and `/data/` path itself. Writing to an existing name creates a
new secret version; avoid replacing a key needed to decrypt earlier ciphertext.

## 3. Configure and start the broker

Use the server repository's example
[`configs/openbao.yaml`](https://github.com/open-crypto-broker/crypto-broker-server/blob/main/configs/openbao.yaml).
For this local setup, edit its values to:

```yaml
address: http://127.0.0.1:8200
token: dev-only-token
mount: mykeys
```

Use the server's
[`example-profiles/Profiles.yaml`](https://github.com/open-crypto-broker/crypto-broker-server/blob/main/example-profiles/Profiles.yaml).
Ensure its `Default` profile has `KMS.Client: openbao`,
`KMS.Config: openbao.yaml`, and `KMS.Cache: false`, with
`API.EncryptData.EncryptAlg: aes-gcm` and `API.EncryptData.KeySize: 256`.

In another terminal, from the server repository, start the broker:

```sh
export CRYPTO_BROKER_PROFILES_DIR="$PWD/example-profiles"
export CRYPTO_BROKER_KMS_DIR="$PWD/configs"
go run ./cmd/server
```

`Config` is relative to `CRYPTO_BROKER_KMS_DIR`. `Cache: false` makes requests
read OpenBao instead of reusing cached keys. The adapter reads the token from
`openbao.yaml`; exporting `BAO_TOKEN` configures the Bao CLI, not this file.

## 4. Encrypt and decrypt through KMS

Back in the main terminal, switch to the Go CLI repository and use this example
12-byte nonce for a single test encryption:

```sh
cd ../crypto-broker-cli-go
NONCE="a83f89b37c90f937b8df5011"
go run . encrypt-data 'Welcome CryptoBroker' \
  --profile Default --keyId secret-key --nonce "$NONCE"
```

Copy the `ciphertext` and `tag` values from the `Encrypt data response` log,
then decrypt with the same nonce and key ID:

```sh
CIPHERTEXT='PASTE_CIPHERTEXT_HEX'
TAG='PASTE_TAG_HEX'
go run . decrypt-data "$CIPHERTEXT" \
  --profile Default --keyId secret-key --nonce "$NONCE" --tag "$TAG"
```

Success means the response contains `plaintext="Welcome CryptoBroker"`
(or the equivalent JSON field). No raw key is supplied to the client.

Before running these commands, ensure your Go CLI honors `--keyId`. Some local
development versions override the requested key ID in
`internal/command/encrypt_data.go` and `decrypt_data.go`; remove any such
overrides before using this guide. Requesting a nonexistent key should fail. Never reuse a nonce with
the same AES-GCM key for another encryption.
