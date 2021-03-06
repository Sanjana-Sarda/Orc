#lang racket

(require 2htdp/image 2htdp/universe)

(define MAX-HEALTH 35)
(define MAX-AGILITY 35)
(define MAX-STRENGTH 35)
(define ATTACKS# 4)
(define STAB-DAMAGE 2)
(define FLAIL-DAMAGE 3)
(define HEALING 8)
(define MONSTER# 12)
(define PER-ROW 4)
(unless (zero? (remainder MONSTER# PER-ROW))
  (error 'constraint "PER-ROW must divide MONSTER# evenly into rows"))
(define MONSTER-HEALTH0 9)
(define CLUB-STRENGTH 8)
(define SLIMINESS 5)
(define HEALTH-DAMAGE -2)
(define AGILITY-DAMAGE -3)
(define STRENGTH-DAMAGE -4)
(define STRENGTH "strength")
(define AGILITY "agility")
(define HEALTH "health")
(define LOSE "YOU LOSE")
(define WIN "YOU WIN")
(define DEAD "DEAD")
(define REMAINING "Remaining attacks ")
(define INSTRUCTIONS-2 "Select a monster using the arrow keys")
(define INSTRUCTIONS-1
  "Press S to stab a monster | Press F to Flail wildly | Press H to Heal")
(define HEALTH-BAR-HEIGHT 12)
(define HEALTH-BAR-WIDTH 50)
(define ORC (bitmap "graphics/orc.png"))
(define HYDRA (bitmap "graphics/hydra.png"))
(define SLIME (bitmap "graphics/slime.bmp"))
(define BRIGAND (bitmap "graphics/brigand.bmp"))
(define PIC-LIST (list ORC HYDRA SLIME BRIGAND))
(define w (apply max (map image-width PIC-LIST)))
(define h (apply max (map image-height PIC-LIST)))
(define PLAYER-IMAGE (bitmap "graphics/player.bmp"))
(define FRAME (rectangle w h 'outline 'white))
(define TARGET (circle (- (/ w 2) 2) 'outline 'blue))
(define ORC-IMAGE (overlay ORC FRAME))
(define HYDRA-IMAGE (overlay HYDRA FRAME))
(define SLIME-IMAGE (overlay SLIME FRAME))
(define BRIGAND-IMAGE (overlay BRIGAND FRAME))
(define V-SPACER (rectangle 0 10 "solid" "white"))
(define H-SPACER (rectangle 10 0 "solid" "white"))
(define AGILITY-COLOR "blue")
(define HEALTH-COLOR "crimson")
(define STRENGTH-COLOR "forest green")
(define MONSTER-COLOR "crimson")
(define MESSAGE-COLOR "black")
(define ATTACK-COLOR "crimson")
(define HEALTH-SIZE (- HEALTH-BAR-HEIGHT 4))
(define DEAD-TEXT-SIZE (- HEALTH-BAR-HEIGHT 2))
(define INSTRUCTION-TEXT-SIZE 16)
(define MESSAGES-SIZE 40)
(define INSTRUCTION-TEXT
  (above
   (text INSTRUCTIONS-2 (- INSTRUCTION-TEXT-SIZE 2) "blue")
   (text INSTRUCTIONS-1 (- INSTRUCTION-TEXT-SIZE 4) "blue")))
(define DEAD-TEXT (text DEAD DEAD-TEXT-SIZE "crimson"))

(struct orc-world (player lom attack# target) #:transparent #:mutable)

(struct player (health agility strength)#:transparent #:mutable)

(struct monster (image [health #:mutable])#:transparent)

(struct orc monster (club)#:transparent)
(struct hydra monster ()#:transparent)
(struct slime monster (sliminess)#:transparent)
(struct brigand monster ()#:transparent)

(define (start-orc)
  (big-bang (initialize-orc-world)
    (on-key player-acts-on-monsters)
    (to-draw render-orc-battle)
    (stop-when end-of-orc-battle? render-the-end)))

(define (initialize-orc-world)
  (define player0 (initialize-player))
  (define lom0 (initialize-monsters))
  (orc-world player0 lom0 (random-number-of-attacks player0) 0))

(define (end-of-orc-battle? w)
  (or (win? w) (lose? w)))

(define (render-orc-battle w)
  (render-orc-world w (orc-world-target w) (instructions w)))

(define (render-the-end w)
  (render-orc-world w #f (message (if (lose? w) LOSE WIN))))

(define (player-acts-on-monsters w k)
  (cond
    [(zero? (orc-world-attack# w)) (void)]
    [(key=? "s" k) (stab w)]
    [(key=? "h" k) (heal w)]
    [(key=? "f" k) (flail w)]
    [(key=? "e" k) (end-turn w)]
    [(key=? "n" k) (initialize-orc-world)]
    [(key=? "right" k) (move-target w +1)]
    [(key=? "left" k) (move-target w -1)]
    [(key=? "down" k) (move-target w (+ PER-ROW))]
    [(key=? "up" k) (move-target w (- PER-ROW))])
  (give-monster-turn-if-attack#=0 w)
  w)

(define (initialize-player)
  (player MAX-HEALTH MAX-AGILITY MAX-STRENGTH))

(define (random-number-of-attacks p)
  (random-quotient (player-agility p) ATTACKS#))

(define (random-quotient x y)
  (define div (quotient x y))
  (if (> 0 div) 0 (random+ (add1 div))))

(define (random+ n)
  (add1 (random n)))

(define (random- n)
  (- (add1 (random n))))

(define (interval- n m (max-value 100))
  (min (max 0 (- n m)) max-value))

(define (interval+ n m (max-value 100))
  (interval- n (- m) max-value))

(define (initialize-monsters)
  (define(create-monster _)
     (define health (random+ MONSTER-HEALTH0))
     (case (random 4)
       [(0) (orc ORC-IMAGE health (random+ CLUB-STRENGTH))]
       [(1) (hydra HYDRA-IMAGE health)]
       [(2) (slime SLIME-IMAGE health (random+ SLIMINESS))]
       [(3) (brigand BRIGAND-IMAGE health)]
       [else (error "can't happen")]))
   (build-list MONSTER# create-monster))
    
(define (stab-orc an-orc)
  (set-monster-health! an-orc (- (monster-health an-orc) STAB-DAMAGE)))

(define (player-update! setter selector mx)
  (lambda (player delta)
    (setter player (interval+ (selector player) delta mx))))

(define player-health+
  (player-update! set-player-health! player-health MAX-HEALTH))

(define player-agility+
  (player-update! set-player-agility! player-agility MAX-AGILITY))

(define player-strength+
  (player-update! set-player-strength! player-strength MAX-STRENGTH))

(define (instructions w)
  (define na (number->string (orc-world-attack# w)))
    (define ra (string-append REMAINING na))
    (define txt (text ra INSTRUCTION-TEXT-SIZE ATTACK-COLOR))
    (above txt INSTRUCTION-TEXT))

(define (message str)
  (text str MESSAGES-SIZE MESSAGE-COLOR))

(define (render-orc-world w t additional-text)
  (define i-player (render-player (orc-world-player w)))
  (define i-monster (render-monsters (orc-world-lom w) t))
  (above V-SPACER
         (beside H-SPACER
                 i-player
                 H-SPACER H-SPACER H-SPACER
                 (above i-monster
                        V-SPACER V-SPACER V-SPACER
                        additional-text)
                 H-SPACER)
         V-SPACER))

(define (render-player p)
  (define s (player-strength p))
  (define a (player-agility p))
  (define h (player-health p))
  (above/align
   "left"
   (status-bar s MAX-STRENGTH STRENGTH-COLOR STRENGTH)
   V-SPACER
   (status-bar a MAX-AGILITY AGILITY-COLOR AGILITY)
   V-SPACER
   (status-bar h MAX-HEALTH HEALTH-COLOR HEALTH)
   V-SPACER V-SPACER V-SPACER
   PLAYER-IMAGE))

(define (status-bar v-current v-max color label)
  (define w (* (/ v-current v-max) HEALTH-BAR-WIDTH))
  (define f (rectangle w HEALTH-BAR-HEIGHT 'solid color))
  (define b (rectangle HEALTH-BAR-WIDTH HEALTH-BAR-HEIGHT 'outline color))
  (define bar (overlay/align "left" "top" f b))
  (beside bar H-SPACER (text label HEALTH-SIZE color)))

(define (render-monsters lom with-target)
 (define target
   (if (number? with-target)
       (list-ref lom with-target)
       'a-silly-symbol-that-cannot-be-eq-to-an-orc))
  (define (render-one-monster m)
    (define image
      (if (eq? m target)
          (overlay TARGET (monster-image m))
          (monster-image m)))
    (define health (monster-health m))
    (define health-bar
      (if (= health 0)
          (overlay DEAD-TEXT (status-bar 0 1 'white ""))
          (status-bar health MONSTER-HEALTH0 MONSTER-COLOR "")))
    (above health-bar image))
  (arrange (map render-one-monster lom)))

(define (arrange lom)
  (cond
    [(empty? lom) empty-image]
    [else (define r (apply beside (take lom PER-ROW)))
          (above r (arrange (drop lom PER-ROW)))]))

(define (win? w)
  (all-dead? (orc-world-lom w)))

(define (lose? w)
  (player-dead? (orc-world-player w)))

(define (player-dead? p)
  (or (= (player-health p) 0)
      (= (player-agility p) 0)
      (= (player-strength p) 0)))

(define (all-dead? lom)
  (not (ormap monster-alive? lom)))

(define (monster-alive? m)
  (> (monster-health m) 0))

(define (end-turn w)
  (set-orc-world-attack#! w 0))

(define (heal w)
  (decrease-attack# w)
  (player-health+ (orc-world-player w) HEALING))

(define (stab w)
  (decrease-attack# w)
  (define target
    (list-ref (orc-world-lom w) (orc-world-target w)))
  (define damage
    (random-quotient (player-strength (orc-world-player w))
                     STAB-DAMAGE))
  (damage-monster target damage))

(define (flail w)
  (decrease-attack# w)
  (define target (current-target w))
  (define alive (filter monster-alive? (orc-world-lom w)))
  (define pick#
    (min
     (random-quotient (player-strength (orc-world-player w))
                      FLAIL-DAMAGE)
     (length alive)))
  (define getem (cons target (take alive pick#)))
  (for-each (lambda (m) (damage-monster m 1)) getem))

(define (decrease-attack# w)
  (set-orc-world-attack#! w (sub1 (orc-world-attack# w))))

(define (damage-monster m delta)
  (set-monster-health! m (interval- (monster-health m) delta)))

(define (current-target w)
  (list-ref (orc-world-lom w) (orc-world-target w)))

(define (move-target w delta)
  (define new (+ (orc-world-target w) delta))
  (set-orc-world-target! w (modulo new MONSTER#)))

(define (give-monster-turn-if-attack#=0 w)
  (when (zero? (orc-world-attack# w))
    (define player (orc-world-player w))
    (all-monsters-attack-player player (orc-world-lom w))
    (set-orc-world-attack#! w (random-number-of-attacks player))))

(define (all-monsters-attack-player player lom)
  (define (one-monster-attacks-player m)
    (cond
      [(orc? m)
       (player-health+ player (random- (orc-club m)))]
      [(hydra? m)
       (player-health+ player (random- (monster-health m)))]
      [(slime? m)
       (player-health+ player -1)
       (player-agility+ player
                        (random- (slime-sliminess m)))]
      [(brigand? m)
       (case (random 3)
         [(0) (player-health+ player HEALTH-DAMAGE)]
         [(1) (player-agility+ player AGILITY-DAMAGE)]
         [(2) (player-strength+ player STRENGTH-DAMAGE)])]))
  (for-each one-monster-attacks-player (filter monster-alive? lom)))


;                                          
;                                          
;                                          
;   ;;;;;;                                 
;   ;  ;                     ;             
;      ;     ;;;;    ;;;;;  ;;;;;    ;;;;; 
;      ;    ;    ;  ;    ;   ;      ;    ; 
;      ;    ;;;;;;   ;;;;    ;       ;;;;  
;      ;    ;            ;   ;           ; 
;      ;    ;       ;    ;   ;   ;  ;    ; 
;     ;;;    ;;;;;  ;;;;;     ;;;   ;;;;;  
;                                          
;                                          
;                                          
;                                          

(module+ test
  
  (require rackunit rackunit/text-ui)
  
  ;; Test structs
  (define WORLD0 (orc-world (initialize-player) empty 0 0))
  (define WORLD1 (struct-copy orc-world (initialize-orc-world) [attack# 5]))
  (define (WORLD2) (struct-copy orc-world (initialize-orc-world) [attack# 0]))
  ;; these are random worlds
  (define AN-ORC (orc 'image 0 5))
  (define A-SLIME (slime 'image 1 6))
  (define A-HYDRA (hydra 'image 2))
  (define A-BRIGAND (brigand 'image 3))
  
  ;; testing move-target
  
  
  (check-equal? (let ([w (orc-world 'dummy 'dummy 'dummy 0)])
                  (move-target w +1)
                  w)
                (orc-world 'dummy 'dummy 'dummy 1))
  (check-equal? (let ([w (orc-world 'dummy 'dummy 'dummy 0)])
                  (move-target w -1)
                  w)
                (orc-world 'dummy 'dummy 'dummy (- MONSTER# 1)))
  (check-equal? (let ([w (orc-world 'dummy 'dummy 'dummy 0)])
                  (move-target w (- PER-ROW))
                  w)
                (orc-world 'dummy 'dummy 'dummy (- MONSTER# PER-ROW)))
  (check-equal? (let ([w (orc-world 'dummy 'dummy 'dummy 1)])
                  (move-target w (+ PER-ROW))
                  w)
                (orc-world 'dummy 'dummy 'dummy (+ PER-ROW 1)))
  (check-equal? (begin
                  (move-target WORLD1 0)
                  WORLD1)
                WORLD1)
  (check-equal? (let ()
                  (define w (struct-copy orc-world WORLD1))
                  (move-target w 4)
                  w)
                (struct-copy orc-world WORLD1 [target (+ 4 (orc-world-target WORLD1))]))
  (check-equal? (current-target WORLD1) 
                (first (orc-world-lom WORLD1)))
  
  ;; testing basic player manipulations
  
  
  (check-equal? (let ([p (player 1 0 0)])
                  (player-health+ p 5)
                  p)
                (player 6 0 0))
  (check-equal? (let ([p (player 0 1 0)])
                  (player-agility+ p 5)
                  p)
                (player 0 6 0))
  
  (check-equal? (let ([p (player 0 0 1)])
                  (player-strength+ p 5)
                  p)
                (player 0 0 6))
  
  (check-equal? (let ([p (player 5 5 5)])
                  (all-monsters-attack-player p (list (orc 'image 1 1)))
                  p)
                (player 4 5 5))
  
  (check-equal? (let ([p (player 5 5 5)])
                  (all-monsters-attack-player p (list (hydra 'image 1)))
                  p)
                (player 4 5 5))
  
  (check-equal? (let ([p (player 5 5 5)])
                  (all-monsters-attack-player p (list (slime 'image 1 1)))
                  p)
                (player 4 4 5))
  
  (check member 
         (let ([p (player 5 5 5)]) 
           (all-monsters-attack-player p (list (brigand 'image 1)))
           p)
         (list (player 3 5 5)
               (player 5 2 5)
               (player 5 5 1)))
  
  ;; Properties
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  
  ;; Property:
  ;; the output will always be in [1, (/ X Y)]
  
  (define (prop:rand-frac-range i)
    (test-begin 
     (for ([i (in-range i)])
       (define x (random 4294967087))
       (define y (random 4294967087))
       (check-true (<= 1 (random-quotient x y) (add1 (/ x y)))))))
  
  ;; Property: 
  ;; The number of the monsters in the list is equal to
  ;; MONSTER-NUM
  
  (define (prop:monster-init-length i)
    (test-begin
     (for ([i (in-range i)])
       (check-true (= MONSTER#
                      (length (initialize-monsters)))))))
  
  ;; Property: 
  ;; the player will have less points in at least one of its
  ;; fields
  
  (define (prop:monster-attack-player-dec i)
    (test-begin
     (for ([i (in-range i)])
       (define pl (player MAX-HEALTH MAX-AGILITY MAX-STRENGTH))
       (define mon (first (initialize-monsters)))
       (begin 
         (all-monsters-attack-player pl (list mon))
         (check-true (or (< (player-health pl) MAX-HEALTH)
                         (< (player-agility pl) MAX-AGILITY)
                         (< (player-strength pl) MAX-STRENGTH)))))))
  
  ;; Property: 
  ;; If there are monster, then the player will 
  ;; have less points in at least one of its fields
  
  (define (prop:monsters-attack-player-dec i)
    (test-begin 
     (for ([i (in-range i)])
       (define pl (player MAX-HEALTH MAX-AGILITY MAX-STRENGTH))
       (define monsters (initialize-monsters))
       (define wor (orc-world pl monsters 0 0))
       (begin 
         (all-monsters-attack-player pl monsters)
         (check-true (or (< (player-health pl) MAX-HEALTH)
                         (< (player-agility pl) MAX-AGILITY)
                         (< (player-strength pl) MAX-STRENGTH)))))))
  
  ;; Property: The health of the targeted monster, m, 
  ;; is less than what it was. and
  ;; [(sub1 (monster-health m)), 
  ;; (- (monster-health m) 
  ;;    (/ (player-strength (orc-world-player w)) 2))]
  
  (define (prop:stab!-health i)
    (test-begin
     (for ([i (in-range i)])
       (begin (define mon (first(initialize-monsters)))
              (define ht (monster-health mon))
              (define pl (random-player))
              (define w (orc-world pl (list mon) 2 0))
              (stab w)
              (check-true (> ht (monster-health (first (orc-world-lom w)))))))))
  
  ;; random-player: -> Player
  ;; creates a random player
  (define (random-player)
    (player (add1 (random MAX-HEALTH))
            (add1 (random MAX-AGILITY))
            (add1 (random MAX-STRENGTH))))
  
  ;; testing initializers
  
  (prop:monster-init-length 1000)
  (check-true (monster? (first (initialize-monsters))))
  (check-true (> 10 (monster-health (first (initialize-monsters)))))
  (check-equal? (length (initialize-monsters)) MONSTER#)
  (check-equal? (length (orc-world-lom WORLD1)) MONSTER#)
  (check-true (>= (let ([p (initialize-player)])
                    (player-health p))
                  (let ([p (initialize-player)])
                    (all-monsters-attack-player p (list AN-ORC))
                    (player-health p))))
  (check-true (> (player-health (initialize-player)) 
                 (let ([p (initialize-player)])
                   (all-monsters-attack-player p (list A-HYDRA))
                   (player-health p))))
  (check-true (< (let ([p (initialize-player)])
                   (all-monsters-attack-player p (list A-SLIME))
                   (player-agility p))
                 (let ([p (initialize-player)])
                   (player-agility p))))
  (check-true (let ([p (initialize-player)])
                (all-monsters-attack-player p (list A-BRIGAND))
                (or (= (player-health p)
                       (- (player-health (initialize-player)) 2))
                    (= (player-agility p)
                       (- (player-agility (initialize-player)) 3))
                    (= (player-strength p)
                       (- (player-strength (initialize-player)) 4)))))
  (check-equal? (length (orc-world-lom WORLD1)) MONSTER#)
  (check-equal? (orc-world-player WORLD1) (orc-world-player WORLD1))
  
  ;; testing the-monster's attacks
  
  (prop:monster-attack-player-dec 1000)
  (prop:monsters-attack-player-dec 1000)
  (check-true (or (> (player-health (orc-world-player (WORLD2)))
                     (player-health (orc-world-player 
                                     (let ([w (WORLD2)])
                                       (all-monsters-attack-player (orc-world-player w) (orc-world-lom w))
                                       w))))
                  (> (player-strength (orc-world-player (WORLD2)))
                     (player-strength (orc-world-player
                                       (let ([w (WORLD2)])
                                         (all-monsters-attack-player (orc-world-player w) (orc-world-lom w))
                                         w))))
                  (> (player-agility (orc-world-player (WORLD2)))
                     (player-agility (orc-world-player
                                      (let ([w (WORLD2)])
                                        (all-monsters-attack-player (orc-world-player w) (orc-world-lom w))
                                        w))))))
  
  ;; testing the player's actions
  
  (prop:stab!-health 1000)
  (test-begin (define o (orc 'image 0 5))
              (damage-monster o 5)
              (check-equal? o (orc 'image 0 5)))
  (test-begin (define o (orc 'image 0 5))
              (damage-monster o 0)
              (check-equal? o (orc 'image 0 5)))
  (check-equal? (player-health (orc-world-player
                                (let () 
                                  (define w (struct-copy orc-world WORLD1))
                                  (heal w)
                                  w)))
                (min MAX-HEALTH
                     (+ 8 (player-health (orc-world-player WORLD1)))))
  
  (check-equal? (length (orc-world-lom 
                         (let ()
                           (define w (struct-copy orc-world WORLD1))
                           (stab w)
                           w)))
                MONSTER#)
  
  ;; testing game predicates

  (check-false (lose? WORLD0))
  (check-true (lose? (orc-world (player 0 30 30) empty 0 0)))
  (check-true (all-dead? (list (orc 'image 0 0) (hydra 'image 0))))
  (check-true (all-dead? (list AN-ORC)))
  (check-true (win? (orc-world (initialize-player) (list (orc 'image 0 0)) 0 0)))
  (check-true (win? (orc-world (initialize-player) (list AN-ORC) 0 0)))
  (check-true (end-of-orc-battle? (orc-world (initialize-player) (list (orc 'image 0 0)) 0 0)))
  (check-true (end-of-orc-battle? (orc-world (initialize-player) (list AN-ORC) 0 0)))
  (check-true (end-of-orc-battle? (orc-world (player 0 30 30) empty 0 0)))
  (check-true (player-dead? (player 0 2 5)))
  (check-false (player-dead? (initialize-player)))
  (check-false (not (monster-alive? A-HYDRA)))
  (check-true (monster-alive? (monster 'image 1)))
  (check-false (monster-alive? (orc 'image 0 0)))
  
  ;; testing utilities 
  (prop:rand-frac-range 1000)
  
  )