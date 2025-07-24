;; Supply Chain Verification System
;; A platform tracking product journeys from raw materials to consumer
;; with incentives for honest reporting and penalties for false information

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-already-exists (err u103))
(define-constant err-invalid-stage (err u104))
(define-constant err-insufficient-stake (err u105))
(define-constant err-already-verified (err u106))
(define-constant err-verification-period-ended (err u107))

;; Data Variables
(define-data-var next-product-id uint u1)
(define-data-var next-participant-id uint u1)
(define-data-var minimum-stake uint u1000000) ;; 1 STX in micro-STX
(define-data-var verification-period uint u144) ;; ~24 hours in blocks
(define-data-var reward-pool uint u0)

;; Data Maps
(define-map products
  uint
  {
    creator: principal,
    name: (string-utf8 100),
    description: (string-utf8 500),
    current-stage: uint,
    created-at: uint,
    is-active: bool,
    total-verifications: uint,
    reputation-score: uint
  }
)

(define-map product-stages
  {product-id: uint, stage: uint}
  {
    stage-name: (string-utf8 50),
    handler: principal,
    timestamp: uint,
    location: (string-utf8 100),
    verified: bool,
    verifier-count: uint,
    stake-amount: uint
  }
)

(define-map participants
  principal
  {
    participant-id: uint,
    reputation: uint,
    total-verifications: uint,
    successful-verifications: uint,
    stake-balance: uint,
    is-active: bool,
    joined-at: uint
  }
)

(define-map verifications
  {product-id: uint, stage: uint, verifier: principal}
  {
    verified-at: uint,
    is-honest: bool,
    reward-claimed: bool
  }
)

(define-map stage-verifiers
  {product-id: uint, stage: uint}
  (list 10 principal)
)

;; Read-only functions
(define-read-only (get-product (product-id uint))
  (map-get? products product-id)
)

(define-read-only (get-product-stage (product-id uint) (stage uint))
  (map-get? product-stages {product-id: product-id, stage: stage})
)

(define-read-only (get-participant (participant principal))
  (map-get? participants participant)
)

(define-read-only (get-verification (product-id uint) (stage uint) (verifier principal))
  (map-get? verifications {product-id: product-id, stage: stage, verifier: verifier})
)

(define-read-only (get-contract-info)
  {
    next-product-id: (var-get next-product-id),
    next-participant-id: (var-get next-participant-id),
    minimum-stake: (var-get minimum-stake),
    verification-period: (var-get verification-period),
    reward-pool: (var-get reward-pool)
  }
)

(define-read-only (calculate-reputation-score (successful uint) (total uint))
  (if (is-eq total u0)
    u50
    (/ (* successful u100) total)
  )
)

;; Private functions
(define-private (is-contract-owner)
  (is-eq tx-sender contract-owner)
)

(define-private (update-participant-reputation (participant principal) (is-honest bool))
  (let (
    (participant-data (unwrap! (map-get? participants participant) false))
    (new-total (+ (get total-verifications participant-data) u1))
    (new-successful (if is-honest 
                      (+ (get successful-verifications participant-data) u1)
                      (get successful-verifications participant-data)))
    (new-reputation (calculate-reputation-score new-successful new-total))
  )
    (map-set participants participant
      (merge participant-data {
        total-verifications: new-total,
        successful-verifications: new-successful,
        reputation: new-reputation
      })
    )
    true
  )
)

;; Public functions
(define-public (register-participant)
  (let (
    (participant-id (var-get next-participant-id))
  )
    (asserts! (is-none (map-get? participants tx-sender)) err-already-exists)
    
    (map-set participants tx-sender {
      participant-id: participant-id,
      reputation: u50,
      total-verifications: u0,
      successful-verifications: u0,
      stake-balance: u0,
      is-active: true,
      joined-at: block-height
    })
    
    (var-set next-participant-id (+ participant-id u1))
    (ok participant-id)
  )
)

(define-public (create-product (name (string-utf8 100)) (description (string-utf8 500)))
  (let (
    (product-id (var-get next-product-id))
    (participant-data (unwrap! (map-get? participants tx-sender) err-unauthorized))
  )
    (asserts! (get is-active participant-data) err-unauthorized)
    
    (map-set products product-id {
      creator: tx-sender,
      name: name,
      description: description,
      current-stage: u0,
      created-at: block-height,
      is-active: true,
      total-verifications: u0,
      reputation-score: u0
    })
    
    (var-set next-product-id (+ product-id u1))
    (ok product-id)
  )
)

(define-public (add-stage (product-id uint) (stage-name (string-utf8 50)) (location (string-utf8 100)))
  (let (
    (product-data (unwrap! (map-get? products product-id) err-not-found))
    (current-stage (get current-stage product-data))
    (new-stage (+ current-stage u1))
  )
    (asserts! (is-eq tx-sender (get creator product-data)) err-unauthorized)
    (asserts! (get is-active product-data) err-unauthorized)
    
    (map-set product-stages {product-id: product-id, stage: new-stage} {
      stage-name: stage-name,
      handler: tx-sender,
      timestamp: block-height,
      location: location,
      verified: false,
      verifier-count: u0,
      stake-amount: u0
    })
    
    (map-set products product-id
      (merge product-data {current-stage: new-stage})
    )
    
    (ok new-stage)
  )
)

(define-public (stake-tokens (amount uint))
  (let (
    (participant-data (unwrap! (map-get? participants tx-sender) err-unauthorized))
  )
    (asserts! (>= amount (var-get minimum-stake)) err-insufficient-stake)
    
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    
    (map-set participants tx-sender
      (merge participant-data {
        stake-balance: (+ (get stake-balance participant-data) amount)
      })
    )
    
    (var-set reward-pool (+ (var-get reward-pool) (/ amount u10))) ;; 10% goes to reward pool
    (ok true)
  )
)

(define-public (verify-stage (product-id uint) (stage uint) (is-honest bool))
  (let (
    (participant-data (unwrap! (map-get? participants tx-sender) err-unauthorized))
    (stage-data (unwrap! (map-get? product-stages {product-id: product-id, stage: stage}) err-not-found))
    (product-data (unwrap! (map-get? products product-id) err-not-found))
    (stake-required (var-get minimum-stake))
  )
    (asserts! (get is-active participant-data) err-unauthorized)
    (asserts! (>= (get stake-balance participant-data) stake-required) err-insufficient-stake)
    (asserts! (is-none (map-get? verifications {product-id: product-id, stage: stage, verifier: tx-sender})) err-already-verified)
    (asserts! (<= (- block-height (get timestamp stage-data)) (var-get verification-period)) err-verification-period-ended)
    
    ;; Record verification
    (map-set verifications {product-id: product-id, stage: stage, verifier: tx-sender} {
      verified-at: block-height,
      is-honest: is-honest,
      reward-claimed: false
    })
    
    ;; Update stage data
    (map-set product-stages {product-id: product-id, stage: stage}
      (merge stage-data {
        verifier-count: (+ (get verifier-count stage-data) u1),
        stake-amount: (+ (get stake-amount stage-data) stake-required)
      })
    )
    
    ;; Update participant stake
    (map-set participants tx-sender
      (merge participant-data {
        stake-balance: (- (get stake-balance participant-data) stake-required)
      })
    )
    
    ;; Update reputation
    (update-participant-reputation tx-sender is-honest)
    
    (ok true)
  )
)

(define-public (finalize-stage (product-id uint) (stage uint))
  (let (
    (stage-data (unwrap! (map-get? product-stages {product-id: product-id, stage: stage}) err-not-found))
    (product-data (unwrap! (map-get? products product-id) err-not-found))
  )
    (asserts! (is-eq tx-sender (get creator product-data)) err-unauthorized)
    (asserts! (> (get verifier-count stage-data) u2) err-insufficient-stake) ;; At least 3 verifications
    
    (map-set product-stages {product-id: product-id, stage: stage}
      (merge stage-data {verified: true})
    )
    
    (ok true)
  )
)

(define-public (claim-reward (product-id uint) (stage uint))
  (let (
    (verification-data (unwrap! (map-get? verifications {product-id: product-id, stage: stage, verifier: tx-sender}) err-not-found))
    (stage-data (unwrap! (map-get? product-stages {product-id: product-id, stage: stage}) err-not-found))
    (participant-data (unwrap! (map-get? participants tx-sender) err-unauthorized))
    (reward-amount (/ (var-get minimum-stake) u2)) ;; 50% of stake as reward
  )
    (asserts! (get verified stage-data) err-unauthorized)
    (asserts! (not (get reward-claimed verification-data)) err-already-verified)
    (asserts! (get is-honest verification-data) err-unauthorized)
    
    (try! (as-contract (stx-transfer? reward-amount tx-sender tx-sender)))
    
    (map-set verifications {product-id: product-id, stage: stage, verifier: tx-sender}
      (merge verification-data {reward-claimed: true})
    )
    
    (ok reward-amount)
  )
)

(define-public (update-minimum-stake (new-stake uint))
  (begin
    (asserts! (is-contract-owner) err-owner-only)
    (var-set minimum-stake new-stake)
    (ok true)
  )
)

(define-public (update-verification-period (new-period uint))
  (begin
    (asserts! (is-contract-owner) err-owner-only)
    (var-set verification-period new-period)
    (ok true)
  )
)

(define-public (emergency-pause-product (product-id uint))
  (let (
    (product-data (unwrap! (map-get? products product-id) err-not-found))
  )
    (asserts! (is-contract-owner) err-owner-only)
    
    (map-set products product-id
      (merge product-data {is-active: false})
    )
    
    (ok true)
  )
)