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
        trade-count: uint,
        realized-gains: int,
        unrealized-gains: int,
        win-rate: uint,
        avg-position-size: uint,
        total-fees: uint
    }
)

(define-map trades
    {user: principal, trade-id: uint}
    {
        symbol: (string-ascii 10),
        quantity: uint,
        price: uint,
        timestamp: uint,
        trade-type: (string-ascii 4),  ;; "BUY" or "SELL"
        fees: uint,
        profit-loss: int
    }
)

(define-map positions
    {user: principal, symbol: (string-ascii 10)}
    {
        quantity: uint,
        avg-price: uint,
        unrealized-pl: int,
        last-updated: uint
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
                        trade-count: u0,
                        realized-gains: 0,
                        unrealized-gains: 0,
                        win-rate: u0,
                        avg-position-size: u0,
                        total-fees: u0
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
            (fees (/ (* trade-value (var-get platform-fee)) u10000))
            (account-info (unwrap! (map-get? trading-accounts caller) err-no-account))
            (portfolio-info (unwrap! (map-get? portfolios caller) err-no-account))
            (position (get-position caller symbol))
        )
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
            (begin 
                (update-position caller symbol quantity price trade-type)
                (record-trade caller symbol quantity price trade-type fees)
                (update-portfolio-metrics caller)
                (ok true)
            )
        )
    )
)

;; Private Functions

;; Record trade in history with P&L tracking
(define-private (record-trade (user principal) (symbol (string-ascii 10)) (quantity uint) (price uint) (trade-type (string-ascii 4)) (fees uint))
    (let
        ((portfolio-info (unwrap! (map-get? portfolios user) err-no-account))
         (trade-id (get trade-count portfolio-info))
         (position (get-position user symbol))
         (pl (calculate-trade-pl position quantity price trade-type)))
        (map-set trades
            {user: user, trade-id: trade-id}
            {
                symbol: symbol,
                quantity: quantity,
                price: price,
                timestamp: block-height,
                trade-type: trade-type,
                fees: fees,
                profit-loss: pl
            }
        )
        (map-set portfolios user
            (merge portfolio-info 
                {
                    trade-count: (+ trade-id u1),
                    total-fees: (+ (get total-fees portfolio-info) fees)
                }))
        (ok true)
    )
)

;; Update position tracking
(define-private (update-position (user principal) (symbol (string-ascii 10)) (quantity uint) (price uint) (trade-type (string-ascii 4)))
    (let ((current-position (default-to 
            {quantity: u0, avg-price: u0, unrealized-pl: 0, last-updated: block-height}
            (map-get? positions {user: user, symbol: symbol}))))
        (if (is-eq trade-type "BUY")
            (map-set positions {user: user, symbol: symbol}
                {
                    quantity: (+ (get quantity current-position) quantity),
                    avg-price: (calculate-avg-price current-position quantity price),
                    unrealized-pl: (calculate-unrealized-pl current-position price),
                    last-updated: block-height
                })
            (map-set positions {user: user, symbol: symbol}
                {
                    quantity: (- (get quantity current-position) quantity),
                    avg-price: (get avg-price current-position),
                    unrealized-pl: (calculate-unrealized-pl current-position price),
                    last-updated: block-height
                })
        )
    )
)

;; Calculate trade P&L
(define-private (calculate-trade-pl (position (optional {quantity: uint, avg-price: uint, unrealized-pl: int, last-updated: uint})) (quantity uint) (price uint) (trade-type (string-ascii 4)))
    (if (is-eq trade-type "SELL")
        (let ((pos (unwrap! position 0)))
            (* (to-int (- price (get avg-price pos))) (to-int quantity)))
        0)
)

;; Calculate average price for position
(define-private (calculate-avg-price (position {quantity: uint, avg-price: uint, unrealized-pl: int, last-updated: uint}) (new-quantity uint) (new-price uint))
    (let ((total-quantity (+ (get quantity position) new-quantity))
          (total-value (+ (* (get quantity position) (get avg-price position)) (* new-quantity new-price))))
        (/ total-value total-quantity))
)

;; Calculate unrealized P&L
(define-private (calculate-unrealized-pl (position {quantity: uint, avg-price: uint, unrealized-pl: int, last-updated: uint}) (current-price uint))
    (* (to-int (get quantity position)) (to-int (- current-price (get avg-price position))))
)

;; Update portfolio metrics
(define-private (update-portfolio-metrics (user principal))
    (let ((portfolio (unwrap! (map-get? portfolios user) err-no-account)))
        (map-set portfolios user
            (merge portfolio {
                win-rate: (calculate-win-rate user),
                avg-position-size: (calculate-avg-position-size user)
            }))
    )
)

;; Calculate win rate
(define-private (calculate-win-rate (user principal))
    (let ((portfolio (unwrap! (map-get? portfolios user) err-no-account)))
        (if (> (get trade-count portfolio) u0)
            u50 ;; Placeholder - would calculate actual win rate
            u0))
)

;; Calculate average position size
(define-private (calculate-avg-position-size (user principal))
    (let ((portfolio (unwrap! (map-get? portfolios user) err-no-account)))
        (if (> (get trade-count portfolio) u0)
            (/ (get total-value portfolio) (get trade-count portfolio))
            u0))
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

(define-read-only (get-position (user principal) (symbol (string-ascii 10)))
    (map-get? positions {user: user, symbol: symbol})
)
