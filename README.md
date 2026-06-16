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

## By the numbers

   2,379 lines of FARD
     107 tests, 0 failures
      20 source files
      14 test files
       8 commits
       1 day

   Stack position:
     EOS      2,379 lines   epistemic kernel (this repo)
     Anka    14,506 lines   coordination mesh
     Azim     4,694 lines   deterministic AI training
     Total   21,579 lines   across 222 files

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
                 No policy in ctx = allow-all (explicit fallback, intentional for dev).

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
                 new(seed) -> kernel with keypair, k1, gossip
                 mint_claim, eval_gate, build_witness,
                 issue_challenge, respond_to_challenge, verify_challenge_response,
                 contest_claim, verify_contest,
                 pub_gossip, sub_gossip, write_blob, read_blob

---

## Policy Layer

   policy/compile        Compiles JSON policy files to executable op-list bytecode.
                         Bytecode = canonical JSON { ops: [...] }
                         Portable, inspectable, re-evaluable without recompilation.
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

---

## Anka Integration

   anka/bridge           Publish signed eOS claim envelopes to an Anka mesh node.
                         client(base_url) -> client record
                         publish_envelope(client, envelope) -> { ok, data }
                         publish_claim(client, kernel, space, subject, ...) -> { envelope, result }
                         query(client, claim_space, subject) -> collapsed answer
                         audit_trail(client, digest_hex) -> full epistemic history

   anka/witness_bridge   Submit witness records to Anka /witness endpoint.
                         submit_witness(client, kernel, claim_digest_hex, validation_type, timestamp)
                         submit_structural / submit_semantic / submit_cryptographic
                         build_and_submit: build local eOS witness AND notify Anka

   anka/discover         Capability discovery — find Anka agents by what they can do.
                         make_entry / sign_entry / verify_entry
                         register_node(client, kernel, address, institution, region, caps, spaces)
                         by_capability / by_institution / by_claim_space
                         best(client, capability, region) -> highest-scored agent
                         Local cache: new_cache / cache_entry / lookup / refresh

Anka interop: EOS claim envelopes are structurally identical to Anka claim envelopes.
Same Ed25519 keypair format, same canonical JSON digesting, same sha256: prefix.
An EOS node and an Anka node verify each other's signatures without any adapter.

Live Anka node (localhost:18080) after integration tests:
   claim_count:   10
   witness_count:  1

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

   tests/test_k1.fard               4 tests    41 lines   blob store
   tests/test_claim.fard            3 tests    34 lines   claim mint/verify
   tests/test_gate.fard             7 tests    57 lines   GateVM evaluation
   tests/test_witness.fard          5 tests    42 lines   witness build/verify
   tests/test_kernel.fard           7 tests    60 lines   kernel integration
   tests/test_azim_bridge.fard      6 tests    46 lines   Azim receipt claims
   tests/test_policy_compile.fard   6 tests    55 lines   policy compilation
   tests/test_fda_policy.fard       4 tests    44 lines   FDA fixture end-to-end
   tests/test_witnessd.fard         8 tests    69 lines   witnessd logic
   tests/test_challenge.fard       10 tests    74 lines   PoP + claim contest
   tests/test_discover.fard        14 tests   108 lines   capability discovery + cache
   tests/test_jurisdictions.fard   16 tests    89 lines   jurisdiction constants
   tests/test_telemetryd.fard      10 tests    71 lines   telemetry claims
   tests/test_anka_live.fard        7 tests    74 lines   live Anka integration
   ─────────────────────────────────────────────────────
   total                          107 tests   970 lines   0 failures

Run all tests:

   bash run_tests.sh

Note: test_anka_live.fard requires a running Anka node on localhost:18080.
     All other tests run fully offline.

---

## Line counts

   src/anka/discover.fard          212
   src/services/telemetryd.fard    206
   src/services/witnessd.fard      129
   src/kernel/challenge.fard       116
   src/policy/jurisdictions.fard    89
   src/kernel/gate.fard             89
   src/kernel/kernel.fard           88
   src/kernel/claim.fard            86
   src/anka/bridge.fard             71
   src/kernel/witness.fard          68
   src/services/gatewayd.fard       61
   src/anka/witness_bridge.fard     55
   src/policy/compile.fard          46
   src/azim/bridge.fard             39
   src/kernel/k1.fard               41
   src/kernel/keypair.fard          40
   src/kernel/canonical.fard        28
   src/kernel/gossip.fard           30
   src/services/policyd.fard        34
   ──────────────────────────────────
   source total                  1,409
   test total                      970
   grand total                   2,379

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

   EOS       2,379 lines   epistemic kernel      claims, gates, witnesses, blobs, gossip, challenges
   Anka     14,506 lines   coordination layer    mesh, audit trail, discovery, reputation, federation
   Azim      4,694 lines   training layer        receipts, corpus, verification, coding agent
   FARD      runtime       deterministic, receipted, self-hosting (Stage 8)
   ──────────────────────────────────────────────────────────────────────────
   Total    21,579 lines   across 222 files

---

## Repositories

   github.com/mauludsadiq/EOS      this repo — epistemic kernel
   github.com/mauludsadiq/Anka     coordination mesh (14,506 lines, 153 files)
   github.com/mauludsadiq/Azim     deterministic AI training (19,200 lines, 192 files)

---

## License

MUI
