

;;; Stream implementation from CP_3
(define the-empty-stream '())
(define (memoize proc)
  (let ((run? #f) (result #f))
    (lambda ()
      (if (not run?)
	  (begin
	    (set! result (proc))
	    (set! run? #t)
	    result)
	  result))))
(define-syntax cons-stream
  (syntax-rules ()
    [(_ a d) (cons a (memoize (delay d)))]))
(define (stream-car st) (car st))
(define (stream-cdr st) (force (cdr st)))
(define (stream-ref st n)
  (if (= n 0)
      (stream-car st)
      (stream-ref (stream-cdr st) (- n 1))))
(define (stream-append-delayed s1 delayed-s2)
  (if (stream-null? s1)
      (force delayed-s2)
      (cons-stream
       (stream-car s1)
       (stream-append-delayed (stream-cdr s1) delayed-s2))))
(define (stream-append s1 s2)
  (if (stream-null? s1)
      s2
      (cons-stream
       (stream-car s1)
       (stream-append (stream-cdr s1) s2))))
(define stream-null? null?)
(define (stream-filter f st)
  (if (stream-null? st)
      st
      (if (f (stream-car st))
	  (cons-stream
	   (stream-car st)
	   (stream-filter f (stream-cdr st)))
	  (stream-filter f (stream-cdr st)))))
(define (stream-map proc . argstreams)
  (if (null? (car argstreams))
      the-empty-stream
      (cons-stream
       (apply proc (map stream-car argstreams))
       (apply stream-map
	      (cons proc (map stream-cdr argstreams))))))
(define (stream-flatmap proc s)
  (flatten-stream (stream-map proc s)))
(define (flatten-stream stream)
  (if (stream-null? stream)
      the-empty-stream
      (interleave-delayed
       (stream-car stream)
       (delay (flatten-stream (stream-cdr stream))))))
(define (add-streams . s)
  (apply stream-map (cons + s)))
(define (mul-streams s1 s2)
  (stream-map * s1 s2))
(define (div-streams s1 s2)
  (stream-map / s1 s2))
(define (scale-stream st factor)
  (cons-stream
   (* factor (stream-car st))
   (scale-stream (stream-cdr st) factor)))
(define (partial-sums stream)
    (define psstream
      (cons-stream
        (stream-car stream)
        (add-streams psstream (stream-cdr stream))))
    psstream)
(define (repeat n) (define self (cons-stream n self)) self)
(define (singleton-stream x) (cons-stream x the-empty-stream))
(define (interleave s1 s2)
  (if (stream-null? s1)
      s2
      (cons-stream
       (stream-car s1)
       (interleave s2 (stream-cdr s1)))))
(define (interleave-delayed s1 delayed-s2)
  (if (stream-null? s1)
      (force delayed-s2)
      (cons-stream
       (stream-car s1)
       (interleave-delayed (force delayed-s2)
			   (delay (stream-cdr s1))))))
(define ones (repeat 1))
(define integers (cons-stream 1 (add-streams integers ones)))
(define (display-stream st until)
  (define (iter st until)
    (cond
     ((stream-null? st))
     ((= until 0) (display "..."))
     (else
      (display (stream-car st))
      (newline)
      (if (not (stream-null? (stream-cdr st))) (display " "))
      (iter (stream-cdr st) (- until 1)))))
  (display "(")
  (iter st until)
  (display ")")
  (newline))


(define (Query)
  ;;; table - primitive
  (define THE-TABLE (make-hash-table))
  (define (get . smth)
    (define (get-child table . smth)
      (if (null? smth)
	  table
	  (let ((obj (get-hash-table table (car smth) #f)))
	    (if obj
		(apply get-child obj (cdr smth))
		#f))))
    (apply get-child THE-TABLE smth))
  (define (put . smth)
    (define (put-child table . smth)
      (if (null? (cddr smth))
	  (put-hash-table! table (car smth) (cadr smth))
	  (let ((obj (get-hash-table table (car smth) #f)))
	    (if obj
		(apply put-child obj (cdr smth))
		(begin
		  (let ((new-table (make-hash-table)))
		    (put-hash-table! table (car smth) new-table)
		    (apply put-child new-table (cdr  smth))))))))
    (apply put-child THE-TABLE smth)
    'ok)
  ;;; Query syntax
  (define (type exp)
    (if (pair? exp)
	(car exp)
	(errorf 'type "Unknown expression:~s" exp)))
  (define (contents exp)
    (if (pair? exp)
	(cdr exp)
	(errorf 'contents "Unknown expression:~s" exp)))
  (define (assertion-to-be-added? exp)
    (eq? (type exp) 'assert!))
  (define (add-assertion-body exp)
    (car (contents exp)))
  (define (empty-conjunction? exps) (null? exps))
  (define (first-conjunct exps) (car exps))
  (define (rest-conjuncts exps) (cdr exps))
  (define (empty-disjuncttion? exps) (null? exps))
  (define (first-disjunct exps) (car exps))
  (define (rest-disjuncts exps) (cdr exps))
  (define (negated-query exps) (car exps))
  (define (predicate exps) (car exps))
  (define (args exps) (cdr exps))
  (define (rule? statement)
    (tagged-list? statement 'rule))
  (define (conclusion rule) (cadr rule))
  (define (rule-body rule)
    (if (null? (cddr rule))
	'(always-true)
	(caddr rule)))
  (define (query-syntax-process exp)
    (map-over-symbols expand-question-mark exp))
  (define (map-over-symbols proc exp)
    (cond
     ((pair? exp)
      (cons (map-over-symbols proc (car exp))
	    (map-over-symbols proc (cdr exp))))
     ((symbol? exp) (proc exp))
     (else exp)))
  (define (expand-question-mark symbol)
    (let ((chars (symbol->string symbol)))
      (if (string=? (substring chars 0 1) "?")
	  (list '?
		(string->symbol
		 (substring chars 1 (string-length chars))))
	  symbol)))
  (define (var? exp)
    (tagged-list? exp '?))
  (define (tagged-list? exp tag)
    (if (pair? exp)
	(eq? (car exp) tag)
	#f))
  (define (constant-symbol? exp) (symbol? exp))
  (define rule-counter 0)
  (define (new-rule-application-id)
    (set! rule-counter (+ 1 rule-counter)))
  (define (make-new-variable var rule-application-id)
    (cons '? (cons rule-application-id (cdr var))))
  (define (contract-question-mark variable)
    (string->symbol
     (string-append
      "?"
      (if (number? (cadr variable))
	  (string-append (symbol->string (caddr variable))
			 "-"
			 (number->string (cadr variable)))
	  (symbol->string (cadr variable))))))
  ;;; Frames&Bindings
  (define (make-binding variable value)
    (cons variable value))
  (define (binding-variable binding) (car binding))
  (define (binding-value binding) (cdr binding))
  (define (binding-in-frame variable frame) (assoc variable frame))
  (define (extend variable value frame)
    (cons (make-binding variable value) frame))
  ;;; DATA Stream
  (define (get-stream key1 key2)
    (let ((s (get key1 key2)))
      (if s s the-empty-stream)))
  (define THE-ASSERTIONS the-empty-stream)
  (define (fetch-assertions pattern frame)
    (if (use-index? pattern)
	(get-indexed-assertions pattern)
	(get-all-assertions)))
  (define (get-all-assertions) THE-ASSERTIONS)
  (define (get-indexed-assertions pattern)
    (get-stream (index-key-of pattern) 'assertion-stream))
  (define THE-RULES the-empty-stream)
  (define (fetch-rules pattern frame)
    (if (use-index? pattern)
	(get-indexed-rules pattern)
	(get-all-rules)))
  (define (get-all-rules) THE-RULES)
  (define (get-indexed-rules pattern)
    (stream-append
     (get-stream (index-key-of pattern) 'rule-stream)
     (get-stream '? 'rule-stream)))

  ;;; RULE/ASSERT ADD F
  (define (add-rule-or-assertion! assertion)
    (if (rule? assertion)
	(add-rule! assertion)
	(add-assertion! assertion)))
  (define (add-assertion! assertion) ;; Maybe a bug
    (store-assertion-in-index assertion)
    (let ((old-assertions THE-ASSERTIONS))
      (set! THE-ASSERTIONS
	    (cons-stream assertion old-assertions))
      'ok))
  (define (add-rule! rule)
    (store-rule-in-index rule)
    (let ((old-rules THE-RULES))
      (set! THE-RULES (cons-stream rule old-rules))
      'ok))
  (define (store-assertion-in-index assertion)
    (if (indexable? assertion)
	(let ((key (index-key-of assertion)))
	  (let ((current-assertion-stream
		 (get-stream key 'assertion-stream)))
	    (put key
		 'assertion-stream
		 (cons-stream assertion
			      current-assertion-stream))))))
  (define (store-rule-in-index rule)
    (let ((pattern (conclusion rule)))
      (if (indexable? pattern)
	  (let ((key (index-key-of pattern)))
	    (let ((current-rule-stream
		   (get-stream key 'rule-stream)))
	      (put key
		   'rule-stream
		   (cons-stream rule
				current-rule-stream)))))))
  (define (indexable? pat)
    (or (constant-symbol? (car pat))
	(var? (car pat))))
  (define (index-key-of pat)
    (let ((key (car pat)))
      (if (var? key) '? key)))
  (define (use-index? pat)
    (constant-symbol? (car pat)))



  
  ;;;basic logic funcs
  (define (conjoin conjuncts frame-stream) ;and
    (if (empty-conjunction? conjuncts)
	frame-stream
	(conjoin (rest-conjuncts conjuncts)
		 (qeval (first-conjunct conjuncts)
			frame-stream))))
  (define (disjoin disjuncts frame-stream) ;or
    (if (empty-disjuncttion? disjuncts)
	the-empty-stream
	(interleave-delayed
	 (qeval (first-disjunct disjuncts) frame-stream)
	 (delay (disjoin (rest-disjuncts disjuncts)
			 frame-stream)))))
  (define (negate operands frame-stream) ;not
    (stream-flatmap
     (lambda (frame)
       (if (stream-null? (qeval (negated-query operands)
				(singleton-stream frame)))
	   (singleton-stream frame)
	   the-empty-stream))
     frame-stream))
  (define (lisp-value call frame-stream) ;lisp-value
    (define (execute exp)
      (apply (eval (predicate exp)) (args exp)))
    (stream-flatmap
     (lambda (frame)
       (if (execute
	    (instantiate call frame
			 (lambda (v f)
			   (errorf 'NOT "Unknown pat var ~s" v))))
	   (singleton-stream frame)
	   the-empty-stream))
     frame-stream))
  (define (always-true ignore frame-stream) frame-stream); always-true

  ;;; Pattern-match
  (define (pattern-match pat dat frame)
    (define (extend-if-consistent var dat frame)
      (let ((binding (binding-in-frame var frame)))
	(if binding
	    (pattern-match (binding-value binding) dat frame)
	    (extend var dat frame))))
    (cond
     ((eq? frame 'failed) 'failed)
     ((equal? pat dat) frame)
     ((var? pat) (extend-if-consistent pat dat frame))
     ((and (pair? pat) (pair? dat))
      (pattern-match (cdr pat)
		     (cdr dat)
		     (pattern-match (car pat)
				    (car dat)
				    frame)))
     (else 'failed)))
  (define (unify-match p1 p2 frame)
    (define (extend-if-possible var val frame)
      (define (depends-on? exp var frame)
	(define (tree-walk e)
	  (cond ((var? e)
		 (if (equal? var e)
		     #t
		     (let ((b (binding-in-frame e frame)))
		       (if b
			   (tree-walk (binding-value b))
			   #f))))
		((pair? e)
		 (or (tree-walk (car e))
		     (tree-walk (cdr e))))
		(else #f)))
	(tree-walk exp))
      (let ((binding (binding-in-frame var frame)))
	(cond
	 (binding
	  (unify-match
	   (binding-value binding) val frame))
	 ((var? val)
	  (let ((binding (binding-in-frame val frame)))
	    (if binding
		(unify-match
		 var (binding-value binding) frame)
		(extend var val frame))))
	 ((depends-on? val var frame)
	  'failed)
	 (else (extend var val frame)))))
    (cond
     ((eq? frame 'failed) 'failed)
     ((equal? p1 p2) frame)
     ((var? p1) (extend-if-possible p1 p2 frame))
     ((var? p2) (exetnd-if possible p2 p1 frame)) ;symmetric p-match
     ((and (pair? p1) (pair? p2))
      (unify-match (cdr p1)
		   (cdr p2)
		   (unify-match (car p1)
				(car p2)
				frame)))))

  
  (define (simple-query query-pattern frame-stream)
    (define (find-assertions pattern frame)
      (define (check-an-assertion assertion query-pat query-frame)
	(let ((match-result
	       (pattern-match query-pat assertion query-frame)))
	  (if (eq? match-result 'failed)
	      the-empty-stream
	      (singleton-stream match-result))))
      (stream-flatmap (lambda (datum)
			(check-an-assertion datum pattern frame))
		      (fetch-assertions pattern frame)))
    (define (apply-rules pattern frame)
      (define (apply-a-rule rule query-pattern query-frame)
	(define (rename-variables-in rule)
	  (let ((rule-application-id (new-rule-application-id)))
	    (define (tree-walk exp)
	      (cond
	       ((var? exp) (make-new-variable exp rule-application-id))
	       ((pair? exp)
		(cons (tree-walk (car exp))
		      (tree-walk (cdr exp))))
	       (else exp)))
	    (tree-walk rule)))
	(let ((clean-rule (rename-variables-in rule)))
	  (let ((unify-result
		 (unify-match query-pattern
			      (conclusion clean-rule)
			      query-frame)))
	    (if (eq? unify-result 'failed)
		the-empty-stream
		(qeval (rule-body clean-rule)
		       (singleton-stream unify-result))))))
      (stream-flatmap (lambda (rule)
			(apply-a-rule rule pattern frame))
		      (fetch-rules pattern frame)))
    (stream-flatmap
     (lambda (frame)
       (stream-append-delayed
	(find-assertions query-pattern frame)
	(delay (apply-rules query-pattern frame))))
     frame-stream))
  (define (qeval query frame-stream)
    (let ((qproc (get (type query) 'qeval)))
      (if qproc
	  (qproc (contents query) frame-stream)
	  (simple-query query frame-stream))))
  (define (instantiate exp frame unbound-var-handler)
    (define (copy exp)
      (cond
       ((var? exp)
	(let ((binding (binding-in-frame exp frame)))
	  (if binding
	      (copy (binding-value binding))
	      (unbound-var-handler exp frame))))
       ((pair? exp)
	(cons (copy (car exp)) (copy (cdr exp))))
       (else exp)))
    (copy exp))
  (define input-prompt ";;; Query input:")
  (define output-prompt ";;; Query results:")
  (define (prompt-for-input msg)
    (newline)
    (newline)
    (display msg))
  (define (query-driver-loop)
    (prompt-for-input input-prompt)
    (let ((q (query-syntax-process (read))))
      (cond
       ((assertion-to-be-added? q)
	(add-rule-or-assertion! (add-assertion-body q))
	(newline)
	(display "Assertion added to data base")
	(query-driver-loop))
       (else
	(newline)
	(display output-prompt)
	(display-stream
	 (stream-map
	  (lambda (frame)
	    (instantiate
	     q
	     frame
	     (lambda (v f)
	       (contract-question-mark v))))
	  (qeval q (singleton-stream '())))
	 -1)
	(query-driver-loop)))))
  (put 'and 'qeval conjoin)
  (put 'or 'qeval disjoin)
  (put 'not 'qeval negate)
  (put 'lisp-value 'qeval lisp-value)
  (put 'always-true 'qeval always-true)
  (query-driver-loop))


(Query)

(assert! (address (Hacker Alyssa P) (Cambridge (Mass Ave) 78)))
(assert! (job (Hacker Alyssa P) (computer programmer)))
(assert! (salary (Hacker Alyssa P) 40000))
(assert! (supervisor (Hacker Alyssa P) (Bitdiddle Ben)))
(assert! (address (Fect Cy D) (Cambridge (Ames Street) 3)))
(assert! (job (Fect Cy D) (computer programmer)))
(assert! (salary (Fect Cy D) 35000))
(assert! (supervisor (Fect Cy D) (Bitdiddle Ben)))
(assert! (address (Tweakit Lem E) (Boston (Bay State Road) 22)))
(assert! (job (Tweakit Lem E) (computer technician)))
(assert! (salary (Tweakit Lem E) 25000))
(assert! (supervisor (Tweakit Lem E) (Bitdiddle Ben)))
(assert! (address (Bitdiddle Ben) (Slumerville (Ridge Road) 10)))
(assert! (job (Bitdiddle Ben) (computer wizard)))
(assert! (salary (Bitdiddle Ben) 60000))
(assert! (address (Reasoner Louis) (Slumerville (Pine Tree Road) 80)))
(assert! (job (Reasoner Louis) (computer programmer trainee)))
(assert! (salary (Reasoner Louis) 30000))
(assert! (supervisor (Reasoner Louis) (Hacker Alyssa P)))
(assert! (supervisor (Bitdiddle Ben) (Warbucks Oliver)))
(assert! (address (Warbucks Oliver) (Swellesley (Top Heap Road))))
(assert! (job (Warbucks Oliver) (administration big wheel)))
(assert! (salary (Warbucks Oliver) 150000))
(assert! (address (Scrooge Eben) (Weston (Shady Lane) 10)))
(assert! (job (Scrooge Eben) (accounting chief accountant)))
(assert! (salary (Scrooge Eben) 75000))
(assert! (supervisor (Scrooge Eben) (Warbucks Oliver)))
(assert! (address (Cratchet Robert) (Allston (N Harvard Street) 16)))
(assert! (job (Cratchet Robert) (accounting scrivener)))
(assert! (salary (Cratchet Robert) 18000))
(assert! (supervisor (Cratchet Robert) (Scrooge Eben)))
(assert! (address (Aull DeWitt) (Slumerville (Onion Square) 5)))
(assert! (job (Aull DeWitt) (administration secretary)))
(assert! (salary (Aull DeWitt) 25000))
(assert! (supervisor (Aull DeWitt) (Warbucks Oliver)))


(assert! (rule (wheel ?person)
	       (and (supervisor ?middle-manager ?person)
		    (supervisor ?x ?middle-manager))))
(wheel ?x)
(assert! (rule (richman ?x1)
	       (and (salary ?x1 ?v1)
		    (not (and
			  (salary ?x2 ?v2)
			  (lisp-value < ?v1 ?v2))))))
(assert! (rule (poorman ?x1)
	       (and (salary ?x1 ?v1)
		    (not (and
			  (salary ?x2 ?v2)
			  (lisp-value > ?v1 ?v2))))))
