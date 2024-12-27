;; TradeTide Contract
;; Main contract for simulated trading platform

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-insufficient-funds (err u101))
(define-constant err-invalid-amount (err u102))
(define-constant err-account-exists (err u103))
(define-constant err-no-account (err u104))

;; Data Variables
(define-data-var platform-fee uint u10) ;; 0.1% in basis points

;; Data Maps
(define-map trading-accounts
    principal
    {
        balance: uint,
        active: bool,
        created-at: uint
    }
)

(define-map portfolios
    principal
    {
        total-value: uint,
        profit-loss: int,
        trade-count: uint
    }
)

(define-map trades
    {user: principal, trade-id: uint}
    {
        symbol: (string-ascii 10),
        quantity: uint,
        price: uint,
        timestamp: uint,
        trade-type: (string-ascii 4)  ;; "BUY" or "SELL"
    }
)

;; Public Functions

;; Create new trading account
(define-public (create-account)
    (let
        ((caller tx-sender))
        (if (default-to false (get active (map-get? trading-accounts caller)))
            err-account-exists
            (begin
                (map-set trading-accounts 
                    caller
                    {
                        balance: u1000000, ;; Start with 1M simulation dollars
                        active: true,
                        created-at: block-height
                    }
                )
                (map-set portfolios
                    caller
                    {
                        total-value: u1000000,
                        profit-loss: 0,
                        trade-count: u0
                    }
                )
                (ok true)
            )
        )
    )
)

;; Execute mock trade
(define-public (execute-trade (symbol (string-ascii 10)) (quantity uint) (price uint) (trade-type (string-ascii 4)))
    (let
        (
            (caller tx-sender)
            (trade-value (* quantity price))
            (account-info (unwrap! (map-get? trading-accounts caller) err-no-account))
            (portfolio-info (unwrap! (map-get? portfolios caller) err-no-account))
        )
        (if (is-eq trade-type "BUY")
            (if (>= (get balance account-info) trade-value)
                (begin
                    (map-set trading-accounts caller
                        (merge account-info {balance: (- (get balance account-info) trade-value)}))
                    (record-trade caller symbol quantity price trade-type)
                    (ok true)
                )
                err-insufficient-funds
            )
            (record-trade caller symbol quantity price trade-type)
        )
    )
)

;; Private Functions

;; Record trade in history
(define-private (record-trade (user principal) (symbol (string-ascii 10)) (quantity uint) (price uint) (trade-type (string-ascii 4)))
    (let
        ((portfolio-info (unwrap! (map-get? portfolios user) err-no-account))
         (trade-id (get trade-count portfolio-info)))
        (map-set trades
            {user: user, trade-id: trade-id}
            {
                symbol: symbol,
                quantity: quantity,
                price: price,
                timestamp: block-height,
                trade-type: trade-type
            }
        )
        (map-set portfolios user
            (merge portfolio-info {trade-count: (+ trade-id u1)}))
        (ok true)
    )
)

;; Read-only functions

(define-read-only (get-account-info (account principal))
    (ok (unwrap! (map-get? trading-accounts account) err-no-account))
)

(define-read-only (get-portfolio (account principal))
    (ok (unwrap! (map-get? portfolios account) err-no-account))
)

(define-read-only (get-trade (user principal) (trade-id uint))
    (ok (unwrap! (map-get? trades {user: user, trade-id: trade-id}) err-no-account))
)