;; EventCred
;; A POAP (Proof of Attendance Protocol) smart contract with rewards

(define-non-fungible-token event-badge uint)
(define-non-fungible-token reward-token uint)

(define-map events 
    { event-id: uint } 
    { 
        name: (string-ascii 50),
        date: uint,
        max-participants: uint,
        current-participants: uint,
        reward-points: uint
    }
)

(define-map participant-badges 
    { participant: principal } 
    { badges: (list 100 uint) }
)

(define-map participant-rewards
    { participant: principal }
    { 
        total-points: uint,
        redeemed-points: uint
    }
)

(define-map event-participants
    { event-id: uint }
    { participants: (list 1000 principal) }
)

(define-data-var badge-counter uint u0)
(define-data-var event-counter uint u0)

;; Error constants
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-EVENT-FULL (err u101))
(define-constant ERR-ALREADY-REGISTERED (err u102))
(define-constant ERR-INSUFFICIENT-POINTS (err u103))
(define-constant ERR-POINTS-AWARD-FAILED (err u104))

;; Administrative Functions

(define-public (create-event (name (string-ascii 50)) (date uint) (max-participants uint) (reward-points uint))
    (let
        ((event-id (+ (var-get event-counter) u1)))
        (try! (is-contract-owner))
        (map-set events 
            { event-id: event-id }
            {
                name: name,
                date: date,
                max-participants: max-participants,
                current-participants: u0,
                reward-points: reward-points
            }
        )
        (var-set event-counter event-id)
        (ok event-id)
    )
)

;; Participant Functions

(define-public (register-for-event (event-id uint))
    (let
        ((event (unwrap! (map-get? events { event-id: event-id }) (err u404)))
         (current-count (get current-participants event))
         (max-count (get max-participants event)))
        
        ;; Check if event is full
        (asserts! (< current-count max-count) ERR-EVENT-FULL)
        
        ;; Check if participant is already registered
        (asserts! (is-not-registered tx-sender event-id) ERR-ALREADY-REGISTERED)
        
        ;; Mint badge
        (let
            ((badge-id (+ (var-get badge-counter) u1))
             (points-result (award-points tx-sender (get reward-points event))))
            
            ;; Ensure points were awarded successfully
            (unwrap! points-result ERR-POINTS-AWARD-FAILED)
            
            ;; Update badge counter
            (var-set badge-counter badge-id)
            
            ;; Mint NFT badge
            (try! (nft-mint? event-badge badge-id tx-sender))
            
            ;; Update participant badges
            (map-set participant-badges
                { participant: tx-sender }
                { badges: (append-badge (default-to (list ) (get badges (map-get? participant-badges { participant: tx-sender }))) badge-id) }
            )
            
            ;; Update event participants
            (map-set events 
                { event-id: event-id }
                (merge event { current-participants: (+ current-count u1) })
            )
            
            (ok badge-id)
        )
    )
)

(define-public (redeem-rewards (points uint))
    (let
        ((participant-info (unwrap! (map-get? participant-rewards { participant: tx-sender }) (err u404)))
         (available-points (- (get total-points participant-info) (get redeemed-points participant-info))))
        
        ;; Check if participant has enough points
        (asserts! (>= available-points points) ERR-INSUFFICIENT-POINTS)
        
        ;; Update redeemed points
        (map-set participant-rewards
            { participant: tx-sender }
            { 
                total-points: (get total-points participant-info),
                redeemed-points: (+ (get redeemed-points participant-info) points)
            }
        )
        
        (ok points)
    )
)

;; Helper Functions

(define-private (is-contract-owner)
    (ok (asserts! (is-eq tx-sender contract-caller) ERR-NOT-AUTHORIZED))
)

(define-private (is-not-registered (participant principal) (event-id uint))
    (is-none (index-of 
        (default-to (list ) 
            (get participants (map-get? event-participants { event-id: event-id }))
        )
        participant
    ))
)

(define-private (append-badge (badges (list 100 uint)) (badge-id uint))
    (unwrap! (as-max-len? (append badges badge-id) u100) badges)
)

(define-private (award-points (participant principal) (points uint))
    (let
        ((current-rewards (default-to { total-points: u0, redeemed-points: u0 } 
            (map-get? participant-rewards { participant: participant }))))
        (map-set participant-rewards
            { participant: participant }
            {
                total-points: (+ (get total-points current-rewards) points),
                redeemed-points: (get redeemed-points current-rewards)
            }
        )
        (ok points)
    )
)

;; Read-Only Functions

(define-read-only (get-participant-badges (participant principal))
    (map-get? participant-badges { participant: participant })
)

(define-read-only (get-participant-rewards (participant principal))
    (map-get? participant-rewards { participant: participant })
)

(define-read-only (get-event-details (event-id uint))
    (map-get? events { event-id: event-id })
)

(define-read-only (get-event-participants (event-id uint))
    (map-get? event-participants { event-id: event-id })
)