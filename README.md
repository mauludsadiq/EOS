# EOS — Epistemic Operating System

**A deterministic, cryptographically-verifiable micro-OS written entirely in FARD.**

EOS is a kernel whose primitives are not files, processes, and sockets — they are
content-addressed blobs, signed claims, policy gates, witnesses, gossip, and challenges.
Every operation is deterministic, auditable, and policy-enforced.

EOS is the substrate layer beneath Anka (cross-institutional AI coordination),
Azim (deterministic AI training), and Fard Dinar (deterministic monetary protocol).
Claims flow up from EOS into the Anka mesh. Training receipts flow down from Azim.
Every Fard Dinar transaction receipt becomes a signed, witnessed, auditable eOS claim.

---

## By the numbers

    2,948 lines of FARD
      143 tests, 0 failures
       25 source files
       17 test files
       11 commits

    Live Anka node after integration tests:
       15 claims on mesh
       12 witnesses recorded

    Stack position:
      EOS          2,948 lines   epistemic kernel (this repo)
      Anka        14,506 lines   coordination mesh
      Azim         4,694 lines   deterministic AI training
      Fard Dinar   ~2,000 lines  deterministic monetary protocol
      Total       24,148 lines

---

## Architecture

    Fard Dinar (monetary receipts)    Azim (training receipts)     Anka (mesh)
             |                                |                        ^
      fard_dinar/bridge              azim/bridge              anka/bridge
      fard_dinar/claim               azim/claim               witness_bridge
      fard_dinar/policy                      |                discover
             |                              |                        |
             +------------------  kernel  --+------------------------+
                                     |
             +--------+--------+-----+----+----------+----------+
             k1     claim     gate  witness   gossip    challenge
           (blobs) (signing) (policy) (attest) (pub/sub)  (PoP)
             |        |        |
         canonical  keypair  compile
                          |
                     jurisdictions (EOS + FD)
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
                  contest_claim, verify_contest, pub_gossip, sub_gossip,
                  write_blob, read_blob

---

## Policy Layer

    policy/compile        Compiles JSON policy files to executable op-list bytecode.
                          Bytecode = canonical JSON { ops: [...] }
                          Portable, inspectable, re-evaluable without recompilation.

    policy/jurisdictions  Named constants for all known EOS claim spaces (17).

    fard_dinar/policy     Gate policies specific to Fard Dinar:
                          transfer_policy, deposit_policy, treasury_policy,
                          fresh_deposit_policy, open_policy
                          eval_transfer, eval_deposit, eval_treasury, eval_open

Known EOS jurisdictions (17):

    Regulatory    FDA_US_2025, EMA_EU_2025, MHRA_UK_2025, PMDA_JP_2025,
                  TGA_AU_2025, ANVISA_BR_2025
    AI            AZIM_TRAIN_V1, AZIM_EVAL_V1, AZIM_CODE_V1
    Coordination  ANKA_MESH_V1, ANKA_WITNESS_V1, ANKA_ORIGIN_V1
    Research      NIST_US_2025, NIH_US_2025, PUBMED_GLOBAL
    Finance       SEC_US_2025, FCA_UK_2025

Known Fard Dinar jurisdictions (5):

    FARD_DINAR_TX_V1        transfer receipts
    FARD_DINAR_DEPOSIT_V1   oracle-attested deposits
    FARD_DINAR_ORACLE_V1    oracle identity claims
    FARD_DINAR_STATE_V1     state snapshots
    FARD_DINAR_TREASURY_V1  treasury operations (RepMin 10)

Gate ops:

    RepMin(n)       pass if ctx.reputation >= n
    AgeMax(secs)    pass if now - claim.timestamp_unix_secs <= secs
    JurAllow([...]) pass if claim.claim_space in list
    And             pop 2, push (a && b)
    Or              pop 2, push (a || b)
    Glb(n)          pop n, push conjunction of all

---

## Anka Integration

    anka/bridge           Publish signed eOS claim envelopes to Anka mesh node.
                          publish_envelope, publish_claim, query, audit_trail

    anka/witness_bridge   Submit witness records to Anka /witness endpoint.
                          submit_structural / submit_semantic / submit_cryptographic
                          build_and_submit: build local eOS witness AND notify Anka

    anka/discover         Capability discovery — find agents by what they can do.
                          register_node, by_capability, by_institution, best
                          Local cache: new_cache / cache_entry / lookup / refresh

---

## Azim Integration

    azim/bridge    Wraps Azim training receipts as eOS claims in AZIM.TRAIN.v1.
                   receipt_to_claim, publish_receipt, verify_receipt_chain

Current Azim training results, receipted as eOS claims:

    Round 1:  5.3168 -> 5.3127   Round 16: 2.4111 -> 2.4087
    Random baseline: 4.86        Current:  2.41 (50% below random)

---

## Fard Dinar Integration

    fard_dinar/jurisdictions   5 FD claim space constants + is_fard_dinar predicate

    fard_dinar/claim           Convert FD engine receipts to eOS claim envelopes.
                               receipt_to_envelope(kernel, event, receipt, timestamp)
                               transfer  -> FARD_DINAR.TX.v1
                               deposit   -> FARD_DINAR.DEPOSIT.v1
                               snapshot  -> FARD_DINAR.STATE.v1
                               evidence_refs: [run_id, trace_hash]

    fard_dinar/policy          Gate policies for FD transactions.
                               transfer_policy: JurAllow TX.v1
                               deposit_policy:  JurAllow + RepMin(1)
                               treasury_policy: JurAllow + RepMin(10)
                               fresh_deposit_policy: JurAllow + AgeMax(86400)

    fard_dinar/bridge          Full pipeline: FD receipt -> gate -> Anka -> witness
                               publish_receipt(anka_client, kernel, event, receipt, ts)
                               publish_state_snapshot, query_tx, audit_tx

Live end-to-end verified:

    FD engine replay (AHD-1024 + Ed25519)
      canonical_event_set: 4 events (2 deposits, 2 transfers)
      final supply: 100,012,500 (matches Rust reference implementation)
      receipts: AHD-1024 tagged run_ids
            |
    eOS kernel (sha256 + Ed25519)
      signed claim envelopes per receipt
      all pass open_policy gate
      all signatures verified
            |
    Anka mesh (localhost:18080)
      15 claims published
      12 witnesses recorded
      audit trail queryable per claim

---

## Service Layer

    gatewayd      HTTP gateway — evaluate claims at ingress.
                  POST /eval, POST /compile, GET /health
                  Port: GATEWAYD_PORT (default 7700)

    witnessd      HTTP service — collect, verify, forward witnesses.
                  POST /witness, POST /witness/raw, GET /witness/pending
                  Port: WITNESSD_PORT (default 7701)

    telemetryd    HTTP service — signed trace events as eOS claims.
                  POST /emit, GET /events, GET /events/:kind, GET /health
                  Port: TELEMETRYD_PORT (default 7702)
                  Persistence: SQLite. Forwarding to Anka mesh.

    policyd       CLI — compile policy JSON to bytecode.

---

## Test Suite

    tests/test_k1.fard               4 tests    blob store
    tests/test_claim.fard            3 tests    claim mint/verify
    tests/test_gate.fard             7 tests    GateVM evaluation
    tests/test_witness.fard          5 tests    witness build/verify
    tests/test_kernel.fard           7 tests    kernel integration
    tests/test_azim_bridge.fard      6 tests    Azim receipt claims
    tests/test_policy_compile.fard   6 tests    policy compilation
    tests/test_fda_policy.fard       4 tests    FDA fixture end-to-end
    tests/test_witnessd.fard         8 tests    witnessd logic
    tests/test_challenge.fard       10 tests    PoP + claim contest
    tests/test_discover.fard        14 tests    capability discovery + cache
    tests/test_jurisdictions.fard   16 tests    jurisdiction constants
    tests/test_telemetryd.fard      10 tests    telemetry claims
    tests/test_anka_live.fard        7 tests    live Anka integration
    tests/test_fd_claim.fard        13 tests    FD receipt -> eOS claim
    tests/test_fd_policy.fard       11 tests    FD gate policies
    tests/test_fd_live.fard         12 tests    live FD engine -> Anka
    ─────────────────────────────────────────────────────────
    total                          143 tests    0 failures

    Offline tests: all except test_anka_live.fard and test_fd_live.fard
    Live tests require: Anka node on localhost:18080, AHD binary

Run all tests:

    bash run_tests.sh

---

## Line counts

    src/anka/discover.fard           212
    src/services/telemetryd.fard     206
    src/services/witnessd.fard       129
    src/kernel/challenge.fard        116
    src/fard_dinar/bridge.fard        74
    src/fard_dinar/claim.fard         72
    src/fard_dinar/policy.fard        68
    src/fard_dinar/jurisdictions.fard 22
    src/policy/jurisdictions.fard     89
    src/kernel/gate.fard              89
    src/kernel/kernel.fard            88
    src/kernel/claim.fard             86
    src/anka/bridge.fard              71
    src/kernel/witness.fard           68
    src/services/gatewayd.fard        61
    src/anka/witness_bridge.fard      55
    src/policy/compile.fard           46
    src/azim/bridge.fard              39
    src/kernel/k1.fard                41
    src/kernel/keypair.fard           40
    src/kernel/canonical.fard         28
    src/kernel/gossip.fard            30
    src/services/policyd.fard         34
    ──────────────────────────────────
    source total               ~1,663
    test total                  ~1,285
    grand total                  2,948

---

## Runtime

    Language:    FARD v1.7.0
    Runtime:     fardrun
    Crypto:      Ed25519 via std/crypto
    Hashing:     SHA-256 (eOS) + AHD-1024 (Fard Dinar) via external binary
    Storage:     In-memory (k1, gossip) — SQLite in telemetryd and Anka node
    Tracing:     std/trace — every telemetry emit is traced

---

## Stack

    EOS          2,948 lines   epistemic kernel
    Anka        14,506 lines   coordination mesh
    Azim         4,694 lines   deterministic AI training
    Fard Dinar  ~2,000 lines   deterministic monetary protocol
    FARD         runtime       deterministic, receipted, self-hosting
    ─────────────────────────────────────────────────────────
    Total       24,148 lines

---

## Repositories

    github.com/mauludsadiq/EOS      this repo — epistemic kernel
    github.com/mauludsadiq/Anka     coordination mesh (14,506 lines)
    github.com/mauludsadiq/Azim     deterministic AI training (19,200 lines)

---

## License

MUI
