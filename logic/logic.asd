;;;; -*- Mode: LISP -*-
;;;;

(in-package :asdf)

;(load (merge-pathnames "winston-ai/winston-forward-chain.asd" *load-truename*))

(defsystem :logic
  :name "LOGIC"
  :author "Alan Ruttenberg"
  :license "BSD"
  :components
  ((:module "package" :pathname ""
    :components
    ((:file "package")))
   (:module "graal" :components
            ((:mvn "fr.lirmm.graphik/graal-io-dlgp/1.3.1")
	     (:mvn "fr.lirmm.graphik/graal-io-sparql/1.3.1")
             (:mvn "fr.lirmm.graphik/graal-kb/1.3.1")
   	     ))
   (:module "main" :pathname ""
    :components
    ((:file "axiom")
     (:file "logic-generator"))
    :serial t
    :depends-on ("package"))
   (:module "provers" :pathname ""
    :components 
    ((:file "snark-logic-generator")
     (:file "prover9-logic-generator")
     (:file "z3-logic-generator")
     (:file "fol-logic-generator")
     (:file "fol-text-logic-generator")
     (:file "latex-logic-generator")
     (:file "clif-logic-generator")
     (:file "dol-logic-generator")
     (:file "prove-with-prover9")
     (:file "prove-with-z3")
     (:file "prove-with-vampire")
     (:file "parse-prover9")
     (:file "proof")
     (:file "check-model")
     (:file "prolog")
     (:file "formula-tester")
     (:file "cnf")
     (:file "model")
     (:file "expand-model")
     (:file "graal")
     (:file "test-theory-with-model-seed")
     (:file "paper-support")
     (:org "render-ontology-fol")
     (:file "read-clif"))
    :depends-on ("package" "main"
			   "graal"
			   )))
  :depends-on (:cl-ansi-text :yacc :paiprolog :util :md5 :cl-unification)
  :defsystem-depends-on  ("lilith")

  :in-order-to ((test-op (load-op "logic/test"))))

(defsystem :logic/test
  :description "Test OWL to FOL translations"
  :perform  (test-op (o s)
                     (load uiop:symbol-call :abcl.test.lisp '#:run))
  :components
  ((:module "t"
    :components ((:file "owl-test-cases")
                 (:file "owl-to-fol"))
    :serial t)))
