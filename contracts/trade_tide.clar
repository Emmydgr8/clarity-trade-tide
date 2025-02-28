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

;; Configuration
(define-data-var platform-fee uint u10) ;; 0.1% in basis points
(define-data-var max-position-size uint u100000000) ;; Maximum position size

;; Data Maps
[Previous maps remain unchanged...]

;; Enhanced Public Functions

;; Execute mock trade with validation
(define-public (execute-trade (symbol (string-ascii 10)) (quantity uint) (price uint) (trade-type (string-ascii 4)))
    (let
        (
            (caller tx-sender)
            (trade-value (* quantity price))
            (fees (/ (* trade-value (var-get platform-fee)) u10000))
            (account-info (unwrap! (map-get? trading-accounts caller) err-no-account))
            (portfolio-info (unwrap! (map-get? portfolios caller) err-no-account))
            (position (get-position caller symbol))
        )
        ;; Validate trade parameters
        (asserts! (> quantity u0) err-invalid-amount)
        (asserts! (> price u0) err-invalid-amount)
        (asserts! (or (is-eq trade-type "BUY") (is-eq trade-type "SELL")) err-invalid-trade)
        
        ;; Validate position limits
        (asserts! (<= trade-value (var-get max-position-size)) err-excessive-position)
        
        (if (is-eq trade-type "BUY")
            (if (>= (get balance account-info) (+ trade-value fees))
                (begin
                    (map-set trading-accounts caller
                        (merge account-info {balance: (- (get balance account-info) (+ trade-value fees))}))
                    (update-position caller symbol quantity price trade-type)
                    (record-trade caller symbol quantity price trade-type fees)
                    (update-portfolio-metrics caller)
                    (ok true)
                )
                err-insufficient-funds
            )
            (let ((current-position (unwrap! (get-position caller symbol) err-no-account)))
                (asserts! (>= (get quantity current-position) quantity) err-insufficient-position)
                (begin 
                    (update-position caller symbol quantity price trade-type)
                    (record-trade caller symbol quantity price trade-type fees)
                    (update-portfolio-metrics caller)
                    (ok true)
                )
            )
        )
    )
)

;; Enhanced Private Functions

;; Calculate win rate with proper implementation
(define-private (calculate-win-rate (user principal))
    (let (
        (portfolio (unwrap! (map-get? portfolios user) err-no-account))
        (profitable-trades (count-profitable-trades user))
    )
        (if (> (get trade-count portfolio) u0)
            (/ (* profitable-trades u100) (get trade-count portfolio))
            u0))
)

;; New helper function to count profitable trades
(define-private (count-profitable-trades (user principal))
    (let ((portfolio (unwrap! (map-get? portfolios user) err-no-account)))
        (default-to u0 (fold check-trade-profit u0 (range u0 (get trade-count portfolio))))
    )
)

;; Helper for profitable trade counting
(define-private (check-trade-profit (trade-id uint) (acc uint))
    (let ((trade (unwrap! (map-get? trades {user: tx-sender, trade-id: trade-id}) acc)))
        (if (> (get profit-loss trade) 0)
            (+ acc u1)
            acc)
    )
)

[Previous read-only functions remain unchanged...]
