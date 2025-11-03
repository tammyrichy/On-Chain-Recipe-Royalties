(define-non-fungible-token recipe-nft uint)
(define-fungible-token recipe-token)

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-authorized (err u101))
(define-constant err-recipe-not-found (err u102))
(define-constant err-insufficient-balance (err u103))
(define-constant err-recipe-already-exists (err u104))
(define-constant err-invalid-royalty (err u105))
(define-constant err-license-not-found (err u106))
(define-constant err-already-licensed (err u107))
(define-constant err-invalid-rating (err u108))
(define-constant err-already-rated (err u109))
(define-constant err-fork-not-allowed (err u110))
(define-constant err-invalid-percentage (err u111))
(define-constant err-subscription-not-found (err u112))
(define-constant err-subscription-expired (err u113))
(define-constant err-subscription-active (err u114))

(define-constant platform-fee-percentage u5)
(define-constant max-royalty-percentage u50)
(define-constant min-license-fee u1000000)
(define-constant collaboration-bonus u10)
(define-constant blocks-per-month u4320)
(define-constant subscription-discount-percentage u30)

(define-data-var recipe-id-nonce uint u1)
(define-data-var license-id-nonce uint u1)
(define-data-var fork-id-nonce uint u1)
(define-data-var total-platform-earnings uint u0)
(define-data-var subscription-id-nonce uint u1)

(define-map recipes uint {
    chef: principal,
    title: (string-utf8 100),
    cuisine-type: (string-ascii 30),
    difficulty: uint,
    prep-time: uint,
    servings: uint,
    royalty-percentage: uint,
    total-earnings: uint,
    license-fee: uint,
    fork-allowed: bool,
    created-at: uint
})

(define-map recipe-ingredients uint {
    recipe-id: uint,
    ingredients-list: (string-utf8 500),
    instructions: (string-utf8 1000),
    nutrition-info: (optional (string-utf8 200))
})

(define-map recipe-licenses uint {
    license-id: uint,
    recipe-id: uint,
    licensee: principal,
    licensed-at: uint,
    usage-count: uint,
    commercial-use: bool
})

(define-map user-licenses { user: principal, recipe-id: uint } {
    license-id: uint,
    active: bool
})

(define-map recipe-ratings { recipe-id: uint, rater: principal } {
    rating: uint,
    review: (optional (string-utf8 200)),
    rated-at: uint
})

(define-map recipe-stats uint {
    total-licenses: uint,
    average-rating: uint,
    total-ratings: uint,
    total-forks: uint,
    trending-score: uint
})

(define-map recipe-forks uint {
    original-recipe-id: uint,
    forked-recipe-id: uint,
    fork-chef: principal,
    royalty-split: uint,
    forked-at: uint
})

(define-map chef-profiles principal {
    total-recipes: uint,
    total-earnings: uint,
    reputation-score: uint,
    verified: bool
})

(define-map collaborations uint {
    recipe-id: uint,
    collaborators: (list 10 principal),
    revenue-shares: (list 10 uint)
})

(define-map recipe-subscriptions uint {
    subscription-id: uint,
    recipe-id: uint,
    subscriber: principal,
    start-block: uint,
    expiry-block: uint,
    monthly-fee: uint,
    auto-renew: bool,
    total-months-paid: uint
})

(define-map user-subscriptions { user: principal, recipe-id: uint } {
    subscription-id: uint,
    active: bool
})

(define-public (mint-recipe
    (title (string-utf8 100))
    (cuisine-type (string-ascii 30))
    (difficulty uint)
    (prep-time uint)
    (servings uint)
    (ingredients (string-utf8 500))
    (instructions (string-utf8 1000))
    (license-fee uint)
    (royalty-percentage uint)
    (fork-allowed bool))
  (let ((recipe-id (var-get recipe-id-nonce)))
    (asserts! (<= royalty-percentage max-royalty-percentage) err-invalid-royalty)
    (asserts! (>= license-fee min-license-fee) err-invalid-royalty)
    (asserts! (<= difficulty u5) err-invalid-rating)
    
    (try! (nft-mint? recipe-nft recipe-id tx-sender))
    
    (map-set recipes recipe-id {
        chef: tx-sender,
        title: title,
        cuisine-type: cuisine-type,
        difficulty: difficulty,
        prep-time: prep-time,
        servings: servings,
        royalty-percentage: royalty-percentage,
        total-earnings: u0,
        license-fee: license-fee,
        fork-allowed: fork-allowed,
        created-at: stacks-block-height
    })
    
    (map-set recipe-ingredients recipe-id {
        recipe-id: recipe-id,
        ingredients-list: ingredients,
        instructions: instructions,
        nutrition-info: none
    })
    
    (map-set recipe-stats recipe-id {
        total-licenses: u0,
        average-rating: u0,
        total-ratings: u0,
        total-forks: u0,
        trending-score: u0
    })
    
    (update-chef-profile tx-sender u0)
    (var-set recipe-id-nonce (+ recipe-id u1))
    (ok recipe-id)))

(define-public (purchase-license (recipe-id uint) (commercial-use bool))
  (let (
    (recipe (unwrap! (map-get? recipes recipe-id) err-recipe-not-found))
    (license-id (var-get license-id-nonce))
    (license-fee (get license-fee recipe))
    (final-fee (if commercial-use (* license-fee u2) license-fee))
    (platform-fee (/ (* final-fee platform-fee-percentage) u100))
    (chef-earning (- final-fee platform-fee)))
    
    (asserts! (is-none (map-get? user-licenses { user: tx-sender, recipe-id: recipe-id })) err-already-licensed)
    
    (try! (stx-transfer? final-fee tx-sender (as-contract tx-sender)))
    (try! (as-contract (stx-transfer? chef-earning tx-sender (get chef recipe))))
    
    (map-set recipe-licenses license-id {
        license-id: license-id,
        recipe-id: recipe-id,
        licensee: tx-sender,
        licensed-at: stacks-block-height,
        usage-count: u0,
        commercial-use: commercial-use
    })
    
    (map-set user-licenses 
        { user: tx-sender, recipe-id: recipe-id }
        { license-id: license-id, active: true })
    
    (map-set recipes recipe-id
        (merge recipe { total-earnings: (+ (get total-earnings recipe) chef-earning) }))
    
    (let ((stats (unwrap! (map-get? recipe-stats recipe-id) err-recipe-not-found)))
        (map-set recipe-stats recipe-id
            (merge stats { total-licenses: (+ (get total-licenses stats) u1) })))
    
    (update-chef-profile (get chef recipe) chef-earning)
    (var-set total-platform-earnings (+ (var-get total-platform-earnings) platform-fee))
    (var-set license-id-nonce (+ license-id u1))
    (ok license-id)))

(define-public (rate-recipe (recipe-id uint) (rating uint) (review (optional (string-utf8 200))))
  (let (
    (recipe (unwrap! (map-get? recipes recipe-id) err-recipe-not-found))
    (stats (unwrap! (map-get? recipe-stats recipe-id) err-recipe-not-found)))
    
    (asserts! (<= rating u5) err-invalid-rating)
    (asserts! (> rating u0) err-invalid-rating)
    (asserts! (is-none (map-get? recipe-ratings { recipe-id: recipe-id, rater: tx-sender })) err-already-rated)
    
    (map-set recipe-ratings 
        { recipe-id: recipe-id, rater: tx-sender }
        { rating: rating, review: review, rated-at: stacks-block-height })
    
    (let (
        (new-total-ratings (+ (get total-ratings stats) u1))
        (new-average (/ (+ (* (get average-rating stats) (get total-ratings stats)) rating) new-total-ratings)))
        (map-set recipe-stats recipe-id
            (merge stats { 
                average-rating: new-average,
                total-ratings: new-total-ratings,
                trending-score: (calculate-trending-score new-average new-total-ratings (get total-licenses stats))
            })))
    (ok true)))

(define-public (fork-recipe 
    (original-recipe-id uint)
    (new-title (string-utf8 100))
    (modifications (string-utf8 500))
    (royalty-split uint))
  (let (
    (original-recipe (unwrap! (map-get? recipes original-recipe-id) err-recipe-not-found))
    (forked-recipe-id (var-get recipe-id-nonce)))
    
    (asserts! (get fork-allowed original-recipe) err-fork-not-allowed)
    (asserts! (<= royalty-split u50) err-invalid-percentage)
    
    (try! (nft-mint? recipe-nft forked-recipe-id tx-sender))
    
    (map-set recipes forked-recipe-id {
        chef: tx-sender,
        title: new-title,
        cuisine-type: (get cuisine-type original-recipe),
        difficulty: (get difficulty original-recipe),
        prep-time: (get prep-time original-recipe),
        servings: (get servings original-recipe),
        royalty-percentage: (get royalty-percentage original-recipe),
        total-earnings: u0,
        license-fee: (get license-fee original-recipe),
        fork-allowed: true,
        created-at: stacks-block-height
    })
    
    (let ((original-ingredients (unwrap! (map-get? recipe-ingredients original-recipe-id) err-recipe-not-found)))
        (map-set recipe-ingredients forked-recipe-id {
            recipe-id: forked-recipe-id,
            ingredients-list: (get ingredients-list original-ingredients),
            instructions: modifications,
            nutrition-info: none
        }))
    
    (map-set recipe-forks (var-get fork-id-nonce) {
        original-recipe-id: original-recipe-id,
        forked-recipe-id: forked-recipe-id,
        fork-chef: tx-sender,
        royalty-split: royalty-split,
        forked-at: stacks-block-height
    })
    
    (let ((stats (unwrap! (map-get? recipe-stats original-recipe-id) err-recipe-not-found)))
        (map-set recipe-stats original-recipe-id
            (merge stats { total-forks: (+ (get total-forks stats) u1) })))
    
    (map-set recipe-stats forked-recipe-id {
        total-licenses: u0,
        average-rating: u0,
        total-ratings: u0,
        total-forks: u0,
        trending-score: u0
    })
    
    (var-set recipe-id-nonce (+ forked-recipe-id u1))
    (var-set fork-id-nonce (+ (var-get fork-id-nonce) u1))
    (ok forked-recipe-id)))

(define-public (update-nutrition-info (recipe-id uint) (nutrition-info (string-utf8 200)))
  (let (
    (recipe (unwrap! (map-get? recipes recipe-id) err-recipe-not-found))
    (ingredients (unwrap! (map-get? recipe-ingredients recipe-id) err-recipe-not-found)))
    
    (asserts! (is-eq tx-sender (get chef recipe)) err-not-authorized)
    
    (map-set recipe-ingredients recipe-id
        (merge ingredients { nutrition-info: (some nutrition-info) }))
    (ok true)))

(define-public (transfer-recipe (recipe-id uint) (new-owner principal))
  (let ((recipe (unwrap! (map-get? recipes recipe-id) err-recipe-not-found)))
    (asserts! (is-eq tx-sender (get chef recipe)) err-not-authorized)
    
    (try! (nft-transfer? recipe-nft recipe-id tx-sender new-owner))
    
    (map-set recipes recipe-id
        (merge recipe { chef: new-owner }))
    (ok true)))

(define-public (withdraw-platform-fees)
  (let ((earnings (var-get total-platform-earnings)))
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (> earnings u0) err-insufficient-balance)
    
    (try! (as-contract (stx-transfer? earnings tx-sender contract-owner)))
    (var-set total-platform-earnings u0)
    (ok earnings)))

(define-private (calculate-trending-score (rating uint) (total-ratings uint) (licenses uint))
  (+ (+ (* rating u10) (* total-ratings u5)) (* licenses u20)))

(define-private (update-chef-profile (chef principal) (earnings uint))
  (let ((profile (default-to 
        { total-recipes: u0, total-earnings: u0, reputation-score: u0, verified: false }
        (map-get? chef-profiles chef))))
    (map-set chef-profiles chef {
        total-recipes: (+ (get total-recipes profile) u1),
        total-earnings: (+ (get total-earnings profile) earnings),
        reputation-score: (+ (get reputation-score profile) u10),
        verified: (get verified profile)
    })))

(define-read-only (get-recipe (recipe-id uint))
  (map-get? recipes recipe-id))

(define-read-only (get-recipe-details (recipe-id uint))
  (map-get? recipe-ingredients recipe-id))

(define-read-only (get-recipe-stats (recipe-id uint))
  (map-get? recipe-stats recipe-id))

(define-read-only (get-user-license (user principal) (recipe-id uint))
  (map-get? user-licenses { user: user, recipe-id: recipe-id }))

(define-read-only (get-chef-profile (chef principal))
  (map-get? chef-profiles chef))

(define-read-only (get-platform-earnings)
  (ok (var-get total-platform-earnings)))

(define-read-only (get-recipe-rating (recipe-id uint) (rater principal))
  (map-get? recipe-ratings { recipe-id: recipe-id, rater: rater }))

(define-public (subscribe-to-recipe (recipe-id uint) (auto-renew bool))
  (let (
    (recipe (unwrap! (map-get? recipes recipe-id) err-recipe-not-found))
    (subscription-id (var-get subscription-id-nonce))
    (license-fee (get license-fee recipe))
    (monthly-fee (- license-fee (/ (* license-fee subscription-discount-percentage) u100)))
    (platform-fee (/ (* monthly-fee platform-fee-percentage) u100))
    (chef-earning (- monthly-fee platform-fee))
    (expiry-block (+ stacks-block-height blocks-per-month)))
    
    (asserts! (is-none (map-get? user-subscriptions { user: tx-sender, recipe-id: recipe-id })) err-subscription-active)
    
    (try! (stx-transfer? monthly-fee tx-sender (as-contract tx-sender)))
    (try! (as-contract (stx-transfer? chef-earning tx-sender (get chef recipe))))
    
    (map-set recipe-subscriptions subscription-id {
        subscription-id: subscription-id,
        recipe-id: recipe-id,
        subscriber: tx-sender,
        start-block: stacks-block-height,
        expiry-block: expiry-block,
        monthly-fee: monthly-fee,
        auto-renew: auto-renew,
        total-months-paid: u1
    })
    
    (map-set user-subscriptions 
        { user: tx-sender, recipe-id: recipe-id }
        { subscription-id: subscription-id, active: true })
    
    (map-set recipes recipe-id
        (merge recipe { total-earnings: (+ (get total-earnings recipe) chef-earning) }))
    
    (update-chef-profile (get chef recipe) chef-earning)
    (var-set total-platform-earnings (+ (var-get total-platform-earnings) platform-fee))
    (var-set subscription-id-nonce (+ subscription-id u1))
    (ok subscription-id)))

(define-public (renew-subscription (recipe-id uint))
  (let (
    (user-sub (unwrap! (map-get? user-subscriptions { user: tx-sender, recipe-id: recipe-id }) err-subscription-not-found))
    (subscription-id (get subscription-id user-sub))
    (subscription (unwrap! (map-get? recipe-subscriptions subscription-id) err-subscription-not-found))
    (recipe (unwrap! (map-get? recipes recipe-id) err-recipe-not-found))
    (monthly-fee (get monthly-fee subscription))
    (platform-fee (/ (* monthly-fee platform-fee-percentage) u100))
    (chef-earning (- monthly-fee platform-fee))
    (new-expiry (+ (get expiry-block subscription) blocks-per-month)))
    
    (asserts! (get active user-sub) err-subscription-not-found)
    
    (try! (stx-transfer? monthly-fee tx-sender (as-contract tx-sender)))
    (try! (as-contract (stx-transfer? chef-earning tx-sender (get chef recipe))))
    
    (map-set recipe-subscriptions subscription-id
        (merge subscription { 
            expiry-block: new-expiry,
            total-months-paid: (+ (get total-months-paid subscription) u1)
        }))
    
    (map-set recipes recipe-id
        (merge recipe { total-earnings: (+ (get total-earnings recipe) chef-earning) }))
    
    (update-chef-profile (get chef recipe) chef-earning)
    (var-set total-platform-earnings (+ (var-get total-platform-earnings) platform-fee))
    (ok new-expiry)))

(define-public (cancel-subscription (recipe-id uint))
  (let (
    (user-sub (unwrap! (map-get? user-subscriptions { user: tx-sender, recipe-id: recipe-id }) err-subscription-not-found))
    (subscription-id (get subscription-id user-sub))
    (subscription (unwrap! (map-get? recipe-subscriptions subscription-id) err-subscription-not-found)))
    
    (asserts! (get active user-sub) err-subscription-not-found)
    
    (map-set recipe-subscriptions subscription-id
        (merge subscription { auto-renew: false }))
    
    (map-set user-subscriptions 
        { user: tx-sender, recipe-id: recipe-id }
        { subscription-id: subscription-id, active: false })
    (ok true)))

(define-read-only (get-subscription (user principal) (recipe-id uint))
  (match (map-get? user-subscriptions { user: user, recipe-id: recipe-id })
    user-sub (map-get? recipe-subscriptions (get subscription-id user-sub))
    none))

(define-read-only (is-subscription-valid (user principal) (recipe-id uint))
  (match (get-subscription user recipe-id)
    subscription (ok (and 
        (>= (get expiry-block subscription) stacks-block-height)
        (is-some (map-get? user-subscriptions { user: user, recipe-id: recipe-id }))))
    (ok false)))

;; title: On-Chain-Recipe-Royalties
;; version:
;; summary:
;; description:

;; traits
;;

;; token definitions
;;

;; constants
;;

;; data vars
;;

;; data maps
;;

;; public functions
;;

;; read only functions
;;

;; private functions
;;

