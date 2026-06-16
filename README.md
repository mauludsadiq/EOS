# EOS — Epistemic Operating System

**A deterministic, cryptographically-verifiable micro-OS written entirely in FARD.**

EOS is a kernel whose primitives are not files, processes, and sockets — they are
content-addressed blobs, signed claims, policy gates, witnesses, gossip, and challenges.
Every operation is deterministic, auditable, and policy-enforced.

EOS is the substrate layer beneath Anka (cross-institutional AI coordination) and
Azim (deterministic AI training). Claims flow up from EOS into the Anka mesh.
Training receipts flow down from Azim into EOS as verifiable claims.
Every significant system event becomes a signed, content-addressed telemetry claim.

---

## Architecture

   Azim (training receipts)          Anka (mesh coordination)
            |                                  ^
       azim/bridge                   anka/bridge, witness_bridge, discover
            |                                  |
            +-------------- kernel ------------+
                                 |
            +--------+--------+--+---+----------+----------+
            k1     claim     gate  witness   gossip    challenge
          (blobs) (signing) (policy) (attest) (pub/sub)  (PoP)
            |        |        |
        canonical  keypair  compile
                         |
                    jurisdictions
                         |
            +------------+------------+
            |            |            |
        gatewayd     witnessd    telemetryd
       (eval/compile) (collect)   (audit trail)


---

## Kernel — Nine Primitives

   k1            Content-addressed blob store.
                 write(store, data) -> { store, digest }  where digest = "sha256:..."
                 read(store, digest) -> { ok: data } | { err: "not_found" }
                 Immutable: same bytes always produce the same digest. No delete.

   canonical     Deterministic JSON serialization and SHA-256 digesting.
                 canonicalize(obj) -> stable JSON text (sorted keys, no whitespace)
                 digest_obj(obj) -> "sha256:..." prefix string
                 All claims must be canonicalized before signing or digesting.

   claim         Mint and verify Ed25519-signed epistemic claims.
                 A claim: who said what about what, when, in which jurisdiction.
                 An envelope: { claim, digest_hex, issuer_signature_hex }
                 make / sign / verify / verify_digest_only / schema_valid

   gate          RPN stack machine for policy evaluation.
                 Ops: RepMin, AgeMax, JurAllow, And, Or, Glb
                 eval(program, claim, ctx) -> { ok } | { err: "Gate denied" }
                 compile(policy_json) -> { ok: ops } | { err }
                 eval_with_ctx_json(claim, ctx_json) -> { ok } | { err }

   witness       Build and verify independent attestations over claims.
                 make(subject, claims, private_key, timestamp) -> witness record
                 make_disagreement(..., disagreement) -> contested witness
                 verify(witness, public_key) -> { accepted, digest_ok, signature_ok }

   gossip        In-memory pub/sub by topic digest.
                 publish(store, topic, msg) -> store
                 subscribe(store, topic) -> { msgs, store }
                 In production: HTTP gossip between Anka mesh nodes.

   keypair       Ed25519 key generation, signing, verification.
                 generate(seed) -> { private_key_hex, public_key_hex, node_id }
                 node_id format: "ed25519:<public_key_hex>"
                 Fully interoperable with Anka keypair module.

   challenge     Proof-of-possession and claim contestation.
                 make_nonce / respond / verify_response  (node identity PoP)
                 make_claim_challenge / verify_claim_challenge  (contest a claim)
                 Interoperable with Anka challenge.fard.

   kernel        Assembles all eight primitives into one record.
                 new(seed) -> kernel record with keypair, k1, gossip
                 Single entry point: mint_claim, eval_gate, build_witness,
                 issue_challenge, respond_to_challenge, contest_claim, ...

---

## Policy Layer

   policy/compile        Compiles JSON policy files to executable op-list bytecode.
                         Bytecode = canonical JSON { ops: [...] } — portable and inspectable.
                         compile_json_text / compile_file / to_bytecode / from_bytecode
                         compile_file_to_bytecode(input_path, output_path)

   policy/jurisdictions  Named constants for all known claim spaces.
                         Eliminates raw strings in policies, gates, and claim minting.

Known jurisdictions (17):

   Regulatory    FDA_US_2025, EMA_EU_2025, MHRA_UK_2025, PMDA_JP_2025,
                 TGA_AU_2025, ANVISA_BR_2025

   AI            AZIM_TRAIN_V1, AZIM_EVAL_V1, AZIM_CODE_V1

   Coordination  ANKA_MESH_V1, ANKA_WITNESS_V1, ANKA_ORIGIN_V1

   Research      NIST_US_2025, NIH_US_2025, PUBMED_GLOBAL

   Finance       SEC_US_2025, FCA_UK_2025

Helpers: is_known, is_regulatory, is_ai, is_coordination, region_of, agency_of

Policy schemas:

   RPN (explicit):
   { "rules": [{"op":"RepMin","val":10}, {"op":"JurAllow","list":["FDA.US.2025"]}, {"op":"Glb","n":2}] }

   Convenience (auto-compiled to Glb):
   { "RepMin": 10, "AgeMax": 315360000, "JurAllow": ["FDA.US.2025"] }

Gate ops:

   RepMin(n)       pass if ctx.reputation >= n
   AgeMax(secs)    pass if now - claim.timestamp_unix_secs <= secs
   JurAllow([...]) pass if claim.claim_space in list
   And             pop 2, push (a && b)
   Or              pop 2, push (a || b)
   Glb(n)          pop n, push conjunction of all

No policy in ctx = allow-all (explicit fallback, intentional for dev).

---

## Anka Integration

   anka/bridge           Publish signed eOS claim envelopes to an Anka mesh node.
                         client(base_url) -> client record
                         publish_envelope(client, envelope) -> { ok, data }
                         publish_claim(client, kernel, space, subject, ...) -> { envelope, result }
                         query(client, claim_space, subject) -> collapsed answer
                         audit_trail(client, digest_hex) -> full epistemic history

   anka/witness_bridge   Build and submit witness records to Anka.
                         submit_witness(client, kernel, subject, claims, timestamp)
                         submit_disagreement(..., disagreement)

   anka/discover         Capability discovery — find Anka agents by what they can do.
                         make_entry / sign_entry / verify_entry
                         register_node(client, kernel, address, institution, region, caps, spaces)
                         by_capability(client, capability) -> agents
                         by_institution / by_claim_space / best(client, cap, region)
                         Local cache: new_cache / cache_entry / lookup / refresh

Anka interop: EOS claim envelopes are structurally identical to Anka claim envelopes.
Same Ed25519 keypair format, same canonical JSON digesting, same sha256: prefix.
An EOS node and an Anka node verify each other's signatures without any adapter.

---

## Azim Integration

   azim/bridge    Wraps Azim training receipts as eOS claims.
                  claim_space: AZIM_TRAIN_V1  ("AZIM.TRAIN.v1")
                  subject:     "azim:round:N"
                  predicate:   "training_step"
                  object:      { loss_before, loss_after, steps, receipt_digest }
                  evidence_refs: [receipt digest_hex]

                  receipt_to_claim(kernel, receipt, timestamp) -> envelope
                  publish_receipt(anka_client, kernel, receipt, timestamp) -> { envelope, result }
                  verify_receipt_chain(kernel, envelope, policy) -> { ok } | { err }

Every Azim training step becomes an auditable, policy-gated eOS claim.
The full training run is a content-addressed, witnessable audit trail in the Anka mesh.

Current Azim training results, receipted as eOS claims:

   Round 1:  5.3168 -> 5.3127   Round 9:  2.9258 -> 2.9230
   Round 8:  3.0139 -> 3.0111   Round 16: 2.4111 -> 2.4087
   Random baseline: 4.86        Current:  2.41 (50% below random)

---

## Service Layer

   gatewayd      HTTP gateway — evaluate claims against policies at ingress.
                 POST /eval      { claim, ctx } -> { ok } | { err: "Gate denied" }
                 POST /compile   { policy } -> { ok, bytecode }
                 GET  /health    -> { ok, service, node_id }
                 Port: GATEWAYD_PORT (default 7700)

   witnessd      HTTP service — collect, verify, and forward witness records.
                 POST /witness       { subject, claims, timestamp, disagreement? }
                                     -> { ok, digest_hex, forwarded }
                 POST /witness/raw   pre-built envelope, verify digest + forward
                 GET  /witness/pending  local queue
                 GET  /health
                 Port: WITNESSD_PORT (default 7701)

   telemetryd    HTTP service — emit signed trace events as eOS claims.
                 POST /emit          { kind, subject, data, timestamp }
                                     -> { ok, digest_hex, forwarded }
                 GET  /events        all stored events
                 GET  /events/:kind  filtered by event kind
                 GET  /health        -> { ok, service, node_id, event_count }
                 Port: TELEMETRYD_PORT (default 7702)
                 Persistence: SQLite (TELEMETRYD_DB)
                 Forwarding: TELEMETRYD_FORWARD=true (default)

   policyd       CLI — compile a policy JSON file to bytecode.
                 fardrun run --program src/services/policyd.fard -- \
                   --input policies/FDA.US.2025.json \
                   --output out/FDA.US.2025.bytecode

Event kinds emitted by telemetryd:
   node_start, node_stop, claim_published, claim_verified, claim_rejected,
   witness_built, challenge_issued, gate_eval, error

---

## Policies

   policies/FDA.US.2025.json    Reference FDA jurisdiction policy fixture.
                                RepMin: 0 (open), Version: 0.1.0

---

## Test Suite

   tests/test_k1.fard               4 tests   blob store
   tests/test_claim.fard            3 tests   claim mint/verify
   tests/test_gate.fard             7 tests   GateVM evaluation
   tests/test_witness.fard          5 tests   witness build/verify
   tests/test_kernel.fard           7 tests   kernel integration
   tests/test_azim_bridge.fard      6 tests   Azim receipt claims
   tests/test_policy_compile.fard   6 tests   policy compilation
   tests/test_fda_policy.fard       4 tests   FDA fixture end-to-end
   tests/test_witnessd.fard         8 tests   witnessd logic
   tests/test_challenge.fard       10 tests   PoP + claim contest
   tests/test_discover.fard        14 tests   capability discovery + cache
   tests/test_jurisdictions.fard   16 tests   jurisdiction constants
   tests/test_telemetryd.fard      10 tests   telemetry claims
   ────────────────────────────────────────────
   total                          100 tests   0 failures

Run all tests:

   bash run_tests.sh

---

## Runtime

   Language:    FARD v1.7.0
   Runtime:     fardrun
   Crypto:      Ed25519 via std/crypto
   Hashing:     SHA-256 via std/hash
   Storage:     In-memory (k1, gossip) — SQLite in telemetryd and Anka node
   Tracing:     std/trace — every telemetry emit is traced

---

## Stack

   EOS       epistemic kernel      claims, gates, witnesses, blobs, gossip, challenges
   Anka      coordination layer    mesh, audit trail, discovery, reputation, federation
   Azim      training layer        receipts, corpus, verification, coding agent
   FARD      language              deterministic, receipted, self-hosting (Stage 8)

---

## Repositories

   github.com/mauludsadiq/EOS      this repo — epistemic kernel
   github.com/mauludsadiq/Anka     coordination mesh (14,506 lines, 153 files)
   github.com/mauludsadiq/Azim     deterministic AI training (19,200 lines, 192 files)

---

## License

MUI
