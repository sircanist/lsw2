(in-package :logic)

;; The general problem is the following: Given a set of FOL formulas, and a partial model in the form of a logic kb -
;; positive ground assertions - what set of rules will generate the maximal number of sound entailments.  This is, in
;; general, a hard problem. It's utility is maintenance of a model for a theory (BFO now), where it starts to get
;; onerous to manually compute all the necessary inferences. Instead we enter a minimal number of assertions from which
;; the rest of the positive assertions are inferred, and this is turned into an interpretation to test.

;; The strategy here is to generate some sound rules and some potentially unsound rules. A rule is an implication with
;; the antecedent a conjunction of positives and the consequent is also a positive.  The potentially unsound rules are
;; checked by seeing if they can be proved from the whole set. The rule set, as a whole is then used to forward chain
;; and generate more assertions for the model. 

;; The overall flow is: Remove quantifiers, compute disjunctive normal form, using heuristics discard some DNFs as
;; unsuitable, keeping those that are rule-like - having a single positive only clause and several negative only
;; clauses.  The sound rules are generated from those cases in which there is a single clause with a single positive
;; assertion and a number of clauses each with a single negative assertion.
;; 
;; ((foo ?x))
;; ((not (bar ?x)))
;; ((not (baz ?x)))
;;->
;; (bar ?x) and (baz ?x) => (foo  ?x)

;; However we will also look at cases where there are multiple positives - in some cases this can generate a number of
;; rules, one for each head (all are concluded if the antecedents hold). We also look at cases where there might be more
;; than one negatives in the negative clauses. In such case it can be the case that these can also be split (either one
;; or the other works as antecedent).

;; The generation phase is where the DNF is taken, various heuristics are applied, and potential rules are generated. In
;; the course of generation there may be duplicate rules created - we drop those here.

;; Finally, potentially unsound rules are tested with a theorem prover. It is often the case that an a generated rule
;; can't be proved from the formula from which it was generated, but *can* be proved from the theory as a whole.

;; Because I wasn't (and am still not) sure what the best strategy is, the various strategies I explored are enumerated
;; and which are used are controllable. 

;; Strategies for removing quantifiers
;; Q1 rewrite exist to not all not, resulting in a formula with only universals
;; Q2 universally quantified skolems, for existentials generate skolem "constants" which are actually variables in the
;; rules. The motivation here is that a rule invocation in which a skolem matches demonstrates the existence of
;; variable, and so can be sound.

;; Filtering DNF
;; D1 discard if any clause has both a positive and negative literal
;; D2 discard if there is any skolem in the head

;; Methods for constructing rule
;; R1 when the DNF has 1 all positive literal, rest all negative literals - create a rule for using each alternative of a negative and each alternative of a positive (cross)
;; R2 when DNF has 1 single positive literal, rest all negative literal - special case of R1 
;; R3 DNF with 1 single positive literal all single negative literals - this is a horn rule and it is sound to convert
;; this so that antecdents are the conjunction of the negated clauses and the consequent is the positive literal.
;; R4 DNF with 1 all positive clause (multiple elements) with rest all single negative literals - special case of R1


;; Methods for filtering generated rules 
;; E1 (for Q2), remove any generated rule with skolem in head. (may miss rule)
;; E2 remove rules where not all variables in head are bound in clauses (always unsound, since will generate nil for the not-bound variable)
;; E3 try to prove rule from theory (can determine sound) 
;; E4 If the head and set of clauses match another generated rule, discard it.

;; Other heuristics
;; H1 If the formula has an iff not surrounded by an existential, use rules from each direction of implication   a<->b ->  a->b and b->a (sound)

;; Defaults: E2, D1, H1 Most conservative is R3 Q1 seems to generate fewer combinations from the DNF Use of R1,R2,R4
;; land up being a trade off between generating (and possibly finding more valid rules) and taking more time to run the
;; proofs.

;; Implementation:
;; (generate-rules (&key alternatives-strategy dnf-filters quantifier-strategy check-with-reasoner theory check )

;; alternatives-strategy is one or more of 
;; :head-variables-bound no free variables in the head [default]
;; :no-skolem-head don't use if there's a skolem in a head - might be ok if bound. more permissive than :no-skolem-head dnf-filter

;; dnf-filters is one or more of
;;  :no-mixed - only pure positive and pure negative clauses  [default]
:;  :no-skolem-head - don't use if there's a skolem in any positive - might be ok if bound. 
;;  :only-one-positive - only one set of positives. 
;;  :single-negative - only one positive in the positive set. If not a separate rule is made for each positive.
;;  :single-negative - only one negative in each negative set. If not, use all possible combinations of negatives

;; quantifier strategy is one of
;;   :replace-existentials - exists -> not forall not
;;   :keep-skolems - existentials are converted to variables

;; check-with-reasoner if nil not check is made. If t then reaser is used with default timeout. If numeric timeout in seconds.

;; theory is a theory spec, used for the proofs
;; check is a spec of which formula you want to generate for, typically ised for testing.


;; https://www.inf.unibz.it/~artale/DML/Lectures/Logic/slides2-prop-logic-1.pdf
;;
;; DNF tells us something as to whether a formula is satisfiable. If all disjuncts
;; contain bottom or complementary literals, then no model exists. Otherwise, the
;; formula is satisfiable.



;; rewrite formula so that nested quantifed variables don't share names e.g. 
;; (forall (?x) .. (forall (?x) ... becomes (forall (?x) .. (forall (?x1) ...
(defun rewrite-standardizing-apart (form &aux used)
  (labels ((doit (form bound)
	     (flet ((replacement (var)
		      (loop for i from 1
			    for potential = (intern (format nil "~a~a" (string var) i))
			    when (and (not (tree-find potential form))
				      (not (member potential used))
				      (not (find potential bound :key 'second)))
			      return  potential)))
	       (cond ((and (and (consp form) (member (car form) '(:forall :exists)))
			   (> (length (second form)) 1))
		      ;; nested, recurse
		      (doit `(,(car form) (,(car (second form))) 
			      (,(car form) (,@(cdr (second form)))
			       ,(third form))) bound ))
		     ((and (consp form) (member (car form) '(:forall :exists) ))
		      (if  (member (car (second form)) used)
			   (let ((replacement (replacement (car (second form)))))
			     (push replacement used)
			     `(,(car form) (,replacement) 
			       ,(doit (third form) (cons (list (car (second form)) replacement) bound) )))
			   (progn
			     (push (car (second form)) used)
			     `(,(car form) ,(second form)
			       ,(doit (third form) (cons (list (car (second form)) (car (second form))) bound) )))))
		     ((logic-var-p form)
		      (or (second (assoc form bound)) form))
		     ((atom form) form)
		     ((consp form) (mapcar (lambda (e) (doit e bound )) form))
		     (t (error "wtf"))))))
    (doit form nil)))

;; Rewrite so that (exists (?x) (f x)) -> (f ?skx) 
(defun convert-existentials-to-skolem-variables (form)
  (let ((counter 0))
    (labels ((inner (form)
	       (tree-replace
		(lambda(e)
		  (if (and (consp e) (eq (car e) :exists))
		      (let ((vars (second e)))
			(loop with body = (inner (third e))
			      for var in vars
			      do (setq body (subst (intern (format nil "?SK~a" (incf counter)) :keyword) var body))
			      finally (return body)))
		      e))
		form)))
      (inner form))))

(defun skolem-var-p (sym)
  (and (symbolp sym)
       (keywordp sym)
       (#"matches" (string sym) "\\?SK\\d+")))

;; Remove all wrapping quantifiers. Valid only when there are only universal quantifiers.
(defun strip-quantifiers (form)
  (cond ((atom  form) form)
	((member (car form) '(:forall forall ))
	 (strip-quantifiers (third form)))
	(t (mapcar 'strip-quantifiers form))))
    
;; Takes in a list of n negated clauses and generates combinations of n single-form clauses with each combination.
;; e.g. (((not (f x)) (not (g y))) ((not (q r))))
;; ->   (((not (f x)) (not (q r)))  
;;       ((not (g y)) (not (q r))) 
(defun all-clause-combinations (lists &optional head)
  (if (null lists) 
      (list head)
      (mapcan (lambda(el) (all-clause-combinations (rest lists) (append head (list (second el))))) (car lists))))

;; Checks that every variable (symbol starting with '?') in head is present in body.
(defun head-variables-bound (head body)
  (every (lambda(e) (tree-find e body)) 
	 (remove-if-not 'logic-var-p head)))


(defun dnf (form)
  (ginsberg-cnf-dnf:dnf
   (tree-replace
    (lambda(e) (or (second (assoc e '((:implies if) (:and and) (:or or) (:not not) (:iff <=>) ))) e))
    form)))
	    
;; If the form has an iff surrounded only by universally quantified variables, split into two implications one for each
;; direction.
;; e.g. (:forall (?x) (:iff (f ?x) (g ?x))) -> (:forall (?x) (:implies (f ?x) (g ?x))), (:forall (?x) (:implies (g ?x) (f ?x)))
;; Note that we use the symbols => and <= here, instead of the usual, since we will be passing to the DNF generator
;; which understands those. So really: (:forall (?x) (=> (f ?x) (g ?x))), (:forall (?x) (<= (f ?x) (g ?x)))
(defun maybe-split-top-iff (formula)
  (let ((done nil))
    (let ((replaced (tree-replace (lambda(e) 
				    (if done
					e
					(progn
					  (if (and (consp e) (eq (car e) :exists))
					      (progn (setq done :exists) e)
					      (if (eq e :iff) (progn (setq done :iff) '|<=| ) e)))))
				  formula)))
      (if (eq done :iff) (list replaced (subst '=> '<= replaced))
	  (list formula)))))
    
;; Strategy is either :keep-skolems, or :replace-existentials. Resulting formula has no quantifiers, but does have free
;; variables.
(defun remove-quantifiers (strategy formula)
  (ecase strategy
    (:keep-skolems 
     (strip-quantifiers
      (convert-existentials-to-skolem-variables
       (rewrite-standardizing-apart
	formula))))
    (:replace-existentials
     (strip-quantifiers
      (tree-replace (lambda(e)
		      (if (and (consp e) (eq (car e) :exists))
			  `(:not (:forall ,(second e) (:not ,(third e))))
			  e))  
		    (rewrite-standardizing-apart
		     formula))))))

;; strategies is a list of any number of :no-mixed, :no-skolem-head, :only-one-positive, :single-negative, :single-negative
;; dnf is the disjunctive normal form
(defun filter-dnf (strategies dnf)
  (let ((positives nil)
	(negatives nil)
	(mixed nil))
    (loop for clause in dnf
	  if (not (find 'not clause :key 'car)) 
	    do (push clause positives)
	  else
	    if (every (lambda(e) (eq (car e) 'not)) clause)
	      do (push clause negatives)
	  else do (push clause mixed))
    (if (or (and (member :no-mixed strategies) mixed)
	    (and (member :only-one-positive strategies) (not (= (length positives) 1)))
	    (and (member :single-positive strategies)
		 (some (lambda(e) (not (= (length e) 1))) positives))
	    (and (member :single-negative strategies)
		 (some (lambda(e) (not (= (length e) 1))) negatives))
	    (and (member :no-skolem-head strategies)
		 (some (lambda(e) (some (lambda(e) (find-if 'skolem-var-p e )) e)) positives)))
	nil
	dnf)))

;; filters is a list with either or both of :head-variables-bound, :no-skolem-head 
;; dnf is the disjunctive normal form
;; label is a symbol used to identifiy the resultant rule
;; Result is a list of lists each: (label head &rest body)
;; head and body are positives
(defun generate-alternatives (filters dnf label)
  (let ((positives nil)
	(negatives nil)
	(mixed nil)
	(seen (make-hash-table :test 'equalp)))
    (loop for clause in dnf
	  if (not (find 'not clause :key 'car)) 
	    do (push clause positives)
	  else
	    if (every (lambda(e) (eq (car e) 'not)) clause)
	      do (push clause negatives)
	  else do (push clause mixed))
    (progn(loop for clause in positives
		do
		   (loop for head in clause
			 unless (and (member :no-skolem-head filters)
				     (find-if 'skolem-var-p head))
			   do
			      (loop for clauses in (all-clause-combinations negatives)
				    for sig = (cons (princ-to-string head) (sort (remove-duplicates
						     (mapcar 'princ-to-string  clauses)
						     :test 'equalp)
						    'string-lessp))
				    unless (and (member :head-variables-bound filters)
						(not (head-variables-bound head clauses)))
				      unless (gethash  sig seen)
					do (setf (gethash sig seen) (list* label head (remove-duplicates clauses :test 'equalp))))))
	  (alexandria::hash-table-values seen))))  



;; alternatives-strategy, a valid list for generate-alternatives
;; dnf-strategy, a valid filter list for filter-dnf
;; quantifier-strategy, a valid stategy to remove-quantifiers
;; check-with-reasoner if nil not check is made. If t then reaser is used with default timeout. If numeric timeout in seconds.
;; theory is a theory spec, used for the proofs
;; check is a spec of which formula you want to generate for, typically ised for testing.
;;
;; Note: Rules that have an equality as head are ignored
;; 
;; Output is a list of (label (:implies (:and (f ?x ...) ...) (g ?x ..)))

(defun generate-rules (&key (alternatives-strategy '(:head-variables-bound))
		  	    (quantifier-strategy :keep-skolems)
			    (dnf-filters '(:no-mixed))
			    check-with-reasoner theory check)
  (let ((candidates
	  (loop for ax in (collect-axioms-from-spec check)
		append 
		(loop for maybe-split in (maybe-split-top-iff  (axiom-sexp ax))
		      append
		      (loop for (label . alt)
			      in 
			      (generate-alternatives 
			       alternatives-strategy 
			       (filter-dnf dnf-filters
					   (dnf (remove-quantifiers quantifier-strategy maybe-split)))
			       (axiom-name ax))
			    for candidate =  `(:implies  (:and ,@(cdr alt)) ,(car alt))
			    for vars = (fourth (multiple-value-list (formula-elements candidate)))
			    when (and (car  alt) (cdr alt) ;; make sure there's both a head and clause 
				      (not (equal (caar alt) :=)) ;; don't include rules generating equality
				      (not (member  (car alt) (cdr alt) :test 'equalp))) ;; remove tautologies (head is one of clauses)
			      collect  (list label `(:forall ,vars ,candidate)))))))
    (if (not check-with-reasoner)
	(mapcar (lambda(e) (list (car e) (third (second e)))) candidates)
	(lparallel::pmapcan (lambda(rule)
			      (if (eq :proved (z3-prove theory (second rule) :timeout (if (numberp check-with-reasoner) check-with-reasoner 2)))
				  (list (list (first rule) (third (second rule))))))
			    candidates))))

;; Currently using the old code from winston ai, but might switch to prolog.
;; Those rules use the syntax (? v) for my ?v
;; This function rewrites the latter to the former
(defun rewrite-variables-for-forward-chainer (form)
  (substitute '= := (tree-replace (lambda(e) 
				    (if (and (symbolp e) (eq (char (string e) 0) #\?) )
					`(? ,(intern (subseq (string e) 1)))
					e))
				  form)))

;; Forward chain the rules starting with assertions and return the resultant list of asserted and inferred propositions
(defun forward-chain-rules (rules assertions) 
  (setq *rules* (make-empty-stream) 
	*assertions* (make-empty-stream))  
  (loop for ass in assertions
	do (remember-assertion ass))
  ;; some of our rules have equality in the antecedents - add an explicit (= x x ) for every ground symbol in the assertions.
  (loop for const in (second (multiple-value-list (formula-elements `(:and ,assertions))))
	do
	   (remember-assertion  `(= ,const ,const)))
  ;; reformat the rules so that Winston's code likes it. The format is: (label antecedent antecedent .. consequent)
  (loop for (label (nil (nil . ants) cons)) in rules
	do (remember-rule `(,label ,@(mapcar 'rewrite-variables-for-forward-chainer ants) ,(rewrite-variables-for-forward-chainer cons))))
  (forward-chain)
  (loop for el = *assertions* then (funcall (second el))
	until (symbolp el)
	unless (eq (caar el) '=)
	  collect (car el)))

;; Report a comparison of an inferred kb compared to a reference.
;; reference is a list of propositions
;; base is a list of propositions that were the basis for forward chaining
;; kb are the base + inferred proposition
;; Report lists	inferred propositions not in reference separated by "---"
;; then reference propositions not in kb
;; then list with number of base propositions, total number of propositions in kb, number of props in inferred but not reference,
;; number in reference but not inferred

(defun check-rules-run (kb reference base rules)
  (declare (ignore rules))
  (let ((props kb)
	(everything reference)
	(good 0)
	(bad 0)
	)
    ;; Report props in kb but not reference, but skip the equality assertions we added
    (loop for prop in (remove '= props :key 'car)
	  if (not (member prop everything :test 'equalp))
	    do (incf bad)
	    and collect prop into bad-ones
	  else do (incf good)
	  finally
    	     (map nil 'print (sort bad-ones 'string-lessp :key 'princ-to-string)))

    (print "---")
    
    (loop for prop in everything
	  if (not (member prop props :test 'equalp))
	    sum 1 into missing and collect prop into missing-ones
	  finally 
	     (map nil 'print (sort missing-ones 'string-lessp :key 'princ-to-string))
	     (return (list (length base) good bad missing)))
    ))
