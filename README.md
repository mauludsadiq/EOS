# EOS — Epistemic Operating System

**A deterministic, cryptographically-verifiable micro-OS written entirely in FARD.**

EOS is a kernel whose primitives are not files, processes, and sockets — they are
content-addressed blobs, signed claims, policy gates, witnesses, and gossip.
Every operation is deterministic, auditable, and policy-enforced.

EOS is the substrate layer beneath Anka (cross-institutional AI coordination) and
Azim (deterministic AI training). Claims flow up from EOS into the Anka mesh.
Training receipts flow down from Azim into EOS as verifiable claims.

---

## Architecture

   Azim (training receipts)       Anka (mesh coordination)
            |                              ^
       azim/bridge                anka/bridge, witness_bridge
            |                              |
            +------------ kernel ----------+
                               |
               +-----------+---+----------+
               k1        claims         gates
            (blobs)     (signing)     (policy)
               |             |             |
           canonical      keypair       compile
               +-------------|------------+
                           gossip
                          witnesses

---

## Kernel Primitives

   k1          Content-addressed blob store. write(data) -> sha256:...
               Immutable: same bytes always same digest, no delete.

   canonical   Deterministic JSON serialization (RFC 8785) and SHA-256 digesting.
               All claims must be canonicalized before signing.

   claim       Mint and verify Ed25519-signed epistemic claims.
               A claim: who said what about what, when, in which jurisdiction.
               An envelope: claim + digest_hex + issuer_signature_hex.

   gate        RPN stack machine for policy evaluation.
               Ops: RepMin, AgeMax, JurAllow, And, Or, Glb.
               Evaluates claims against compiled policy programs.

   witness     Build and verify independent attestations over claims.
               Supports disagreement records for contested claims.

   gossip      In-memory pub/sub by topic digest.
               In production: HTTP gossip between Anka mesh nodes.

   keypair     Ed25519 key generation, signing, verification.
               Fully interoperable with Anka keypair module.

   kernel      Assembles all six primitives into one record.
               Single entry point for all applications.

---

## Policy Layer

   policy/compile    Compiles JSON policy files to executable op-list bytecode.
                     Bytecode is canonical JSON — portable, inspectable, re-evaluable.

Two policy schemas are supported:

RPN (explicit):

   {
     "rules": [
       {"op": "RepMin", "val": 10},
       {"op": "JurAllow", "list": ["FDA.US.2025"]},
       {"op": "Glb", "n": 2}
     ]
   }

Convenience (auto-compiled to GLB):

   {
     "RepMin": 10,
     "AgeMax": 315360000,
     "JurAllow": ["FDA.US.2025"]
   }

Gate ops:

   RepMin(n)         pass if ctx.reputation >= n
   AgeMax(secs)      pass if now - claim.timestamp <= secs
   JurAllow([...])   pass if claim.claim_space in list
   And               pop 2, push (a && b)
   Or                pop 2, push (a || b)
   Glb(n)            pop n, push conjunction of all

No policy in ctx = allow-all (explicit fallback, intentional for dev).

---

## Anka Integration

   anka/bridge           Publish signed eOS claim envelopes to an Anka mesh node.
                         POST /publish, GET /query, GET /audit/trail.
                         publish_claim(client, kernel, space, subject, ...) mints and publishes in one step.

   anka/witness_bridge   Build and submit witness records to Anka /witness.
                         Supports disagreement witnesses for contested claims.

Anka interop: EOS claim envelopes are structurally identical to Anka claim envelopes.
Same Ed25519 keypair format, same canonical JSON digesting, same sha256: prefix convention.
An EOS node and an Anka node can verify each other's signatures without any adapter.

---

## Azim Integration

   azim/bridge    Wraps Azim training receipts as eOS claims.
                  claim_space: "AZIM.TRAIN.v1"
                  subject: "azim:round:N"
                  predicate: "training_step"
                  object: JSON of {loss_before, loss_after, steps, receipt_digest}
                  evidence_refs: [receipt digest_hex]

                  publish_receipt(anka_client, kernel, receipt, timestamp) mints the
                  claim and publishes it to Anka in one step.

                  verify_receipt_chain(kernel, envelope, policy) gate-checks a receipt
                  claim, allowing policy enforcement over training provenance.

Every Azim training step can be published as an auditable, policy-gated eOS claim.
The full training run becomes a content-addressed, witnessable audit trail in the Anka mesh.

---

## Services

   gatewayd    HTTP service. Evaluates claims against policies at ingress.
               POST /eval    { claim, ctx } -> { ok } | { err }
               POST /compile { policy } -> { ok, bytecode }
               GET  /health  -> { ok, service, node_id }
               Port: GATEWAYD_PORT env var (default 7700)

   policyd     CLI. Compiles a policy JSON file to bytecode.
               fardrun run --program src/services/policyd.fard -- \
                 --input policies/FDA.US.2025.json \
                 --output out/FDA.US.2025.bytecode

---

## Policies

   policies/FDA.US.2025.json    Reference FDA jurisdiction policy fixture.
                                RepMin: 0 (open — any reputation passes).
                                Version: 0.1.0.

---

## Test Suite

   tests/test_k1.fard              4 tests   blob store
   tests/test_claim.fard           3 tests   claim mint/verify
   tests/test_gate.fard            7 tests   GateVM evaluation
   tests/test_witness.fard         5 tests   witness build/verify
   tests/test_kernel.fard          7 tests   kernel integration
   tests/test_azim_bridge.fard     6 tests   Azim receipt claims
   tests/test_policy_compile.fard  6 tests   policy compilation
   tests/test_fda_policy.fard      4 tests   FDA fixture end-to-end
   ─────────────────────────────────────────
   total                          42 tests   0 failures

Run all tests:

   fardrun test --program tests/test_k1.fard
   fardrun test --program tests/test_claim.fard
   fardrun test --program tests/test_gate.fard
   fardrun test --program tests/test_witness.fard
   fardrun test --program tests/test_kernel.fard
   fardrun test --program tests/test_azim_bridge.fard
   fardrun test --program tests/test_policy_compile.fard
   fardrun test --program tests/test_fda_policy.fard

---

## Runtime

   Language:   FARD v1.7.0
   Runtime:    fardrun
   Crypto:     Ed25519 via std/crypto
   Hashing:    SHA-256 via std/hash
   Storage:    In-memory (k1, gossip) — persistent via Anka SQLite in production

---

## Stack

   EOS       epistemic kernel      claims, gates, witnesses, blobs, gossip
   Anka      coordination layer    mesh, audit trail, discovery, reputation
   Azim      training layer        receipts, corpus, verification, coding agent
   FARD      language              deterministic, receipted, self-hosting

---

## Repositories

   github.com/mauludsadiq/EOS      this repo
   github.com/mauludsadiq/Anka     coordination mesh
   github.com/mauludsadiq/Azim     deterministic AI training

---

## License

MUI
