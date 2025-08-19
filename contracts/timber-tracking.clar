;; ForestGuard Timber Tracking Contract
;; Clarity v2 (using latest syntax as of Stacks 2.1+)
;; Tracks timber batches with provenance, ownership transfers, compliance verification via oracle,
;; and immutable history logs. Supports batch registration, splitting, merging, and certification updates.
;; Designed for robustness: admin controls, pausing, detailed metadata, and anti-fraud measures.

(define-constant ERR-NOT-AUTHORIZED u100)
(define-constant ERR-INVALID-BATCH-ID u101)
(define-constant ERR-INSUFFICIENT-QUANTITY u102)
(define-constant ERR-BATCH-ALREADY-EXISTS u103)
(define-constant ERR-PAUSED u104)
(define-constant ERR-ZERO-ADDRESS u105)
(define-constant ERR-INVALID-METADATA u106)
(define-constant ERR-NOT-OWNER u107)
(define-constant ERR-MERGE-MISMATCH u108)
(define-constant ERR-ORACLE-ONLY u109)
(define-constant ERR-INVALID-STATUS u110)
(define-constant ERR-SPLIT-OVERFLOW u111)

;; Batch status enums (using uint for simplicity)
(define-constant STATUS-PENDING u0) ;; Newly registered, awaiting verification
(define-constant STATUS_VERIFIED u1) ;; Compliant and certified
(define-constant STATUS_HARVESTED u2) ;; Processed but tracked
(define-constant STATUS_INVALID u3) ;; Failed compliance

;; Admin and contract state
(define-data-var admin principal tx-sender)
(define-data-var paused bool false)
(define-data-var oracle principal tx-sender) ;; Oracle principal for verifications
(define-data-var next-batch-id uint u1) ;; Auto-incrementing ID

;; Core data structures
(define-map batches uint
  {
    owner: principal,
    quantity: uint, ;; In cubic meters or units
    origin: (string-ascii 256), ;; GPS or location description
    harvest-date: uint, ;; Block height or timestamp
    certifications: (list 10 (string-ascii 64)), ;; List of cert strings
    status: uint ;; One of the STATUS constants
  }
)

(define-map batch-history uint (list 50 {timestamp: uint, action: (string-ascii 32), from: (optional principal), to: (optional principal)}))

;; Private helper: is-admin
(define-private (is-admin)
  (is-eq tx-sender (var-get admin))
)

;; Private helper: is-oracle
(define-private (is-oracle)
  (is-eq tx-sender (var-get oracle))
)

;; Private helper: ensure not paused
(define-private (ensure-not-paused)
  (asserts! (not (var-get paused)) (err ERR-PAUSED))
)

;; Private helper: validate principal
(define-private (validate-principal (p principal))
  (not (is-eq p 'SP000000000000000000002Q6VF78))
)

;; Transfer admin rights
(define-public (transfer-admin (new-admin principal))
  (begin
    (asserts! (is-admin) (err ERR-NOT-AUTHORIZED))
    (asserts! (validate-principal new-admin) (err ERR-ZERO-ADDRESS))
    (var-set admin new-admin)
    (ok true)
  )
)

;; Set oracle principal
(define-public (set-oracle (new-oracle principal))
  (begin
    (asserts! (is-admin) (err ERR-NOT-AUTHORIZED))
    (asserts! (validate-principal new-oracle) (err ERR-ZERO-ADDRESS))
    (var-set oracle new-oracle)
    (ok true)
  )
)

;; Pause/unpause the contract
(define-public (set-paused (pause bool))
  (begin
    (asserts! (is-admin) (err ERR-NOT-AUTHORIZED))
    (var-set paused pause)
    (ok pause)
  )
)

;; Register a new timber batch
(define-public (register-batch (quantity uint) (origin (string-ascii 256)) (harvest-date uint) (initial-certs (list 10 (string-ascii 64))))
  (begin
    (ensure-not-paused)
    (asserts! (is-admin) (err ERR-NOT-AUTHORIZED)) ;; Only admin can register initially
    (asserts! (> quantity u0) (err ERR-INSUFFICIENT-QUANTITY))
    (asserts! (> (len origin) u0) (err ERR-INVALID-METADATA))
    (let ((batch-id (var-get next-batch-id)))
      (asserts! (is-none (map-get? batches batch-id)) (err ERR-BATCH-ALREADY-EXISTS))
      (map-set batches batch-id
        {
          owner: tx-sender,
          quantity: quantity,
          origin: origin,
          harvest-date: harvest-date,
          certifications: initial-certs,
          status: STATUS-PENDING
        }
      )
      ;; Initialize history with registration
      (map-set batch-history batch-id (list {timestamp: block-height, action: "registered", from: none, to: (some tx-sender)}))
      (var-set next-batch-id (+ batch-id u1))
      (ok batch-id)
    )
  )
)

;; Transfer ownership of a batch
(define-public (transfer-ownership (batch-id uint) (new-owner principal))
  (begin
    (ensure-not-paused)
    (asserts! (validate-principal new-owner) (err ERR-ZERO-ADDRESS))
    (match (map-get? batches batch-id)
      some-batch
        (begin
          (asserts! (is-eq (get owner some-batch) tx-sender) (err ERR-NOT-OWNER))
          (asserts! (not (is-eq (get status some-batch) STATUS_INVALID)) (err ERR-INVALID-STATUS))
          (map-set batches batch-id (merge some-batch {owner: new-owner}))
          ;; Append to history
          (map-set batch-history batch-id
            (append (default-to (list) (map-get? batch-history batch-id))
              {timestamp: block-height, action: "transferred", from: (some tx-sender), to: (some new-owner)}
            )
          )
          (ok true)
        )
      (err ERR-INVALID-BATCH-ID)
    )
  )
)

;; Split a batch into two (e.g., for partial sales)
(define-public (split-batch (batch-id uint) (split-quantity uint))
  (begin
    (ensure-not-paused)
    (match (map-get? batches batch-id)
      some-batch
        (begin
          (asserts! (is-eq (get owner some-batch) tx-sender) (err ERR-NOT-OWNER))
          (asserts! (and (> split-quantity u0) (< split-quantity (get quantity some-batch))) (err ERR-INSUFFICIENT-QUANTITY))
          (let ((remaining-quantity (- (get quantity some-batch) split-quantity))
                (new-batch-id (var-get next-batch-id)))
            ;; Update original batch
            (map-set batches batch-id (merge some-batch {quantity: remaining-quantity}))
            ;; Create new batch with same metadata
            (map-set batches new-batch-id
              {
                owner: tx-sender,
                quantity: split-quantity,
                origin: (get origin some-batch),
                harvest-date: (get harvest-date some-batch),
                certifications: (get certifications some-batch),
                status: (get status some-batch)
              }
            )
            ;; History for split
            (map-set batch-history batch-id
              (append (default-to (list) (map-get? batch-history batch-id))
                {timestamp: block-height, action: "split", from: (some batch-id), to: (some new-batch-id)}
              )
            )
            (map-set batch-history new-batch-id
              (list {timestamp: block-height, action: "created_from_split", from: (some batch-id), to: (some tx-sender)})
            )
            (var-set next-batch-id (+ new-batch-id u1))
            (ok new-batch-id)
          )
        )
      (err ERR-INVALID-BATCH-ID)
    )
  )
)

;; Merge two batches (same origin, certs, etc.)
(define-public (merge-batches (batch-id1 uint) (batch-id2 uint))
  (begin
    (ensure-not-paused)
    (match (map-get? batches batch-id1)
      batch1
        (match (map-get? batches batch-id2)
          batch2
            (begin
              (asserts! (is-eq (get owner batch1) tx-sender) (err ERR-NOT-OWNER))
              (asserts! (is-eq (get owner batch2) tx-sender) (err ERR-NOT-OWNER))
              (asserts! (and (is-eq (get origin batch1) (get origin batch2))
                             (is-eq (get harvest-date batch1) (get harvest-date batch2))
                             (is-eq (get status batch1) (get status batch2))) (err ERR-MERGE-MISMATCH))
              (let ((new-quantity (+ (get quantity batch1) (get quantity batch2))))
                ;; Update batch1, delete batch2
                (map-set batches batch-id1 (merge batch1 {quantity: new-quantity}))
                (map-delete batches batch-id2)
                ;; History
                (map-set batch-history batch-id1
                  (append (default-to (list) (map-get? batch-history batch-id1))
                    {timestamp: block-height, action: "merged", from: (some batch-id2), to: none}
                  )
                )
                (ok true)
              )
            )
          (err ERR-INVALID-BATCH-ID)
        )
      (err ERR-INVALID-BATCH-ID)
    )
  )
)

;; Oracle: Verify compliance and update status
(define-public (verify-compliance (batch-id uint) (new-status uint) (additional-cert (optional (string-ascii 64))))
  (begin
    (asserts! (is-oracle) (err ERR-ORACLE-ONLY))
    (asserts! (or (is-eq new-status STATUS_VERIFIED) (is-eq new-status STATUS_INVALID)) (err ERR-INVALID-STATUS))
    (match (map-get? batches batch-id)
      some-batch
        (begin
          (let ((new-certs (match additional-cert cert (append (get certifications some-batch) (list cert)) (get certifications some-batch))))
            (map-set batches batch-id (merge some-batch {status: new-status, certifications: new-certs}))
            ;; History
            (map-set batch-history batch-id
              (append (default-to (list) (map-get? batch-history batch-id))
                {timestamp: block-height, action: "verified", from: none, to: none}
              )
            )
            (ok true)
          )
        )
      (err ERR-INVALID-BATCH-ID)
    )
  )
)

;; Read-only: Get batch details
(define-read-only (get-batch-details (batch-id uint))
  (ok (map-get? batches batch-id))
)

;; Read-only: Get batch history
(define-read-only (get-batch-history (batch-id uint))
  (ok (map-get? batch-history batch-id))
)

;; Read-only: Get next batch ID
(define-read-only (get-next-batch-id)
  (ok (var-get next-batch-id))
)

;; Read-only: Get admin
(define-read-only (get-admin)
  (ok (var-get admin))
)

;; Read-only: Get oracle
(define-read-only (get-oracle)
  (ok (var-get oracle))
)

;; Read-only: Check if paused
(define-read-only (is-paused)
  (ok (var-get paused))
)

;; Read-only: Check if batch is compliant
(define-read-only (is-compliant (batch-id uint))
  (match (map-get? batches batch-id)
    some-batch (ok (is-eq (get status some-batch) STATUS_VERIFIED))
    (ok false)
  )
)