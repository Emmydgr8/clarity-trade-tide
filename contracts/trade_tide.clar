;; TradeTide Contract
;; Main contract for simulated trading platform

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-insufficient-funds (err u101))
(define-constant err-invalid-amount (err u102))
(define-constant err-account-exists (err u103))
(define-constant err-no-account (err u104))
(define-constant err-invalid-trade (err u105))
(define-constant err-excessive-position (err u106))
(define-constant err-insufficient-position (err u107))
(define-constant err-price-precision (err u108))

;; Configuration
(define-data-var platform-fee uint u10) ;; 0.1% in basis points
(define-data-var max-position-size uint u100000000) ;; Maximum position size
(define-data-var price-precision uint u100000000) ;; 8 decimal places

;; Enhanced Data Maps
(define-map positions
  { user: principal, symbol: (string-ascii 10) }
  {
    quantity: uint,
    avg-price: uint,
    timestamp: uint,
    total-cost: uint
  }
)

;; Enhanced Public Functions

;; Execute mock trade with improved validation and position tracking
(define-public (execute-trade (symbol (string-ascii 10)) (quantity uint) (price uint) (trade-type (string-ascii 4)))
    (let
        (
            (caller tx-sender)
            (trade-value (* quantity price))
            (fees (/ (* trade-value (var-get platform-fee)) u10000))
            (account-info (unwrap! (map-get? trading-accounts caller) err-no-account))
            (portfolio-info (unwrap! (map-get? portfolios caller) err-no-account))
            (current-block-height block-height)
        )
        ;; Enhanced validation
        (asserts! (> quantity u0) err-invalid-amount)
        (asserts! (> price u0) err-invalid-amount)
        (asserts! (<= price (var-get price-precision)) err-price-precision)
        (asserts! (or (is-eq trade-type "BUY") (is-eq trade-type "SELL")) err-invalid-trade)
        (asserts! (<= trade-value (var-get max-position-size)) err-excessive-position)
        
        (if (is-eq trade-type "BUY")
            (if (>= (get balance account-info) (+ trade-value fees))
                (begin
                    (map-set trading-accounts caller
                        (merge account-info {balance: (- (get balance account-info) (+ trade-value fees))}))
                    (update-position-with-timestamp caller symbol quantity price trade-type current-block-height)
                    (record-trade caller symbol quantity price trade-type fees)
                    (update-portfolio-metrics caller)
                    (ok true)
                )
                err-insufficient-funds
            )
            (let ((current-position (unwrap! (get-position caller symbol) err-no-account)))
                (asserts! (>= (get quantity current-position) quantity) err-insufficient-position)
                (begin 
                    (update-position-with-timestamp caller symbol quantity price trade-type current-block-height)
                    (record-trade caller symbol quantity price trade-type fees)
                    (update-portfolio-metrics caller)
                    (ok true)
                )
            )
        )
    )
)

;; Enhanced Private Functions

;; Update position with timestamp tracking
(define-private (update-position-with-timestamp (user principal) (symbol (string-ascii 10)) (quantity uint) (price uint) (trade-type (string-ascii 4)) (timestamp uint))
    (let (
        (position-key { user: user, symbol: symbol })
        (current-position (default-to 
            { quantity: u0, avg-price: u0, timestamp: timestamp, total-cost: u0 }
            (map-get? positions position-key)))
    )
        (if (is-eq trade-type "BUY")
            (let (
                (new-quantity (+ (get quantity current-position) quantity))
                (new-total-cost (+ (get total-cost current-position) (* quantity price)))
            )
                (map-set positions position-key
                    {
                        quantity: new-quantity,
                        avg-price: (/ new-total-cost new-quantity),
                        timestamp: timestamp,
                        total-cost: new-total-cost
                    })
            )
            (let (
                (new-quantity (- (get quantity current-position) quantity))
                (new-total-cost (if (is-eq new-quantity u0)
                    u0
                    (- (get total-cost current-position) (* quantity (get avg-price current-position)))))
            )
                (map-set positions position-key
                    {
                        quantity: new-quantity,
                        avg-price: (if (is-eq new-quantity u0) u0 (/ new-total-cost new-quantity)),
                        timestamp: timestamp,
                        total-cost: new-total-cost
                    })
            )
        )
    )
)

;; Optimized win rate calculation
(define-private (calculate-win-rate (user principal))
    (let (
        (portfolio (unwrap! (map-get? portfolios user) err-no-account))
        (profitable-trades (count-profitable-trades user))
        (total-trades (get trade-count portfolio))
    )
        (if (> total-trades u0)
            (/ (* profitable-trades u100) total-trades)
            u0))
)
