;; Decentralized Accommodation Platform Smart Contract
;; A comprehensive platform for peer-to-peer accommodation booking

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant PLATFORM_FEE u5) ;; 5% platform fee
(define-constant CANCELLATION_WINDOW u86400) ;; 24 hours in seconds
(define-constant DISPUTE_WINDOW u604800) ;; 7 days in seconds
(define-constant MIN_STAKE u1000000) ;; 1 STX minimum stake for hosts

;; Error codes
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_PROPERTY_NOT_FOUND (err u101))
(define-constant ERR_BOOKING_NOT_FOUND (err u102))
(define-constant ERR_INVALID_DATES (err u103))
(define-constant ERR_PROPERTY_NOT_AVAILABLE (err u104))
(define-constant ERR_INSUFFICIENT_PAYMENT (err u105))
(define-constant ERR_BOOKING_ALREADY_EXISTS (err u106))
(define-constant ERR_CANCELLATION_WINDOW_EXPIRED (err u107))
(define-constant ERR_ALREADY_REVIEWED (err u108))
(define-constant ERR_INVALID_RATING (err u109))
(define-constant ERR_DISPUTE_WINDOW_EXPIRED (err u110))
(define-constant ERR_INSUFFICIENT_STAKE (err u111))
(define-constant ERR_PROPERTY_ALREADY_EXISTS (err u112))
(define-constant ERR_INVALID_INPUT (err u113))
(define-constant ERR_INVALID_AMOUNT (err u114))

;; Data Variables
(define-data-var next-property-id uint u1)
(define-data-var next-booking-id uint u1)
(define-data-var platform-balance uint u0)

;; Data Maps
(define-map properties 
  { property-id: uint }
  {
    host: principal,
    title: (string-ascii 100),
    description: (string-ascii 500),
    location: (string-ascii 100),
    price-per-night: uint,
    max-guests: uint,
    amenities: (list 10 (string-ascii 50)),
    is-active: bool,
    total-bookings: uint,
    total-rating: uint,
    review-count: uint,
    created-at: uint
  }
)

(define-map bookings
  { booking-id: uint }
  {
    property-id: uint,
    guest: principal,
    host: principal,
    check-in: uint,
    check-out: uint,
    total-guests: uint,
    total-amount: uint,
    platform-fee: uint,
    status: (string-ascii 20), ;; "pending", "confirmed", "cancelled", "completed", "disputed"
    created-at: uint,
    confirmed-at: (optional uint),
    cancelled-at: (optional uint)
  }
)

(define-map property-availability
  { property-id: uint, date: uint }
  { is-available: bool }
)

(define-map host-stakes
  { host: principal }
  { amount: uint, staked-at: uint }
)

(define-map reviews
  { booking-id: uint }
  {
    reviewer: principal,
    rating: uint,
    comment: (string-ascii 500),
    created-at: uint
  }
)

(define-map disputes
  { booking-id: uint }
  {
    initiated-by: principal,
    reason: (string-ascii 500),
    status: (string-ascii 20), ;; "pending", "resolved", "escalated"
    created-at: uint,
    resolved-at: (optional uint)
  }
)

(define-map user-profiles
  { user: principal }
  {
    username: (string-ascii 50),
    email: (string-ascii 100),
    total-bookings: uint,
    total-earnings: uint,
    reputation-score: uint,
    is-verified: bool,
    joined-at: uint
  }
)

;; Helper Functions
(define-private (is-contract-owner)
  (is-eq tx-sender CONTRACT_OWNER)
)

(define-private (calculate-platform-fee (amount uint))
  (/ (* amount PLATFORM_FEE) u100)
)

(define-private (is-date-available (property-id uint) (date uint))
  (default-to true 
    (get is-available (map-get? property-availability { property-id: property-id, date: date }))
  )
)

(define-private (get-days-between (start uint) (end uint))
  (if (> end start)
    (/ (- end start) u86400) ;; Convert seconds to days
    u0
  )
)

(define-private (set-single-date-availability (property-id uint) (date uint) (available bool))
  (map-set property-availability 
    { property-id: property-id, date: date }
    { is-available: available }
  )
)

(define-private (check-date-range-available (property-id uint) (start-date uint) (end-date uint))
  (let ((days-to-check (get-days-between start-date end-date)))
    (if (<= days-to-check u7) ;; Limit to 7 days max for booking
      (and 
        (is-date-available property-id start-date)
        (if (> days-to-check u1) (is-date-available property-id (+ start-date u86400)) true)
        (if (> days-to-check u2) (is-date-available property-id (+ start-date (* u2 u86400))) true)
        (if (> days-to-check u3) (is-date-available property-id (+ start-date (* u3 u86400))) true)
        (if (> days-to-check u4) (is-date-available property-id (+ start-date (* u4 u86400))) true)
        (if (> days-to-check u5) (is-date-available property-id (+ start-date (* u5 u86400))) true)
        (if (> days-to-check u6) (is-date-available property-id (+ start-date (* u6 u86400))) true)
      )
      false ;; Don't allow bookings longer than 7 days
    )
  )
)

;; Input validation functions
(define-private (validate-string-input (input (string-ascii 500)))
  (> (len input) u0)
)

(define-private (validate-short-string-input (input (string-ascii 100)))
  (> (len input) u0)
)

(define-private (validate-username (username (string-ascii 50)))
  (and (> (len username) u2) (<= (len username) u50))
)

(define-private (validate-email (email (string-ascii 100)))
  (and (> (len email) u5) (<= (len email) u100))
)

(define-private (validate-uint-positive (value uint))
  (> value u0)
)

(define-private (validate-property-id (property-id uint))
  (and (> property-id u0) (< property-id (var-get next-property-id)))
)

(define-private (validate-booking-id (booking-id uint))
  (and (> booking-id u0) (< booking-id (var-get next-booking-id)))
)

(define-private (validate-amenity-item (amenity (string-ascii 50)))
  (and (> (len amenity) u0) (<= (len amenity) u50))
)

(define-private (validate-amenities (amenities (list 10 (string-ascii 50))))
  (let ((validated-list (filter validate-amenity-item amenities)))
    (is-eq (len validated-list) (len amenities))
  )
)

;; Public Functions

;; Host Functions
(define-public (stake-as-host (amount uint))
  (let ((current-stake (default-to u0 (get amount (map-get? host-stakes { host: tx-sender })))))
    (asserts! (validate-uint-positive amount) ERR_INVALID_INPUT)
    (asserts! (>= amount MIN_STAKE) ERR_INSUFFICIENT_STAKE)
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (map-set host-stakes
      { host: tx-sender }
      { amount: (+ current-stake amount), staked-at: block-height }
    )
    (ok amount)
  )
)

(define-public (create-property 
  (title (string-ascii 100))
  (description (string-ascii 500))
  (location (string-ascii 100))
  (price-per-night uint)
  (max-guests uint)
  (amenities (list 10 (string-ascii 50)))
)
  (let ((property-id (var-get next-property-id))
        (host-stake (get amount (map-get? host-stakes { host: tx-sender }))))
    ;; Input validation
    (asserts! (validate-short-string-input title) ERR_INVALID_INPUT)
    (asserts! (validate-string-input description) ERR_INVALID_INPUT)
    (asserts! (validate-short-string-input location) ERR_INVALID_INPUT)
    (asserts! (validate-uint-positive price-per-night) ERR_INVALID_INPUT)
    (asserts! (validate-uint-positive max-guests) ERR_INVALID_INPUT)
    (asserts! (<= max-guests u20) ERR_INVALID_INPUT) ;; Reasonable max guest limit
    (asserts! (validate-amenities amenities) ERR_INVALID_INPUT)
    
    (asserts! (>= (default-to u0 host-stake) MIN_STAKE) ERR_INSUFFICIENT_STAKE)
    (asserts! (is-none (map-get? properties { property-id: property-id })) ERR_PROPERTY_ALREADY_EXISTS)
    
    (map-set properties
      { property-id: property-id }
      {
        host: tx-sender,
        title: title,
        description: description,
        location: location,
        price-per-night: price-per-night,
        max-guests: max-guests,
        amenities: amenities,
        is-active: true,
        total-bookings: u0,
        total-rating: u0,
        review-count: u0,
        created-at: block-height
      }
    )
    
    (var-set next-property-id (+ property-id u1))
    (ok property-id)
  )
)

(define-public (update-property-status (property-id uint) (is-active bool))
  (let ((property (unwrap! (map-get? properties { property-id: property-id }) ERR_PROPERTY_NOT_FOUND)))
    (asserts! (validate-property-id property-id) ERR_INVALID_INPUT)
    (asserts! (is-eq (get host property) tx-sender) ERR_NOT_AUTHORIZED)
    
    (map-set properties
      { property-id: property-id }
      (merge property { is-active: is-active })
    )
    (ok true)
  )
)

;; Guest Functions
(define-public (create-booking
  (property-id uint)
  (check-in uint)
  (check-out uint)
  (total-guests uint)
)
  (let (
    (property (unwrap! (map-get? properties { property-id: property-id }) ERR_PROPERTY_NOT_FOUND))
    (booking-id (var-get next-booking-id))
    (nights (get-days-between check-in check-out))
    (total-amount (* (get price-per-night property) nights))
    (platform-fee (calculate-platform-fee total-amount))
    (host-amount (- total-amount platform-fee))
  )
    ;; Input validation
    (asserts! (validate-property-id property-id) ERR_INVALID_INPUT)
    (asserts! (validate-uint-positive check-in) ERR_INVALID_INPUT)
    (asserts! (validate-uint-positive check-out) ERR_INVALID_INPUT)
    (asserts! (validate-uint-positive total-guests) ERR_INVALID_INPUT)
    
    (asserts! (get is-active property) ERR_PROPERTY_NOT_AVAILABLE)
    (asserts! (> check-out check-in) ERR_INVALID_DATES)
    (asserts! (<= total-guests (get max-guests property)) ERR_INVALID_DATES)
    (asserts! (<= nights u7) ERR_INVALID_DATES) ;; Max 7 night bookings
    
    ;; Check date availability for the entire range
    (asserts! (check-date-range-available property-id check-in check-out) ERR_PROPERTY_NOT_AVAILABLE)
    
    ;; Transfer payment
    (try! (stx-transfer? total-amount tx-sender (as-contract tx-sender)))
    
    ;; Create booking
    (map-set bookings
      { booking-id: booking-id }
      {
        property-id: property-id,
        guest: tx-sender,
        host: (get host property),
        check-in: check-in,
        check-out: check-out,
        total-guests: total-guests,
        total-amount: total-amount,
        platform-fee: platform-fee,
        status: "pending",
        created-at: block-height,
        confirmed-at: none,
        cancelled-at: none
      }
    )
    
    ;; Mark dates as unavailable (up to 7 days)
    (let ((days (get-days-between check-in check-out)))
      (set-single-date-availability property-id check-in false)
      (if (> days u1) (set-single-date-availability property-id (+ check-in u86400) false) true)
      (if (> days u2) (set-single-date-availability property-id (+ check-in (* u2 u86400)) false) true)
      (if (> days u3) (set-single-date-availability property-id (+ check-in (* u3 u86400)) false) true)
      (if (> days u4) (set-single-date-availability property-id (+ check-in (* u4 u86400)) false) true)
      (if (> days u5) (set-single-date-availability property-id (+ check-in (* u5 u86400)) false) true)
      (if (> days u6) (set-single-date-availability property-id (+ check-in (* u6 u86400)) false) true)
    )
    
    (var-set next-booking-id (+ booking-id u1))
    (ok booking-id)
  )
)

(define-public (cancel-booking (booking-id uint))
  (let ((booking (unwrap! (map-get? bookings { booking-id: booking-id }) ERR_BOOKING_NOT_FOUND)))
    (asserts! (validate-booking-id booking-id) ERR_INVALID_INPUT)
    (asserts! (is-eq (get guest booking) tx-sender) ERR_NOT_AUTHORIZED)
    (asserts! (is-eq (get status booking) "pending") ERR_NOT_AUTHORIZED)
    (asserts! (< block-height (+ (get created-at booking) CANCELLATION_WINDOW)) ERR_CANCELLATION_WINDOW_EXPIRED)
    
    ;; Refund guest
    (try! (as-contract (stx-transfer? (get total-amount booking) tx-sender (get guest booking))))
    
    ;; Mark dates as available again (up to 7 days)
    (let ((days (get-days-between (get check-in booking) (get check-out booking))))
      (set-single-date-availability (get property-id booking) (get check-in booking) true)
      (if (> days u1) (set-single-date-availability (get property-id booking) (+ (get check-in booking) u86400) true) true)
      (if (> days u2) (set-single-date-availability (get property-id booking) (+ (get check-in booking) (* u2 u86400)) true) true)
      (if (> days u3) (set-single-date-availability (get property-id booking) (+ (get check-in booking) (* u3 u86400)) true) true)
      (if (> days u4) (set-single-date-availability (get property-id booking) (+ (get check-in booking) (* u4 u86400)) true) true)
      (if (> days u5) (set-single-date-availability (get property-id booking) (+ (get check-in booking) (* u5 u86400)) true) true)
      (if (> days u6) (set-single-date-availability (get property-id booking) (+ (get check-in booking) (* u6 u86400)) true) true)
    )
    
    ;; Update booking status
    (map-set bookings
      { booking-id: booking-id }
      (merge booking { 
        status: "cancelled",
        cancelled-at: (some block-height)
      })
    )
    
    (ok true)
  )
)

;; Host confirmation
(define-public (confirm-booking (booking-id uint))
  (let ((booking (unwrap! (map-get? bookings { booking-id: booking-id }) ERR_BOOKING_NOT_FOUND)))
    (asserts! (validate-booking-id booking-id) ERR_INVALID_INPUT)
    (asserts! (is-eq (get host booking) tx-sender) ERR_NOT_AUTHORIZED)
    (asserts! (is-eq (get status booking) "pending") ERR_NOT_AUTHORIZED)
    
    ;; Transfer payment to host
    (let ((host-amount (- (get total-amount booking) (get platform-fee booking))))
      (try! (as-contract (stx-transfer? host-amount tx-sender (get host booking))))
      (var-set platform-balance (+ (var-get platform-balance) (get platform-fee booking)))
    )
    
    ;; Update booking status
    (map-set bookings
      { booking-id: booking-id }
      (merge booking { 
        status: "confirmed",
        confirmed-at: (some block-height)
      })
    )
    
    ;; Update property stats
    (let ((property (unwrap! (map-get? properties { property-id: (get property-id booking) }) ERR_PROPERTY_NOT_FOUND)))
      (map-set properties
        { property-id: (get property-id booking) }
        (merge property { 
          total-bookings: (+ (get total-bookings property) u1)
        })
      )
    )
    
    (ok true)
  )
)

;; Review System
(define-public (submit-review (booking-id uint) (rating uint) (comment (string-ascii 500)))
  (let ((booking (unwrap! (map-get? bookings { booking-id: booking-id }) ERR_BOOKING_NOT_FOUND)))
    ;; Input validation
    (asserts! (validate-booking-id booking-id) ERR_INVALID_INPUT)
    (asserts! (and (>= rating u1) (<= rating u5)) ERR_INVALID_RATING)
    (asserts! (validate-string-input comment) ERR_INVALID_INPUT)
    
    (asserts! (or (is-eq (get guest booking) tx-sender) (is-eq (get host booking) tx-sender)) ERR_NOT_AUTHORIZED)
    (asserts! (is-eq (get status booking) "completed") ERR_NOT_AUTHORIZED)
    (asserts! (is-none (map-get? reviews { booking-id: booking-id })) ERR_ALREADY_REVIEWED)
    
    (map-set reviews
      { booking-id: booking-id }
      {
        reviewer: tx-sender,
        rating: rating,
        comment: comment,
        created-at: block-height
      }
    )
    
    ;; Update property rating
    (let ((property (unwrap! (map-get? properties { property-id: (get property-id booking) }) ERR_PROPERTY_NOT_FOUND)))
      (map-set properties
        { property-id: (get property-id booking) }
        (merge property {
          total-rating: (+ (get total-rating property) rating),
          review-count: (+ (get review-count property) u1)
        })
      )
    )
    
    (ok true)
  )
)

;; Dispute System
(define-public (initiate-dispute (booking-id uint) (reason (string-ascii 500)))
  (let ((booking (unwrap! (map-get? bookings { booking-id: booking-id }) ERR_BOOKING_NOT_FOUND)))
    ;; Input validation
    (asserts! (validate-booking-id booking-id) ERR_INVALID_INPUT)
    (asserts! (validate-string-input reason) ERR_INVALID_INPUT)
    
    (asserts! (or (is-eq (get guest booking) tx-sender) (is-eq (get host booking) tx-sender)) ERR_NOT_AUTHORIZED)
    (asserts! (< block-height (+ (get check-out booking) DISPUTE_WINDOW)) ERR_DISPUTE_WINDOW_EXPIRED)
    
    (map-set disputes
      { booking-id: booking-id }
      {
        initiated-by: tx-sender,
        reason: reason,
        status: "pending",
        created-at: block-height,
        resolved-at: none
      }
    )
    
    ;; Update booking status
    (map-set bookings
      { booking-id: booking-id }
      (merge booking { status: "disputed" })
    )
    
    (ok true)
  )
)

;; Profile Management
(define-public (create-profile (username (string-ascii 50)) (email (string-ascii 100)))
  (begin
    ;; Input validation
    (asserts! (validate-username username) ERR_INVALID_INPUT)
    (asserts! (validate-email email) ERR_INVALID_INPUT)
    
    (map-set user-profiles
      { user: tx-sender }
      {
        username: username,
        email: email,
        total-bookings: u0,
        total-earnings: u0,
        reputation-score: u100, ;; Start with neutral score
        is-verified: false,
        joined-at: block-height
      }
    )
    (ok true)
  )
)

;; Admin Functions
(define-public (resolve-dispute (booking-id uint) (resolution (string-ascii 20)))
  (begin
    (asserts! (is-contract-owner) ERR_NOT_AUTHORIZED)
    (asserts! (validate-booking-id booking-id) ERR_INVALID_INPUT)
    (asserts! (> (len resolution) u0) ERR_INVALID_INPUT)
    
    (let ((dispute (unwrap! (map-get? disputes { booking-id: booking-id }) ERR_BOOKING_NOT_FOUND)))
      (map-set disputes
        { booking-id: booking-id }
        (merge dispute {
          status: resolution,
          resolved-at: (some block-height)
        })
      )
      (ok true)
    )
  )
)

(define-public (withdraw-platform-fees (amount uint))
  (begin
    (asserts! (is-contract-owner) ERR_NOT_AUTHORIZED)
    (asserts! (validate-uint-positive amount) ERR_INVALID_AMOUNT)
    (asserts! (<= amount (var-get platform-balance)) ERR_INSUFFICIENT_PAYMENT)
    
    (try! (as-contract (stx-transfer? amount tx-sender CONTRACT_OWNER)))
    (var-set platform-balance (- (var-get platform-balance) amount))
    (ok amount)
  )
)

;; Read-only Functions
(define-read-only (get-property (property-id uint))
  (map-get? properties { property-id: property-id })
)

(define-read-only (get-booking (booking-id uint))
  (map-get? bookings { booking-id: booking-id })
)

(define-read-only (get-property-availability (property-id uint) (date uint))
  (is-date-available property-id date)
)

(define-read-only (get-host-stake (host principal))
  (map-get? host-stakes { host: host })
)

(define-read-only (get-review (booking-id uint))
  (map-get? reviews { booking-id: booking-id })
)

(define-read-only (get-dispute (booking-id uint))
  (map-get? disputes { booking-id: booking-id })
)

(define-read-only (get-user-profile (user principal))
  (map-get? user-profiles { user: user })
)

(define-read-only (get-platform-balance)
  (var-get platform-balance)
)

(define-read-only (get-property-rating (property-id uint))
  (let ((property (map-get? properties { property-id: property-id })))
    (match property
      prop (if (> (get review-count prop) u0)
             (some (/ (get total-rating prop) (get review-count prop)))
             none)
      none
    )
  )
)

(define-read-only (calculate-booking-cost (property-id uint) (check-in uint) (check-out uint))
  (let ((property (map-get? properties { property-id: property-id })))
    (match property
      prop (let (
        (nights (get-days-between check-in check-out))
        (total-amount (* (get price-per-night prop) nights))
        (platform-fee (calculate-platform-fee total-amount))
      )
        (some {
          nights: nights,
          total-amount: total-amount,
          platform-fee: platform-fee,
          host-amount: (- total-amount platform-fee)
        })
      )
      none
    )
  )
)