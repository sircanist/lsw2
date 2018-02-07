(eval-when (:load-toplevel :execute :compile-toplevel)
  (loop for early in '("OWL-SEXP-TO-FOL" "URI-LABEL" "URI-FULL" "*RUNNING-IN-VAGRANT*" "*VAMPIRE-BOX-NAME*" "*VAMPIRE-EXECUTABLE*"
		       "*VAMPIRE-SHARED-DIRECTORY-REMOTE*" "*VAMPIRE-SHARED-DIRECTORY-LOCAL*" "CAMELCASE" "*DEFAULT-URI-BASE*"
		       "GET-VAGRANT-BOX-ID" "GET-VAGRANT-BOX-WD" "GET-VAGRANT-BOX-STATUS" "VAGRANT-BOX-UP") 
		      do (intern early :cl-user)))
(defpackage :logic
  (:use cl)
  (:import-from :cl-user cl-user::owl-sexp-to-fol cl-user::run-program-string->string
		cl-user::uri-full cl-user::uri-p cl-user::uri-label cl-user::*default-kb* cl-user::*default-uri-base*
		cl-user::camelcase cl-user::replace-all cl-user::make-uri  
		cl-user::get-vagrant-box-id cl-user::get-vagrant-box-status
		cl-user::get-vagrant-box-wd cl-user::vagrant-box-up
		cl-user::*vampire-shared-directory-remote* cl-user::*vampire-shared-directory-local*
		cl-user::*running-in-vagrant* cl-user::*vampire-box-name* cl-user::*vampire-executable* cl-user::print-db
		cl-user::tree-replace cl-user::tree-find cl-user::tree-walk cl-user::tree-remove-if
		)
  (:import-from :jss jss::all-matches)
  (:import-from :sys sys::run-program sys::process-output sys::process-input)
  (:import-from :asdf asdf::system-relative-pathname)
  (:export
   #:l-forall #:l-exists #:l-and #:l-or #:l-iff #:l-equal #:l-not
   #:l-implies #:pred-property #:pred-class #:*use-holds*
   #:logic-generator #:with-logic-var #:with-logic-vars #: #:
   #:def-logic-axiom #:axiom-sexp #:axiom-name #:axiom-description
   #:delete-axiom #:get-axiom #:prover9-prove #:mace4-find-model #:mace4-check-satisfiability #:mace4-check-satisfiability-alt #:logic-var-p
   #:clausetester-check-model 
   #:get-axioms #:tree-walk #:tree-replace
   #:prover9-logic-generator
   #:*last-mace4-model* 
   #:*last-prover9-input* 
   #:*last-prover9-output* 
   #:z3-logic-generator.
   #:latex-logic-generator.
   #:collect-axioms-from-spec
   #:z3-prove #:z3-find-model #:z3-get-unsat-core
   #:z3-check-satisfiability
   #:z3-syntax-check
   #:z3-check-true
   #:z3-render
   #:z3-model-form
   #:pprint-z3-model
   #:render
   #:render-axiom #:render-axioms
   #:vampire-prove
   #:vampire-render
   #:pprint-spec-axioms  #:pprint-spec-axiom-names  #:clear-axioms
   #:*last-z3-input* #:*last-z3-output*
   #:*last-vampire-input* #:*last-vampire-output*
   #:*last-clausetester-input*   #:*last-clausetester-output*
   #:def-expect-satisfiable #:def-expect-unsatisfiable #:def-expect-provable #:def-expect-not-entailed 
   #:run-proof #:proof-form #:render-proof #:prove-with
   #:clif-logic-generator #:dol-logic-generator
   #:render-ontology
   #:formula-elements
   #:vampire-check-unsatisfiable
   #:prover9-check-unsatisfiable
   #:prover9-check-true
   #:prover9-output-proof-section
   #:get-proof-support
  ))
