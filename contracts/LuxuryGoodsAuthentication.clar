;; LuxuryGoods Authentication Contract
;; High-end product authentication system for watches, bags, and luxury items

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-authorized (err u101))
(define-constant err-already-authenticated (err u102))
(define-constant err-item-not-found (err u103))
(define-constant err-invalid-data (err u104))

;; Data variables
(define-data-var next-item-id uint u1)
(define-data-var total-authenticated-items uint u0)

;; Maps
(define-map luxury-items
  uint
  {
    brand: (string-ascii 50),
    model: (string-ascii 100),
    category: (string-ascii 20),
    serial-number: (string-ascii 100),
    authenticated-by: principal,
    authentication-date: uint,
    owner: principal,
    is-authentic: bool
  }
)

(define-map authorized-authenticators principal bool)
(define-map item-ownership principal (list 100 uint))

;; Initialize contract owner as first authorized authenticator
(map-set authorized-authenticators contract-owner true)

;; Function 1: Authenticate a luxury item
;; Register and verify a luxury item with authentication details
(define-public (authenticate-item 
  (brand (string-ascii 50))
  (model (string-ascii 100))
  (category (string-ascii 20))
  (serial-number (string-ascii 100))
  (owner principal))
  (let 
    (
      (item-id (var-get next-item-id))
      (current-items (default-to (list) (map-get? item-ownership owner)))
    )
    ;; Check if caller is authorized authenticator
    (asserts! (default-to false (map-get? authorized-authenticators tx-sender)) err-not-authorized)
    ;; Validate input data
    (asserts! (and (> (len brand) u0) (> (len model) u0) (> (len serial-number) u0)) err-invalid-data)
    
    ;; Create the luxury item record
    (map-set luxury-items item-id
      {
        brand: brand,
        model: model,
        category: category,
        serial-number: serial-number,
        authenticated-by: tx-sender,
        authentication-date: stacks-block-height,
        owner: owner,
        is-authentic: true
      }
    )
    
    ;; Update owner's item list
    (map-set item-ownership owner (unwrap-panic (as-max-len? (append current-items item-id) u100)))
    
    ;; Update counters
    (var-set next-item-id (+ item-id u1))
    (var-set total-authenticated-items (+ (var-get total-authenticated-items) u1))
    
    (ok item-id)
  )
)

;; Function 2: Verify luxury item authenticity
;; Check and retrieve authentication details of a luxury item
(define-read-only (verify-item (item-id uint))
  (match (map-get? luxury-items item-id)
    item-data 
      (ok {
        item-id: item-id,
        brand: (get brand item-data),
        model: (get model item-data),
        category: (get category item-data),
        serial-number: (get serial-number item-data),
        authenticated-by: (get authenticated-by item-data),
        authentication-date: (get authentication-date item-data),
        owner: (get owner item-data),
        is-authentic: (get is-authentic item-data),
        verification-status: "VERIFIED_AUTHENTIC"
      })
    (err err-item-not-found)
  )
)

;; Helper functions for contract management
(define-public (add-authenticator (authenticator principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (map-set authorized-authenticators authenticator true)
    (ok true)
  )
)

(define-read-only (is-authorized (authenticator principal))
  (default-to false (map-get? authorized-authenticators authenticator))
)

(define-read-only (get-owner-items (owner principal))
  (ok (default-to (list) (map-get? item-ownership owner)))
)

(define-read-only (get-total-authenticated)
  (ok (var-get total-authenticated-items))
)