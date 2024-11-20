;; EventCred
;; A POAP (Proof of Attendance Protocol) smart contract with cross-platform rewards

(define-non-fungible-token event-badge uint)
(define-non-fungible-token reward-token uint)

(define-map events 
    { event-id: uint } 
    { 
        name: (string-ascii 50),
        date: uint,
        max-participants: uint,
        current-participants: uint,
        reward-points: uint,
        platform-tags: (list 10 (string-ascii 20))
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
        redeemed-points: uint,
        cross-platform-multipliers: (list 10 uint)
    }
)

(define-map event-participants
    { event-id: uint }
    { participants: (list 1000 principal) }
)

(define-map platform-alliances
    { platform-tag: (string-ascii 20) }
    { alliance-multiplier: uint }
)

(define-data-var badge-counter uint u0)
(define-data-var event-counter uint u0)

;; Error constants
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-EVENT-FULL (err u101))
(define-constant ERR-ALREADY-REGISTERED (err u102))
(define-constant ERR-INSUFFICIENT-POINTS (err u103))
(define-constant ERR-POINTS-AWARD-FAILED (err u104))
(define-constant ERR-INVALID-EVENT-PARAMS (err u105))
(define-constant ERR-PLATFORM-NOT-FOUND (err u106))
(define-constant ERR-INVALID-PLATFORM-TAG (err u107))

;; Validation Constants
(define-constant MAX-EVENT-NAME-LENGTH u50)
(define-constant MAX-PARTICIPANTS u1000)
(define-constant MAX-REWARD-POINTS u10000)
(define-constant MAX-PLATFORM-TAGS u10)
(define-constant MAX-ALLIANCE-MULTIPLIER u5)
(define-constant MAX-PLATFORM-TAG-LENGTH u20)

;; Administrative Functions

(define-public (create-platform-alliance 
    (platform-tag (string-ascii 20)) 
    (multiplier uint)
)
    (begin
        ;; Validate platform-tag
        (asserts! 
            (and 
                (> (len platform-tag) u0)
                (<= (len platform-tag) MAX-PLATFORM-TAG-LENGTH)
            ) 
            ERR-INVALID-PLATFORM-TAG
        )

        ;; Validate multiplier
        (asserts! 
            (and 
                (> multiplier u0)
                (<= multiplier MAX-ALLIANCE-MULTIPLIER)
            ) 
            ERR-INVALID-EVENT-PARAMS
        )

        (try! (is-contract-owner))
        (map-set platform-alliances 
            { platform-tag: platform-tag }
            { alliance-multiplier: multiplier }
        )
        (ok platform-tag)
    )
)

(define-public (create-event 
    (name (string-ascii 50)) 
    (date uint) 
    (max-participants uint) 
    (reward-points uint)
    (platform-tags (list 10 (string-ascii 20)))
)
    ;; Input validation
    (begin
        ;; Validate event name length
        (asserts! 
            (and 
                (> (len name) u0)
                (<= (len name) MAX-EVENT-NAME-LENGTH)
            ) 
            ERR-INVALID-EVENT-PARAMS
        )

        ;; Validate platform tags
        (asserts! 
            (<= (len platform-tags) MAX-PLATFORM-TAGS) 
            ERR-INVALID-EVENT-PARAMS
        )

        ;; Validate date (ensure it's a future date)
        (asserts! (> date block-height) ERR-INVALID-EVENT-PARAMS)

        ;; Validate max participants
        (asserts! 
            (and 
                (> max-participants u0)
                (<= max-participants MAX-PARTICIPANTS)
            ) 
            ERR-INVALID-EVENT-PARAMS
        )

        ;; Validate reward points
        (asserts! 
            (and 
                (> reward-points u0)
                (<= reward-points MAX-REWARD-POINTS)
            ) 
            ERR-INVALID-EVENT-PARAMS
        )

        ;; Proceed with event creation
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
                    reward-points: reward-points,
                    platform-tags: platform-tags
                }
            )
            (var-set event-counter event-id)
            (ok event-id)
        )
    )
)

(define-public (register-for-event (event-id uint))
    (let
        ((event (unwrap! (map-get? events { event-id: event-id }) (err u404)))
         (current-count (get current-participants event))
         (max-count (get max-participants event)))
        
        ;; Check if event is full
        (asserts! (< current-count max-count) ERR-EVENT-FULL)
        
        ;; Check if participant is already registered
        (asserts! (is-not-registered tx-sender event-id) ERR-ALREADY-REGISTERED)
        
        ;; Mint badge and calculate cross-platform points
        (let
            ((badge-id (+ (var-get badge-counter) u1))
             (points-result (calculate-cross-platform-points 
                 tx-sender 
                 (get reward-points event) 
                 (get platform-tags event)
             )))
            
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
                redeemed-points: (+ (get redeemed-points participant-info) points),
                cross-platform-multipliers: (get cross-platform-multipliers participant-info)
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

(define-private (calculate-cross-platform-points 
    (participant principal) 
    (base-points uint)
    (event-platforms (list 10 (string-ascii 20)))
)
    (let
        ((current-rewards (default-to 
            { 
                total-points: u0, 
                redeemed-points: u0, 
                cross-platform-multipliers: (list ) 
            } 
            (map-get? participant-rewards { participant: participant })))
         (platform-bonus (calculate-platform-bonus event-platforms)))
        
        (map-set participant-rewards
            { participant: participant }
            {
                total-points: (+ 
                    (get total-points current-rewards) 
                    (* base-points (+ u1 platform-bonus))
                ),
                redeemed-points: (get redeemed-points current-rewards),
                cross-platform-multipliers: (append-multiplier 
                    (get cross-platform-multipliers current-rewards) 
                    platform-bonus
                )
            }
        )
        (ok base-points)
    )
)

(define-private (calculate-platform-bonus (platforms (list 10 (string-ascii 20))))
    (fold 
        + 
        (map get-platform-multiplier platforms)
        u0
    )
)

(define-private (get-platform-multiplier (platform-tag (string-ascii 20)))
    (default-to u0 
        (get alliance-multiplier 
            (map-get? platform-alliances { platform-tag: platform-tag })
        )
    )
)

(define-private (append-multiplier 
    (multipliers (list 10 uint)) 
    (multiplier uint)
)
    (unwrap! 
        (as-max-len? 
            (if (is-none (index-of multipliers multiplier))
                (append multipliers multiplier)
                multipliers
            ) 
            u10
        ) 
        multipliers
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

(define-read-only (get-platform-alliance (platform-tag (string-ascii 20)))
    (map-get? platform-alliances { platform-tag: platform-tag })
)
