;;;; -*- Mode: LISP -*-

(in-package :asdf)

(defsystem :patches
  :name "patches"
  :serial t
  :components
  (
   (:file "abcl-function-doc")
   (:file "jinterface-safe-implementation")
  ))

;;;; eof
