(defpackage :logic (:use cl))
(in-package :logic)

;(loop for s in '(l-forall l-exists l-and l-or l-iff l-equal l-implies logical-forall logical-exists logical-and logical-or logical-iff logical-equal logical-implies pred-property pred-class pred-property pred-class *use-holds* logic-generator logical-holds) do (shadowing-import s 'cl-user))
	      
(defclass logic-generator () ())

(defgeneric logical-forall ((g logic-generator) vars expressions))
(defgeneric logical-exists ((g logic-generator) vars expressions))
(defgeneric logical-implies ((g logic-generator) antecedent consequent))
(defgeneric logical-and ((g logic-generator) expressions))
(defgeneric logical-or ((g logic-generator) expressions))
(defgeneric logical-iff ((g logic-generator) antecedent consequent))
(defgeneric logical-not ((g logic-generator) expression))
(defgeneric logical-= ((g logic-generator) a b))
(defgeneric logical-holds ((g logic-generator) &rest args))
(defgeneric logical-class ((g logic-generator) class el))
(defgeneric logical-relation ((g logic-generator) head &rest args))
(defgeneric logical-fact ((g logic-generator) fact))

(defvar *use-holds* nil)

(defmethod logical-relation ((g logic-generator) head &rest args)
    (if *use-holds*
	(apply 'logical-holds g head args)
	`(,head ,@args)))

(defmethod logical-class ((g logic-generator) class el)
  (if *use-holds*
      (logical-holds g class el)
      `(,class ,el)))

(defmethod logical-forall ((g logic-generator) vars expressions) `(:forall ,vars ,@expressions))
(defmethod logical-exists ((g logic-generator) vars expressions) `(:exists ,vars ,@expressions))
(defmethod logical-implies ((g logic-generator) antecedent consequent) `(:implies ,antecedent ,consequent))
(defmethod logical-and ((g logic-generator) expressions) `(:and ,@expressions))
(defmethod logical-or ((g logic-generator) expressions) `(:or ,@expressions))
(defmethod logical-iff ((g logic-generator) antecedent consequent) `(:iff ,antecedent ,consequent))
(defmethod logical-not ((g logic-generator) expression) `(:not ,expression))
(defmethod logical-= ((g logic-generator) a b) `(:= ,a ,b))
(defmethod logical-holds ((g logic-generator) &rest args) `(:holds ,@args))
(defmethod logical-fact ((g logic-generator) fact) fact)

(defvar *logic-generator* (make-instance 'logic-generator))

(defparameter *logic-symbols* "PQRSUVWXYZABCDEFGHIJKLMNOT")

(defmacro with-logic-vars ((vars n &optional (from *logic-symbols* from-supplied-p)) &body body)
  `(let ((,vars (loop for i below  ,n
		      for base = (elt ,(if from-supplied-p 'from '*logic-symbols*) i)
		      collect (intern (concatenate 'string "?" (string base))
				      (if (symbolp base) (symbol-package base) *package*))
		      )))
     (let ((*logic-symbols* (if ,from-supplied-p *logic-symbols* (subseq *logic-symbols* ,n))))
       ,@body)))

(defmacro with-logic-var (var &body body)
  (let ((vars (gensym)))
    `(with-logic-vars (,vars 1)
       (let ((,var (car ,vars)))
	 ,@body))))

(defun pred-property (head &rest args)
  (apply 'logical-relation *logic-generator* head args))

(defun pred-class (class arg)
  (logical-class *logic-generator*  class arg))

(defun l-forall (vars &rest expressions)
  (logical-forall *logic-generator* vars expressions))

(defun l-exists (vars &rest expressions)
  (logical-exists *logic-generator* vars expressions))

(defun l-implies (antecedent consequent)
  (logical-implies *logic-generator* antecedent consequent))

(defun l-and (&rest expressions)
  (logical-and *logic-generator* expressions))

(defun l-or (&rest expressions)
  (logical-or *logic-generator* expressions))

(defun l-iff (antecedent consequent)
  (logical-iff *logic-generator* antecedent consequent))

(defun l-not (expression)
  (logical-not *logic-generator* expression))

(defun l-= (a b)
  (logical-= *logic-generator* a b))

(defun l-fact (a)
  (logical-fact *logic-generator* a))

(defun formula-sexp-p (it)
  (and (consp it) (member (car it) '(:implies :forall :exists :and :or :iff :not := :fact :=))))

(defmethod predicates ((exp list))
  (let ((them nil))
    (labels ((walk (form)
	       (unless (atom form) 
		 (case (car form)
		   ((:forall :exists) (walk (third form)))
		   ((:implies :iff :and :or :not := :fact) (map nil #'walk (rest form)))
		   (otherwise 
		    (pushnew (list (intern (string (car form))) (1- (length form)))  them :test 'equalp)
		    (map nil #'walk (rest form)))))))
      (walk exp)
      them)))

(defmethod constants ((exp list))
  (let ((them nil))
    (labels ((walk (form)
	       (if (and (symbolp form) (not (char= (char (string form) 0) #\?))) 
		   (pushnew (intern (string form)) them)
		   (unless (atom form)
		     (case (car form)
		       ((:forall :exists) (walk (third form)))
		       ((:implies :iff :and :or :not :=) (map nil #'walk (rest form)))
		       (otherwise (map nil #'walk (rest form))))))))
      (walk exp)
      them)))

(defmethod render-axiom ((g logic-generator) (a axiom))
  (let ((*logic-generator* g))
    (eval (axiom-generation-form a))))

(defmethod render-axiom ((g logic-generator) (a list))
  (render-axiom g (make-instance 'axiom :sexp a)))

(defmethod render-axiom ((g logic-generator) (a string))
  a)

(defmethod render-axiom ((g symbol) (a string))
  (render-axiom (make-instance g) a))

(defmethod render-axioms ((g logic-generator b) axs)
  (if (stringp axs)
      axs
      (mapcar (lambda(e) (render-axiom g e)) axs)))

(defmethod render-axioms ((g symbol) axs)
  (render-axioms (make-instance g) axs))

(defun render (which assumptions &optional goals &key path at-beginning at-end)
  (let ((generator-class
	  (ecase which
	    (:z3 'z3-logic-generator)
	    (:prover9 'prover9-logic-generator))))
    (flet ((doit ()
	     (concatenate
	      'string
	      (or (and at-beginning (format nil "~a~%" at-beginning)) "")
	      (render-axioms generator-class
			     (append (if (stringp assumptions) assumptions
					 (collect-axioms-from-spec assumptions))
				     (if (stringp goals) goals
					 (mapcar (lambda(e) (negate-axiom e)) (collect-axioms-from-spec goals)))))
	      (or (and at-end (format nil "~a~%" at-end))  ""))))
      (if path
	(with-open-file (f path :direction :output :if-does-not-exist :create :if-exists :supersede)
	  (progn (write-string (doit) f) (truename path)))
	(doit)))))