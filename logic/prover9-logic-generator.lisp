(in-package :logic)

(defclass prover9-logic-generator (logic-generator) ())

(defun normalize-names (e)
  (cond ((and (symbolp e) (char= (char (string e) 0) #\?))
	 (cl-user::camelCase (subseq (string e) 1) t))
	((symbolp e) (cl-user::camelCase (string e) nil))
	((and (stringp e) (find #\( e :test 'char=)) e) ;; already done
	((stringp e) (cl-user::camelCase e nil))
	((cl-user::uri-p e) (cl-user::camelCase (if (and (boundp 'cl-user::*default-kb*) cl-user::*default-kb*)
						    (cl-user::uri-label e)
						    (#"replaceAll" (cl-user::uri-full e) ".*/" "")) nil) )
	((atom e) e)
	(t (mapcar 'normalize-names e))))

(defmethod prover-expression ((g prover9-logic-generator) expression)
  (if (consp expression)
      (format nil "~a(~{~a~^,~})" (normalize-names (car expression)) (normalize-names (cdr expression)))
      (normalize-names expression))
  )

(defmethod prover-quantifier-vars ((g prover9-logic-generator) vars)
  (normalize-names vars))

(defmethod logical-forall ((g prover9-logic-generator) vars expressions) 
  (format nil "~{~a ~} (~{~a~})"  (mapcar (lambda(e) (format nil "all ~a" e)) (prover-quantifier-vars g vars))
	  (mapcar (lambda(e)(prover-expression g e)) expressions)))

(defmethod logical-exists ((g prover9-logic-generator) vars expressions)
  (format nil "~{~a ~} (~{~a~})"  (mapcar (lambda(e) (format nil "exists ~a" e)) (prover-quantifier-vars g vars))
	  (mapcar (lambda(e)(prover-expression g e)) expressions)))

(defmethod logical-implies ((g prover9-logic-generator) antecedent consequent)
  (format nil "(~a) -> (~a)" (prover-expression g antecedent) (prover-expression g consequent)))

(defmethod logical-and ((g prover9-logic-generator) expressions) 
 (format nil "(~{~a~^ & ~})"  (mapcar (lambda(e) (prover-expression g e)) expressions)))

(defmethod logical-or ((g prover9-logic-generator) expressions) 
  (format nil "(~{~a~^ | ~})"  (mapcar (lambda(e) (prover-expression g e)) expressions)))

(defmethod logical-iff ((g prover9-logic-generator) antecedent consequent)
  (format nil "(~a) <-> (~a)" (prover-expression g antecedent) (prover-expression g consequent)))

(defmethod logical-not ((g prover9-logic-generator) expression)
  (format nil "-(~a)" (prover-expression g expression)))

(defmethod logical-= ((g prover9-logic-generator) a b)
  (format nil "(~a) = (~a)" (prover-expression g a) (prover-expression g b)))

(defmethod logical-holds ((g prover9-logic-generator) &rest args) 
  (prover-expression g `(holds ,@args)))

(defmethod logical-fact ((g prover9-logic-generator) fact)
  (prover-expression g fact))

(defmethod render ((g prover9-logic-generator) (a axiom))
  (concatenate 'string
	       (format nil "~{% ~a~%~}" (and (axiom-description a) (jss::split-at-char (axiom-description a) #\newline)))
	       (generate-from-sexp g (axiom-sexp a))
	       (format nil " # label(\"~a\") .~%" (axiom-name a))))

;all x all y all t(continuantOverlapAt(x,y,t) <-> (exists z(continuantPartOfAt(z,x,t) & continuantPartOfAt(z,y,t)))).

