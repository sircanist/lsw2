(in-package :logic)

(defvar *snark-symbols* nil)
(defvar *snark-symbols-logical* nil)
;; make it so snark is only lazy-loaded if you make one of these.

(defun ensure-snark-tables ()
  (unless *snark-symbols*
    (setq *snark-symbols* (make-hash-table))
    (setq *snark-symbols-logical* (make-hash-table))
      (loop for term in '("FORALL" "EXISTS" "IMPLIES" "AND" "OR" "IFF" "NOT" "=")
	do 
	   (setf (gethash (intern term 'keyword) *snark-symbols*) (intern term 'snark-user))
	   (setf (gethash (intern term 'snark-user) *snark-symbols-logical*)
		 (intern (concatenate 'string "L-" term) 'logic))
	   (setf (gethash (intern (concatenate 'string "L-" term) 'logic) *snark-symbols-logical*)
		 (intern (concatenate 'string "L-" term) 'logic)))
      ))
  
(defclass snark-logic-generator (logic-generator) ())

(defmethod initialize-instance  ((i snark-logic-generator) &rest initargs)
  (require 'snark)
  (ensure-snark-tables)
  (call-next-method))

(defun ss (sym)
  (gethash sym *snark-symbols*))
    
(defmethod logical-forall ((g snark-logic-generator) vars expressions) `(,(ss :forall) ,vars ,@expressions))
(defmethod logical-exists ((g snark-logic-generator) vars expressions) `(,(ss :exists) ,vars ,@expressions))
(defmethod logical-implies ((g snark-logic-generator) antecedent consequent) `(,(ss :implies) ,antecedent ,consequent))
(defmethod logical-and ((g snark-logic-generator) expressions) `(,(ss :and) ,@expressions))
(defmethod logical-or ((g snark-logic-generator) expressions) `(,(ss :or) ,@expressions))
(defmethod logical-iff ((g snark-logic-generator) antecedent consequent) `(,(ss :iff) ,antecedent ,consequent))
(defmethod logical-not ((g snark-logic-generator) expression) `(,(ss :not) ,expression))
(defmethod logical-= ((g snark-logic-generator) a b) `(,(ss :=) ,a ,b))
(defmethod logical-holds ((g snark-logic-generator) &rest args) `(holds ,@args))
(defmethod logical-fact ((g snark-logic-generator) fact) `(quote ,fact))

(defmethod generate-from-snark ((generator logic-generator) expression)
  (ensure-snark-tables)
  (labels ((rewrite (expression)
	     (cond ((and (consp expression) (gethash (car expression) *snark-symbols-logical*))
		    `(,(gethash (car expression) *snark-symbols-logical*)
		      ,@(mapcar (lambda(e) 
				  (if (and (consp e) (gethash (car e) *snark-symbols-logical*))
				      e
				      `(quote ,e)))
				(mapcar #'rewrite (cdr expression)))))
		   (t expression))))
    (let ((*logic-generator* generator)) (eval (rewrite expression)))))

  
