;; Manufacturer Registration Contract
;; Validates legitimate drug producers

(define-data-var admin principal tx-sender)

;; Data structures
(define-map manufacturers
  { manufacturer-id: (string-ascii 36) }
  {
    name: (string-ascii 100),
    license-number: (string-ascii 50),
    location: (string-ascii 100),
    contact-info: (string-ascii 100),
    status: (string-ascii 10),
    registration-date: uint,
    last-verified-date: uint
  }
)

;; Status constants
(define-constant STATUS_PENDING "pending")
(define-constant STATUS_APPROVED "approved")
(define-constant STATUS_REVOKED "revoked")

;; Public functions
(define-public (register-manufacturer
  (manufacturer-id (string-ascii 36))
  (name (string-ascii 100))
  (license-number (string-ascii 50))
  (location (string-ascii 100))
  (contact-info (string-ascii 100))
)
  (let
    ((caller tx-sender)
     (current-time (get-block-info? time (- block-height u1))))
    (asserts! (is-some current-time) (err u1000))
    (asserts! (is-none (map-get? manufacturers {manufacturer-id: manufacturer-id})) (err u1001))

    (ok (map-set manufacturers
      {manufacturer-id: manufacturer-id}
      {
        name: name,
        license-number: license-number,
        location: location,
        contact-info: contact-info,
        status: STATUS_PENDING,
        registration-date: (unwrap-panic current-time),
        last-verified-date: (unwrap-panic current-time)
      }
    ))
  )
)

(define-public (update-manufacturer-info
  (manufacturer-id (string-ascii 36))
  (name (string-ascii 100))
  (license-number (string-ascii 50))
  (location (string-ascii 100))
  (contact-info (string-ascii 100))
)
  (let
    ((manufacturer-data (unwrap! (map-get? manufacturers {manufacturer-id: manufacturer-id}) (err u1002)))
     (current-time (get-block-info? time (- block-height u1))))
    (asserts! (is-some current-time) (err u1000))

    ;; In a real implementation, we would verify that the caller is the manufacturer
    ;; or has permission to update the manufacturer info

    (ok (map-set manufacturers
      {manufacturer-id: manufacturer-id}
      (merge manufacturer-data {
        name: name,
        license-number: license-number,
        location: location,
        contact-info: contact-info,
        last-verified-date: (unwrap-panic current-time)
      })
    ))
  )
)

;; Admin functions
(define-public (approve-manufacturer (manufacturer-id (string-ascii 36)))
  (let
    ((manufacturer-data (unwrap! (map-get? manufacturers {manufacturer-id: manufacturer-id}) (err u1002)))
     (current-time (get-block-info? time (- block-height u1))))
    (asserts! (is-some current-time) (err u1000))
    (asserts! (is-eq tx-sender (var-get admin)) (err u1003))

    (ok (map-set manufacturers
      {manufacturer-id: manufacturer-id}
      (merge manufacturer-data {
        status: STATUS_APPROVED,
        last-verified-date: (unwrap-panic current-time)
      })
    ))
  )
)

(define-public (revoke-manufacturer (manufacturer-id (string-ascii 36)))
  (let
    ((manufacturer-data (unwrap! (map-get? manufacturers {manufacturer-id: manufacturer-id}) (err u1002)))
     (current-time (get-block-info? time (- block-height u1))))
    (asserts! (is-some current-time) (err u1000))
    (asserts! (is-eq tx-sender (var-get admin)) (err u1003))

    (ok (map-set manufacturers
      {manufacturer-id: manufacturer-id}
      (merge manufacturer-data {
        status: STATUS_REVOKED,
        last-verified-date: (unwrap-panic current-time)
      })
    ))
  )
)

(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u1003))
    (ok (var-set admin new-admin))
  )
)

;; Read-only functions
(define-read-only (get-manufacturer (manufacturer-id (string-ascii 36)))
  (map-get? manufacturers {manufacturer-id: manufacturer-id})
)

(define-read-only (is-manufacturer-approved (manufacturer-id (string-ascii 36)))
  (match (map-get? manufacturers {manufacturer-id: manufacturer-id})
    manufacturer-data (is-eq (get status manufacturer-data) STATUS_APPROVED)
    false
  )
)
