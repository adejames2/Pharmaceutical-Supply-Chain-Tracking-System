;; Batch Tracking Contract
;; Monitors medications from production to pharmacy

(define-data-var admin principal tx-sender)

;; Data structures
(define-map batches
  { batch-id: (string-ascii 36) }
  {
    manufacturer-id: (string-ascii 36),
    medication-name: (string-ascii 100),
    dosage: (string-ascii 50),
    form: (string-ascii 50),
    quantity: uint,
    production-date: uint,
    expiry-date: uint,
    current-custodian: principal,
    status: (string-ascii 10)
  }
)

(define-map custody-events
  {
    batch-id: (string-ascii 36),
    event-id: uint
  }
  {
    from: principal,
    to: principal,
    timestamp: uint,
    location: (string-ascii 100),
    event-type: (string-ascii 20),
    notes: (string-ascii 200)
  }
)

(define-map batch-event-counters
  { batch-id: (string-ascii 36) }
  { counter: uint }
)

;; Status constants
(define-constant STATUS_PRODUCED "produced")
(define-constant STATUS_TRANSIT "transit")
(define-constant STATUS_DELIVERED "delivered")
(define-constant STATUS_DISPENSED "dispensed")
(define-constant STATUS_RECALLED "recalled")

;; Event type constants
(define-constant EVENT_PRODUCTION "production")
(define-constant EVENT_TRANSFER "transfer")
(define-constant EVENT_DELIVERY "delivery")
(define-constant EVENT_DISPENSING "dispensing")
(define-constant EVENT_RECALL "recall")

;; Public functions
(define-public (register-batch
  (batch-id (string-ascii 36))
  (manufacturer-id (string-ascii 36))
  (medication-name (string-ascii 100))
  (dosage (string-ascii 50))
  (form (string-ascii 50))
  (quantity uint)
  (production-date uint)
  (expiry-date uint)
)
  (let
    ((caller tx-sender)
     (current-time (get-block-info? time (- block-height u1))))
    (asserts! (is-some current-time) (err u1000))
    (asserts! (is-none (map-get? batches {batch-id: batch-id})) (err u1001))
    (asserts! (> expiry-date production-date) (err u1004))

    ;; In a real implementation, we would verify that the caller is an approved manufacturer
    ;; by calling the manufacturer-registration contract

    ;; Initialize batch
    (map-set batches
      {batch-id: batch-id}
      {
        manufacturer-id: manufacturer-id,
        medication-name: medication-name,
        dosage: dosage,
        form: form,
        quantity: quantity,
        production-date: production-date,
        expiry-date: expiry-date,
        current-custodian: caller,
        status: STATUS_PRODUCED
      }
    )

    ;; Initialize event counter
    (map-set batch-event-counters {batch-id: batch-id} {counter: u0})

    ;; Record production event
    (record-custody-event batch-id caller caller (unwrap-panic current-time) "Production Facility" EVENT_PRODUCTION "Batch produced")
  )
)

(define-public (transfer-batch
  (batch-id (string-ascii 36))
  (to principal)
  (location (string-ascii 100))
  (notes (string-ascii 200))
)
  (let
    ((batch-data (unwrap! (map-get? batches {batch-id: batch-id}) (err u1002)))
     (current-time (get-block-info? time (- block-height u1))))
    (asserts! (is-some current-time) (err u1000))
    (asserts! (is-eq tx-sender (get current-custodian batch-data)) (err u1003))
    (asserts! (not (is-eq (get status batch-data) STATUS_RECALLED)) (err u1005))

    ;; Update batch custodian and status
    (map-set batches
      {batch-id: batch-id}
      (merge batch-data {
        current-custodian: to,
        status: STATUS_TRANSIT
      })
    )

    ;; Record transfer event
    (record-custody-event batch-id tx-sender to (unwrap-panic current-time) location EVENT_TRANSFER notes)
  )
)

(define-public (deliver-batch
  (batch-id (string-ascii 36))
  (location (string-ascii 100))
  (notes (string-ascii 200))
)
  (let
    ((batch-data (unwrap! (map-get? batches {batch-id: batch-id}) (err u1002)))
     (current-time (get-block-info? time (- block-height u1))))
    (asserts! (is-some current-time) (err u1000))
    (asserts! (is-eq tx-sender (get current-custodian batch-data)) (err u1003))
    (asserts! (not (is-eq (get status batch-data) STATUS_RECALLED)) (err u1005))

    ;; Update batch status
    (map-set batches
      {batch-id: batch-id}
      (merge batch-data {
        status: STATUS_DELIVERED
      })
    )

    ;; Record delivery event
    (record-custody-event batch-id tx-sender tx-sender (unwrap-panic current-time) location EVENT_DELIVERY notes)
  )
)

(define-public (dispense-batch
  (batch-id (string-ascii 36))
  (quantity-dispensed uint)
  (location (string-ascii 100))
  (notes (string-ascii 200))
)
  (let
    ((batch-data (unwrap! (map-get? batches {batch-id: batch-id}) (err u1002)))
     (current-time (get-block-info? time (- block-height u1)))
     (remaining-quantity (- (get quantity batch-data) quantity-dispensed)))
    (asserts! (is-some current-time) (err u1000))
    (asserts! (is-eq tx-sender (get current-custodian batch-data)) (err u1003))
    (asserts! (not (is-eq (get status batch-data) STATUS_RECALLED)) (err u1005))
    (asserts! (<= quantity-dispensed (get quantity batch-data)) (err u1006))

    ;; Update batch quantity and status if fully dispensed
    (map-set batches
      {batch-id: batch-id}
      (merge batch-data {
        quantity: remaining-quantity,
        status: (if (is-eq remaining-quantity u0) STATUS_DISPENSED (get status batch-data))
      })
    )

    ;; Record dispensing event
    (record-custody-event batch-id tx-sender tx-sender (unwrap-panic current-time) location EVENT_DISPENSING notes)
  )
)

(define-public (recall-batch
  (batch-id (string-ascii 36))
  (notes (string-ascii 200))
)
  (let
    ((batch-data (unwrap! (map-get? batches {batch-id: batch-id}) (err u1002)))
     (current-time (get-block-info? time (- block-height u1))))
    (asserts! (is-some current-time) (err u1000))

    ;; In a real implementation, we would verify that the caller is the manufacturer
    ;; or has permission to recall the batch

    ;; Update batch status
    (map-set batches
      {batch-id: batch-id}
      (merge batch-data {
        status: STATUS_RECALLED
      })
    )

    ;; Record recall event
    (record-custody-event batch-id tx-sender (get current-custodian batch-data) (unwrap-panic current-time) "N/A" EVENT_RECALL notes)
  )
)

;; Helper function to record custody events
(define-private (record-custody-event
  (batch-id (string-ascii 36))
  (from principal)
  (to principal)
  (timestamp uint)
  (location (string-ascii 100))
  (event-type (string-ascii 20))
  (notes (string-ascii 200))
)
  (let
    ((counter-data (unwrap! (map-get? batch-event-counters {batch-id: batch-id}) (err u1007)))
     (event-id (get counter counter-data)))

    ;; Record event
    (map-set custody-events
      {
        batch-id: batch-id,
        event-id: event-id
      }
      {
        from: from,
        to: to,
        timestamp: timestamp,
        location: location,
        event-type: event-type,
        notes: notes
      }
    )

    ;; Increment counter
    (map-set batch-event-counters
      {batch-id: batch-id}
      {counter: (+ event-id u1)}
    )

    (ok event-id)
  )
)

;; Read-only functions
(define-read-only (get-batch (batch-id (string-ascii 36)))
  (map-get? batches {batch-id: batch-id})
)

(define-read-only (get-custody-event (batch-id (string-ascii 36)) (event-id uint))
  (map-get? custody-events {batch-id: batch-id, event-id: event-id})
)

(define-read-only (get-event-count (batch-id (string-ascii 36)))
  (match (map-get? batch-event-counters {batch-id: batch-id})
    counter-data (get counter counter-data)
    u0
  )
)

(define-read-only (is-batch-recalled (batch-id (string-ascii 36)))
  (match (map-get? batches {batch-id: batch-id})
    batch-data (is-eq (get status batch-data) STATUS_RECALLED)
    false
  )
)

(define-read-only (is-batch-expired (batch-id (string-ascii 36)))
  (let
    ((batch-data (unwrap! (map-get? batches {batch-id: batch-id}) false))
     (current-time (get-block-info? time (- block-height u1))))
    (and
      (is-some current-time)
      (>= (unwrap-panic current-time) (get expiry-date batch-data))
    )
  )
)
