;; Verification Contract
;; Allows consumers to confirm medication authenticity

(define-data-var admin principal tx-sender)

;; Data structures
(define-map verification-requests
  uint
  {
    batch-id: (string-ascii 36),
    requester: principal,
    timestamp: uint,
    result: (string-ascii 20),
    details: (string-ascii 200)
  }
)

(define-data-var request-counter uint u0)

;; Result constants
(define-constant RESULT_AUTHENTIC "authentic")
(define-constant RESULT_COUNTERFEIT "counterfeit")
(define-constant RESULT_RECALLED "recalled")
(define-constant RESULT_EXPIRED "expired")
(define-constant RESULT_UNKNOWN "unknown")

;; Public functions
(define-public (verify-medication
  (batch-id (string-ascii 36))
)
  (let
    ((caller tx-sender)
     (current-time (get-block-info? time (- block-height u1)))
     (request-id (var-get request-counter)))
    (asserts! (is-some current-time) (err u1000))

    ;; In a real implementation, we would call the batch-tracking contract
    ;; to verify the batch exists and check its status

    ;; For this example, we'll simulate the verification process
    (let
      ((result RESULT_AUTHENTIC)
       (details "Medication verified successfully"))

      ;; Record verification request
      (map-set verification-requests
        request-id
        {
          batch-id: batch-id,
          requester: caller,
          timestamp: (unwrap-panic current-time),
          result: result,
          details: details
        }
      )

      ;; Increment counter
      (var-set request-counter (+ request-id u1))

      (ok {request-id: request-id, result: result, details: details})
    )
  )
)

;; This function would be called by a backend system that has verified the medication
(define-public (record-verification-result
  (request-id uint)
  (result (string-ascii 20))
  (details (string-ascii 200))
)
  (let
    ((caller tx-sender)
     (request-data (unwrap! (map-get? verification-requests request-id) (err u1002))))
    (asserts! (is-eq caller (var-get admin)) (err u1003))

    (ok (map-set verification-requests
      request-id
      (merge request-data {
        result: result,
        details: details
      })
    ))
  )
)

;; Read-only functions
(define-read-only (get-verification-request (request-id uint))
  (map-get? verification-requests request-id)
)

(define-read-only (get-request-count)
  (var-get request-counter)
)

;; Admin functions
(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u1003))
    (ok (var-set admin new-admin))
  )
)
