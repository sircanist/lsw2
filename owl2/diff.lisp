(in-package :cl-user)
(defun get-ontology-annotations (ont)
  (jss::j2list (#"getAnnotations" (v3kb-ont ont))))

(defun diff-ontologies (ont1 ont2)
  "Print out differences between ont1 and ont2, including ontology and version IRI, imports, ontology annotations, and axioms. Inputs can either be v3kbs, java ontology objects, uris or strings. In the latter 2 cases the ontologies will be loaded"
  (let ((table (make-hash-table :test 'equalp))
	(only-in-1 nil)
	(only-in-2 nil)
	(in-both nil)
	(ont1 (if (v3kb-p ont1) ont1 (load-ontology ont1)))
	(ont2 (if (v3kb-p ont2) ont2 (load-ontology ont2))))
    (loop for ax in (mapcar 'axiom-to-lisp-syntax (get-ontology-annotations ont1))
	  do (setf (gethash ax table) '(1)))
    (loop for ax in (mapcar 'axiom-to-lisp-syntax (get-ontology-annotations ont2))
	  do (push  2 (gethash ax table)))
    (each-axiom ont1
	(lambda(ax) (setf (gethash (axiom-to-lisp-syntax ax) table) '(1)))
      t)
    (each-axiom ont2
	(lambda(ax) (push 2 (gethash (axiom-to-lisp-syntax ax) table)))
      t)
    (maphash (lambda(k v)
	       (cond ((equal v '(1))
		      (push k only-in-1))
		     ((equal v '(2))
		      (push k only-in-2))
		     (t (push k in-both))))
	     table)
    (multiple-value-bind (annotations axioms) (partition-if (lambda(e) (eq (car e) 'annotation)) in-both)
      (format t "Common to both: ~a axioms and ~a ontology annotations~%" (length axioms) (length annotations)))
    (unless (eq (get-ontology-iri ont1) (get-ontology-iri ont2))
      (format t "~%Ontology IRIs differ: ~a, ~a~%" (get-ontology-iri ont1) (get-ontology-iri ont2)))
    (unless (eq (get-version-iri ont1) (get-version-iri ont2))
      (format t "~%Version IRIs differ: ~a, ~a~%" (get-version-iri ont1) (get-version-iri ont2)))
    (let ((imports1 (get-imports-declarations ont1))
	  (imports2 (get-imports-declarations ont2)))
      (unless (equalp imports1 imports2)
	(let ((only-in-1 (set-difference imports1 imports2 ))
	      (only-in-2 (set-difference imports2 imports1 )))
	  (when only-in-1
	    (format t "Imports only in first: ~{~a~^, ~}~%" only-in-1))
	  (when only-in-2
	    (format t "Imports only in second: ~{~a~^, ~}~%" only-in-2)))))
    (multiple-value-bind (annotations axioms) (partition-if (lambda(e) (eq (car e) 'annotation)) only-in-1)
      (when (or annotations axioms)
	(format t "~%Only in first~%")
	(when annotations
	  (let ((*default-kb* ont1))
	    (ppax annotations)))
	(when axioms
	  (let ((*default-kb* ont1))
	    (ppax axioms)))))
    (multiple-value-bind (annotations axioms) (partition-if (lambda(e) (eq (car e) 'annotation)) only-in-2)
      (when (or annotations axioms)
	(format t "~%~%Only in second~%")
	(when annotations
	  (let ((*default-kb* ont2))
	    (ppax annotations)))
	(when axioms
	  (let ((*default-kb* ont2))
	    (ppax axioms)))))))
