(in-package :logic)

(defclass latex-logic-generator (logic-generator) 
  ((formula-format :accessor formula-format :initarg :formula-format :initform "~a:~%~a")
   (insert-line-breaks :accessor insert-line-breaks :initarg :insert-line-breaks :initform nil)))

(defmethod normalize-names ((g latex-logic-generator) e)
  (cond ((and (symbolp e) (char= (char (string e) 0) #\?))
	 (cl-user::camelCase (subseq (string e) 1) nil))
	((symbolp e) (cl-user::camelCase (string e) nil))
	((and (stringp e) (or (find #\( e :test 'char=) (find #\= e :test 'char=) (find #\\ e :test 'char=))) e) ;; already done
	((stringp e) (cl-user::camelCase e nil))
	((cl-user::uri-p e) (cl-user::camelCase (if (and (boundp 'cl-user::*default-kb*) cl-user::*default-kb*)
						    (cl-user::uri-label e)
						    (#"replaceAll" (cl-user::uri-full e) ".*/" "")) nil) )
	((atom e) e)
	(t (mapcar (lambda(e) (normalize-names g e)) e))))

(defmethod latex-expression ((g latex-logic-generator) expression)
  (if (null expression) (break))
  (if (consp expression)
      (format nil "~a(~{~a~^,~})" (normalize-names g (car expression)) (normalize-names g (cdr expression)))
      (normalize-names g expression))
  )

(defmethod maybe-line-break ((g latex-logic-generator))
  (if (insert-line-breaks g) #\newline ""))
  
(defmethod latex-quantifier-vars ((g latex-logic-generator) vars)
  (normalize-names g vars))

(defmethod logical-forall ((g latex-logic-generator) vars expressions)
  (format nil "~{\\forall ~a\\, ~} ~{~a~}"  (latex-quantifier-vars g vars)
	  (mapcar (lambda(e)(latex-expression g e)) expressions)))

(defmethod logical-exists ((g latex-logic-generator) vars expressions)
  (format nil "~{\\exists ~a\\, ~} ~{~a~}"  (latex-quantifier-vars g vars)
	  (mapcar (lambda(e)(latex-expression g e)) expressions)))

(defmethod logical-implies ((g latex-logic-generator) antecedent consequent)
  (format nil "~a ~a\\rightarrow ~a" (latex-expression g antecedent) (maybe-line-break g) (latex-expression g consequent)))

(defmethod logical-and ((g latex-logic-generator) expressions)
  (let ((format-string (if (eql (maybe-line-break g) #\newline)
			   "~{~a ~^~%\\land ~}"
			   "~{~a ~^\\land ~}")))
    (format nil format-string  (mapcar (lambda(e) (latex-expression g e)) expressions))))

(defmethod logical-or ((g latex-logic-generator) expressions) 
  (format nil "~{~a ~^\\lor ~}"  (mapcar (lambda(e) (latex-expression g e)) expressions)))

(defmethod logical-iff ((g latex-logic-generator) antecedent consequent)
  (format nil "~a ~a\\leftrightarrow ~a" (latex-expression g antecedent) (maybe-line-break g) (latex-expression g consequent)))

(defmethod logical-not ((g latex-logic-generator) expression)
  (format nil "\\neg ~a" (latex-expression g expression)))

(defmethod logical-= ((g latex-logic-generator) a b)
  (format nil "~a = ~a" (latex-expression g a) (latex-expression g b)))

(defmethod logical-holds ((g latex-logic-generator) &rest args) 
  (latex-expression g `(holds ,@args)))

(defmethod logical-fact ((g latex-logic-generator) fact)
  (latex-expression g fact))

(defmethod logical-parens ((g latex-logic-generator) expression)
  (format nil "~a(~a)" (maybe-line-break g) (latex-expression g expression)))

;; ugh this got ugly handling bug  (:not (:exists (?a ?b) ..)) should -> (:not (:exists (?a) (:not (:exists (?b) ...

(defmethod make-explicit-parentheses ((g latex-logic-generator) e &optional parent propagate-negation)
  (cond ((symbolp e) e)
	((not (keywordp (car e))) e)
	((and (member (car e) '(:forall :exists))
	      (> (length (second e)) 1)
	      (make-explicit-parentheses g `(,(car e) (,(car (second e)))
					     ,(if propagate-negation
						  `(:not (,(car e) ,(rest (second e)) ,@(cddr e)))
						  `(,(car e) ,(rest (second e)) ,@(cddr e))))
					 (car e) propagate-negation)
					 ))
	((member (car e) '(:forall :exists))
	 (if (and (keywordp (car (third e)))  (not (eq (car e) parent)))
	     `(,(car e) ,(second e) (:parens ,(make-explicit-parentheses g  (third e) parent nil)))
	     `(,(car e) ,(second e) ,(make-explicit-parentheses g  (third e) parent nil))))
	((keywordp (car e))
	 (let ((form `(,(car e)
		       ,@(mapcar (lambda(e2) 
				   (if (and (consp e2) (keywordp (car e2)))
				       (if (or #|(eq (car e) (car e2))|# (lower-precedence-p (car e) (car e2)))
					   (make-explicit-parentheses g e2 (if (eq (car e) :not) parent :not)  (eq (car e) :not))
					   `(:parens ,(make-explicit-parentheses g e2 (if (eq (car e) :not) parent :not) (or propagate-negation (eq (car e) :not)))))
				       (make-explicit-parentheses g e2 (if (eq (car e) :not) parent :not)  (or propagate-negation (eq (car e) :not)))))
				 (rest e)))))
	   (if (and (not (eq :not (car e))) (member parent '(:forall :exists))) `(:parens ,form) form)))
	(t e)))

;; https://en.wikipedia.org/wiki/Logical_connective#Order_of_precedence
(defun lower-precedence-p (a b)
  (> (position a '(:forall :exists :not :and :or :implies :iff :=))
     (position b '(:forall :exists :not :and :or  :implies :iff :=))))


(defmethod render-axiom ((g latex-logic-generator) (a axiom))
  (let ((*logic-generator* g))
    (format nil (formula-format g) (axiom-name a)
	    (eval (rewrite-to-axiom-generation-form (make-explicit-parentheses g (axiom-sexp a)))))))

(defmethod render-axioms ((generator latex-logic-generator) axs)
  (if (stringp axs)
      axs
      (format nil "~{~a~^~%~}" (mapcar (lambda(e) (render-axiom generator e)) axs))
      ))


;; even using breqn there is trouble with long parenthesized expressions
;; one strategy is that if there are more than 3 existentials, put them on a separate line with \\ and remove the surrounding parentheses.
;; might try the "." instead of parentheses for quantifiers

(defun axiom-sexp-length (sexp)
  (cond ((atom sexp) (length (string sexp)))
	((member (car sexp) '(:forall :exists :and :or :not :implies :iff))
	 (+ 2 (apply '+ (mapcar 'axiom-sexp-length (rest sexp)))))
	(t (+ (axiom-sexp-length (car sexp)) (apply '+ (mapcar 'axiom-sexp-length (rest sexp)))))))
	 
  