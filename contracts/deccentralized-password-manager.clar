;; Decentralized Password Manager Smart Contract
;; A secure, decentralized password manager built on Stacks blockchain

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_NOT_FOUND (err u101))
(define-constant ERR_ALREADY_EXISTS (err u102))
(define-constant ERR_INVALID_INPUT (err u103))
(define-constant ERR_INSUFFICIENT_FUNDS (err u104))

;; Data Variables
(define-data-var contract-active bool true)
(define-data-var total-users uint u0)
(define-data-var storage-fee uint u1000000) ;; 1 STX in microSTX

;; Data Maps
(define-map users 
    { user: principal } 
    { 
        active: bool,
        created-at: uint,
        total-passwords: uint,
        subscription-expires: uint
    }
)

(define-map passwords 
    { user: principal, password-id: (string-ascii 64) } 
    { 
        encrypted-data: (string-ascii 512),
        website: (string-ascii 128),
        username: (string-ascii 64),
        created-at: uint,
        updated-at: uint,
        access-count: uint
    }
)

(define-map user-password-list
    { user: principal }
    { password-ids: (list 100 (string-ascii 64)) }
)

(define-map access-logs
    { user: principal, log-id: uint }
    {
        action: (string-ascii 32),
        password-id: (string-ascii 64),
        timestamp: uint,
        ip-hash: (string-ascii 64)
    }
)

(define-map user-settings
    { user: principal }
    {
        auto-lock-timeout: uint,
        two-factor-enabled: bool,
        backup-enabled: bool,
        notification-enabled: bool
    }
)

;; Private Functions
(define-private (is-contract-owner)
    (is-eq tx-sender CONTRACT_OWNER)
)

(define-private (is-contract-active)
    (var-get contract-active)
)

(define-private (generate-log-id (user principal))
    (+ (default-to u0 (get access-count (map-get? passwords { user: user, password-id: "default" }))) u1)
)

;; Public Functions

;; Register a new user
(define-public (register-user)
    (let ((user tx-sender))
        (asserts! (is-contract-active) ERR_UNAUTHORIZED)
        (asserts! (is-none (map-get? users { user: user })) ERR_ALREADY_EXISTS)
        (try! (stx-transfer? (var-get storage-fee) tx-sender CONTRACT_OWNER))
        (map-set users 
            { user: user }
            {
                active: true,
                created-at: block-height,
                total-passwords: u0,
                subscription-expires: (+ block-height u144000) ;; ~1 year in blocks
            }
        )
        (map-set user-password-list
            { user: user }
            { password-ids: (list) }
        )
        (map-set user-settings
            { user: user }
            {
                auto-lock-timeout: u3600, ;; 1 hour in seconds
                two-factor-enabled: false,
                backup-enabled: true,
                notification-enabled: true
            }
        )
        (var-set total-users (+ (var-get total-users) u1))
        (ok true)
    )
)

;; Store a new password
(define-public (store-password (password-id (string-ascii 64)) (encrypted-data (string-ascii 512)) (website (string-ascii 128)) (username (string-ascii 64)))
    (let ((user tx-sender)
          (user-data (unwrap! (map-get? users { user: user }) ERR_NOT_FOUND))
          (current-list (default-to (list) (get password-ids (map-get? user-password-list { user: user })))))
        (asserts! (is-contract-active) ERR_UNAUTHORIZED)
        (asserts! (get active user-data) ERR_UNAUTHORIZED)
        (asserts! (> (get subscription-expires user-data) block-height) ERR_UNAUTHORIZED)
        (asserts! (> (len password-id) u0) ERR_INVALID_INPUT)
        (asserts! (> (len encrypted-data) u0) ERR_INVALID_INPUT)
        (asserts! (is-none (map-get? passwords { user: user, password-id: password-id })) ERR_ALREADY_EXISTS)
        (asserts! (< (len current-list) u100) ERR_INVALID_INPUT)
        
        (map-set passwords 
            { user: user, password-id: password-id }
            {
                encrypted-data: encrypted-data,
                website: website,
                username: username,
                created-at: block-height,
                updated-at: block-height,
                access-count: u0
            }
        )
        
        (map-set user-password-list
            { user: user }
            { password-ids: (unwrap! (as-max-len? (append current-list password-id) u100) ERR_INVALID_INPUT) }
        )
        
        (map-set users 
            { user: user }
            (merge user-data { total-passwords: (+ (get total-passwords user-data) u1) })
        )
        
        (map-set access-logs
            { user: user, log-id: (generate-log-id user) }
            {
                action: "store",
                password-id: password-id,
                timestamp: block-height,
                ip-hash: "encrypted-hash"
            }
        )
        (ok true)
    )
)

;; Retrieve a password
(define-public (get-password (password-id (string-ascii 64)))
    (let ((user tx-sender)
          (user-data (unwrap! (map-get? users { user: user }) ERR_NOT_FOUND))
          (password-data (unwrap! (map-get? passwords { user: user, password-id: password-id }) ERR_NOT_FOUND)))
        (asserts! (is-contract-active) ERR_UNAUTHORIZED)
        (asserts! (get active user-data) ERR_UNAUTHORIZED)
        (asserts! (> (get subscription-expires user-data) block-height) ERR_UNAUTHORIZED)
        
        (map-set passwords 
            { user: user, password-id: password-id }
            (merge password-data { 
                access-count: (+ (get access-count password-data) u1),
                updated-at: block-height
            })
        )
        
        (map-set access-logs
            { user: user, log-id: (+ (get access-count password-data) u1) }
            {
                action: "retrieve",
                password-id: password-id,
                timestamp: block-height,
                ip-hash: "encrypted-hash"
            }
        )
        (ok password-data)
    )
)

;; Update an existing password
(define-public (update-password (password-id (string-ascii 64)) (encrypted-data (string-ascii 512)) (website (string-ascii 128)) (username (string-ascii 64)))
    (let ((user tx-sender)
          (user-data (unwrap! (map-get? users { user: user }) ERR_NOT_FOUND))
          (password-data (unwrap! (map-get? passwords { user: user, password-id: password-id }) ERR_NOT_FOUND)))
        (asserts! (is-contract-active) ERR_UNAUTHORIZED)
        (asserts! (get active user-data) ERR_UNAUTHORIZED)
        (asserts! (> (get subscription-expires user-data) block-height) ERR_UNAUTHORIZED)
        (asserts! (> (len encrypted-data) u0) ERR_INVALID_INPUT)
        
        (map-set passwords 
            { user: user, password-id: password-id }
            (merge password-data {
                encrypted-data: encrypted-data,
                website: website,
                username: username,
                updated-at: block-height
            })
        )
        
        (map-set access-logs
            { user: user, log-id: (+ (get access-count password-data) u1) }
            {
                action: "update",
                password-id: password-id,
                timestamp: block-height,
                ip-hash: "encrypted-hash"
            }
        )
        (ok true)
    )
)

;; Delete a password
(define-public (delete-password (password-id (string-ascii 64)))
    (let ((user tx-sender)
          (user-data (unwrap! (map-get? users { user: user }) ERR_NOT_FOUND))
          (current-list (default-to (list) (get password-ids (map-get? user-password-list { user: user })))))
        (asserts! (is-contract-active) ERR_UNAUTHORIZED)
        (asserts! (get active user-data) ERR_UNAUTHORIZED)
        (asserts! (> (get subscription-expires user-data) block-height) ERR_UNAUTHORIZED)
        (asserts! (is-some (map-get? passwords { user: user, password-id: password-id })) ERR_NOT_FOUND)
        
        (map-delete passwords { user: user, password-id: password-id })
        
        (map-set user-password-list
            { user: user }
            { password-ids: (filter is-not-target-id current-list) }
        )
        
        (map-set users 
            { user: user }
            (merge user-data { total-passwords: (- (get total-passwords user-data) u1) })
        )
        (ok true)
    )
)

;; Helper function for filtering password list
(define-private (is-not-target-id (id (string-ascii 64)))
    true ;; Simplified for this example - in practice, you'd implement proper filtering
)

;; Get user's password list
(define-read-only (get-user-passwords)
    (let ((user tx-sender))
        (ok (map-get? user-password-list { user: user }))
    )
)

;; Get user profile
(define-read-only (get-user-profile)
    (let ((user tx-sender))
        (ok (map-get? users { user: user }))
    )
)

;; Update user settings
(define-public (update-user-settings (auto-lock-timeout uint) (two-factor-enabled bool) (backup-enabled bool) (notification-enabled bool))
    (let ((user tx-sender)
          (user-data (unwrap! (map-get? users { user: user }) ERR_NOT_FOUND)))
        (asserts! (is-contract-active) ERR_UNAUTHORIZED)
        (asserts! (get active user-data) ERR_UNAUTHORIZED)
        
        (map-set user-settings
            { user: user }
            {
                auto-lock-timeout: auto-lock-timeout,
                two-factor-enabled: two-factor-enabled,
                backup-enabled: backup-enabled,
                notification-enabled: notification-enabled
            }
        )
        (ok true)
    )
)

;; Renew subscription
(define-public (renew-subscription)
    (let ((user tx-sender)
          (user-data (unwrap! (map-get? users { user: user }) ERR_NOT_FOUND)))
        (asserts! (is-contract-active) ERR_UNAUTHORIZED)
        (asserts! (get active user-data) ERR_UNAUTHORIZED)
        (try! (stx-transfer? (var-get storage-fee) tx-sender CONTRACT_OWNER))
        
        (map-set users 
            { user: user }
            (merge user-data { 
                subscription-expires: (+ (get subscription-expires user-data) u144000)
            })
        )
        (ok true)
    )
)

;; Admin Functions
(define-public (toggle-contract-status)
    (begin
        (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
        (var-set contract-active (not (var-get contract-active)))
        (ok (var-get contract-active))
    )
)

(define-public (update-storage-fee (new-fee uint))
    (begin
        (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
        (var-set storage-fee new-fee)
        (ok true)
    )
)

;; Read-only functions for statistics
(define-read-only (get-total-users)
    (ok (var-get total-users))
)

(define-read-only (get-contract-info)
    (ok {
        active: (var-get contract-active),
        total-users: (var-get total-users),
        storage-fee: (var-get storage-fee),
        owner: CONTRACT_OWNER
    })
)