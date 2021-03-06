(in-package :logic)

(defclass z3-logic-generator (logic-generator)
  ((with-declarations :accessor with-declarations :initarg :with-declarations :initform t )
   (with-names :accessor with-names :initarg :with-names :initform t)
   (domain-sort :accessor domain-sort :initarg :domain-sort :initform '|Int|)))

(defmethod normalize-names ((g z3-logic-generator) e)
  (if (and (symbolp e) (digit-char-p (char (string e) 0)))
      (normalize-names g (format nil "~r~a" (parse-integer (string (char (string e) 0))) (subseq (string e) 1)))
      (flet ((replace-numbers (name)
	       (replace-all (string name) "(\\d+)" (lambda(e) (camelCase (format nil "~r" (read-from-string e)))) 1)))
	(cond ((and (symbolp e) (char= (char (string e) 0) #\?))
	       (normalize-names g (intern (subseq (string e) 1))))
;	      ((keywordp e) e)
	      ((and (symbolp e) (find #\- (string e)))
	       (intern (camelCase (replace-numbers e))))
	      ((uri-p e) (intern 
			  (camelCase
			   (if (and (boundp '*default-kb*) *default-kb*)
			       (uri-label e)
			       (#"replaceAll" (uri-full e) ".*/" "")))))
	      ((atom e) e)
	      (t (mapcar (lambda(e) (normalize-names g e)) e))))))

(defmethod z3-quantifier-vars ((g z3-logic-generator) vars)
  (normalize-names g vars))

(defmethod logical-relation ((g z3-logic-generator) head &rest args)
  (normalize-names g `(,head ,@args)))

(defmethod logical-forall ((g z3-logic-generator) vars expressions)
  `(forall ,(mapcar (lambda(e) `(,e ,(domain-sort g))) (z3-quantifier-vars g vars)) ,@expressions))

(defmethod logical-exists ((g z3-logic-generator) vars expressions)
  `(exists ,(mapcar (lambda(e) `(,e ,(domain-sort g))) (z3-quantifier-vars g vars)) ,@expressions))

(defmethod logical-implies ((g z3-logic-generator) antecedent consequent)
  `(=> ,antecedent ,consequent))

(defmethod logical-and ((g z3-logic-generator) expressions) 
  `(and ,@expressions))

(defmethod logical-or ((g z3-logic-generator) expressions) 
  `(or ,@expressions))

(defmethod logical-iff ((g z3-logic-generator) antecedent consequent)
  `(= ,antecedent  ,consequent))

(defmethod logical-not ((g z3-logic-generator) expression)
  `(not ,expression))

(defmethod logical-= ((g z3-logic-generator) a b)
  `(= ,a ,b))

(defmethod logical-holds ((g z3-logic-generator) &rest args) 
  `(holds ,@args))

(defmethod logical-fact ((g z3-logic-generator) fact)
   fact)

(defmethod logical-distinct ((g z3-logic-generator) &rest args)
  `(distinct ,@args))

(defmethod to-string  ((g z3-logic-generator) exp)
  (if (stringp exp) exp
      (let ((*print-case* nil))
	(format nil "~a~%"
		(replace-all
		 (format nil "~a" exp) "\\b([A-Z-0-9]+)\\b"
		 (lambda(e)
		   (if (some 'lower-case-p e)
		       e
		       (string-downcase e)))
		 1)))))

(defmethod builtin-predicate ((g z3-logic-generator) pred)
  (member pred '(declare-datatypes + - < > * = <= >= ^)))
  

(defmethod generate-declarations ((g z3-logic-generator) (a list) &key (include-constants t) (include-predicates t) (include-functions t))
  (multiple-value-bind (predicates constants functions variables)
      (formula-elements `(:and ,@(mapcar 'axiom-sexp a)))
    (apply 'concatenate 'string
	   (append
	    (and include-constants
		 (loop for c in constants
		       collect (to-string g `(declare-const ,(normalize-names g c) ,(domain-sort g)))))
	    (and include-functions
		 (loop for (f arity) in functions
		       collect (to-string g
					  `(declare-fun ,(normalize-names g f)
							,(loop repeat arity collect (domain-sort g)) ,(domain-sort g)))))
	    (and include-predicates
		 (loop for (p arity) in (remove-duplicates predicates :test 'equalp :key (lambda(e) (string(car e))))
		       collect (to-string g
					  `(declare-fun ,(normalize-names g p)
							,(loop repeat arity collect (domain-sort g)) |Bool|))))))))

  
(defmethod mangle-label ((g z3-logic-generator) label)
  (flet ((replace-angle (name)
	   (#"replaceAll" (#"replaceAll"  (string name) "<" ".lt.") ">" ".gt.")))
    (let ((new (replace-angle (replace-all (string label) "(\\d+)" (lambda(e) (camelCase (format nil ".~r" (read-from-string e)))) 1))))
      (pushnew (cons label new) (mangled-labels g) :test 'equalp)
      new
      )))
    
(defmethod render-axiom ((g z3-logic-generator) (a axiom))
  (let ((bare (call-next-method)))
    (if (with-declarations g)
	(concatenate 'string 
		     (generate-declarations g (list a))
		     (to-string g `(assert ,(normalize-names g bare))))
	(if (and (with-names g) (axiom-name a))
	    (to-string g `(assert (|!| ,(normalize-names g bare) |:named| ,(mangle-label g (axiom-name a)))))
	    (to-string g `(assert ,(normalize-names g bare)))))))

(defmethod render-axioms ((g z3-logic-generator) (a list))
  (apply 'concatenate 'string
	 (generate-declarations g a)
	 (mapcar 
	  (lambda(e) (to-string g e))
	  (let ((was (with-declarations g)))
	    (unwind-protect (progn 
			      (setf (with-declarations g) nil)
			      (mapcar (lambda(e) (render-axiom g e)) a))
	      (setf (with-declarations g) was))))))
		    
;all x all y all t(continuantOverlapAt(x,y,t) <-> (exists z(continuantPartOfAt(z,x,t) & continuantPartOfAt(z,y,t)))).

