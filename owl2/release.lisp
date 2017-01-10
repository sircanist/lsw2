;; Rerun the ontofox script to update externals (todo)
;; Load an ontology, merge all axioms into one ontology. (done)
;; Run reasoner. Add inferred subclass axioms.  (done)
:; Do a little materialization.  (todo)
;; Copy the ontology annotations from the top ontology (not the imports)  (done)
;; Don't add certain duplicates, such as extra copies of definitions or annotation. Be aware of duplicate 
;;   axioms that might be pulled in by chains of imports and prefer the proximate one. (todo)
;; Add imported-from annotations to the imported ontologies (done)
;; Write the merged ontology to the release directory (done)
;; Copy our own imports and others' unversioned imports to the release directory (done)
;; Add versionIRIs and rewrite imports to used them (done)
;; Add a note saying how this was created (done)
;; Write out a catalog-v001.xml because protege can't find ontologies in front of its nose (todo)
;; Write out what will be needed to be added to the the PURL config (todo)
;; Write out some basic facts / release notes template (todo)

(defclass foundry-release ()
  ((ontology-source-file :accessor ontology-source-file :initarg :ontology-source-file)
   (project-root-directory :accessor project-root-directory :initarg :project-root-directory)
   (ontology :accessor ontology :initarg :ontology)
   (reasoner :accessor reasoner :initarg :reasoner :initform :factpp)
   (namespace :accessor namespace :initarg :namespace)
   (release-time :accessor release-time :initarg :release-time )
   (version-date-string :accessor version-date-string :initarg :version-date-string)
   (release-directory-base :accessor release-directory-base :initarg :release-directory-base)
   (release-purl-base :accessor release-purl-base :initarg :release-purl-base)
   (dispositions :accessor dispositions :initarg :dispositions )
   (license-annotations :accessor license-annotations :initarg :license-annotations)
   (phases :accessor phases :initarg :phases :initform nil)
   (versioned-uri-map :accessor versioned-uri-map :initarg :versioned-uri-map)
   (additional-products :accessor additional-products :initarg :additional-products)
   ))

(setq last-kbd-macro "\213\C-y :accessor \C-y :initarg :\C-y\C-n\C-a\C-f\C-f\C-f")


(defmethod initialize-instance ((r foundry-release) &rest initiargs)
  (call-next-method)
  (assert (probe-file (ontology-source-file r)) () "Didn't find ontology-source-file - given as ~a" (ontology-source-file r))
  (when (and (not (slot-boundp r 'version-date-string) ) (not (slot-boundp r 'release-time)))
    (setf (release-time r) (get-universal-time)))
  (when (and (slot-boundp r 'version-date-string) (not (slot-boundp r 'release-time)))
    (setf (release-time r) 
	  (apply 'encode-universal-time 0 0 12
		 (car (all-matches (version-date-string r) "(\\d+)-(\\d+)-(\\d+)" 3 2 1))))))

(defmethod print-object ((r foundry-release) stream)
  (if (not (slot-boundp r 'namespace))
      (call-next-method)
      (print-unreadable-object (r stream :type t)
	(format stream "~a@~a~a~{~a~^,~}" (namespace r) (version-date-string r) (if (phases r) " : " ", not yet started") (phases r)))))

(defvar *current-release* )

;; this is the main call
(defun make-release (namespace source-file  &rest initargs &key (when (get-universal-time)) &allow-other-keys)
  (remf initargs :when)
  (setq *current-release* (apply 'make-instance 'foundry-release
				 :release-time when
				 :ontology-source-file source-file
				 :namespace namespace
				 initargs))
  (do-release *current-release*))

(defmethod do-release  ((r foundry-release))
  (create-merged-ontology r)
  (copy-files-to-release-directory r)
  (log-progress r "Creating catalog-v0001.xml for protege")
  (write-catalog.xml r)
  (log-progress r "Creating purl.yaml with lines to be pasted into the PURL config")
  (write-purl-yaml r))

;; (make-release "iao" "~/repos/information-artifact-ontology/src/ontology/iao.owl" when
;;    :additional-products '("ontology-metadata.owl"))
 
(defmethod  version-date-string  :around ((r foundry-release))
  "The date of the release in the form YYYY-MM-DD"
  (if (slot-boundp r 'version-date-string)
      (call-next-method)
      (setf (version-date-string r)
	    (multiple-value-bind (second minute hour date month year day)  (decode-universal-time (release-time r))
	      (declare (ignore second minute hour  day))
	      (format nil "~a-~2,'0D-~2,'0D" year month date)))))

(defmethod release-directory-base :around ((r foundry-release))
  "Usual setup is 'releases' parallel to 'src' and ontology below
   'ontology'. Guess the release directory from our input, check if it is
   there and let us know where we stand"
  (if (slot-boundp r 'release-directory-base)
      (call-next-method)
      (setf (release-directory-base r)
	    (let* ((source-path (ontology-source-file r))
		   (release-base (make-pathname :directory 
						(append
						 (remove-if
						  (lambda(e) (member e '("src" "ontology") :test'equal))
						  (pathname-directory source-path))
						 '("releases")))))
	      (if (probe-file release-base)
		  (log-progress r "Using release directory: ~a~%" release-base)
		  (cerror "Can't figure out release base (guessed ~a). Pass it to the function" release-base))
	      release-base))))

(defmethod project-root-directory :around ((r foundry-release))
  (if (slot-boundp r 'project-root-directory)
      (call-next-method)
      (setf (project-root-directory r)
	    (car (directory
		  (read-line 
		   (sys::process-output
		    (sys::run-program
		     "git" (list "rev-parse" "--show-toplevel")
		     :wait t :directory (release-directory-base r)))))))))

(defmethod project-root-relative-path ((r foundry-release) path)
  (make-pathname
   :directory
   `(:relative ,@(subseq (cdr (pathname-directory path))
			 (length (cdr (pathname-directory (project-root-directory r)))))) 
   :name (pathname-name path)
   :type (pathname-type path)))

(defmethod git-project-info ((r foundry-release))
  (loop with stream = (sys::process-output
		       (sys::run-program "git" (list "remote" "-v") :output
					 :stream :wait t :directory (release-directory-base r)))
	for line = (read-line stream nil :eof)
	until (eq line :eof)
	for match = (caar (all-matches line "origin\\s+(.*)\\s+\\(fetch\\)$" 1))
	when match do (return (car (all-matches match ".*?([^/]+)/([^/]+)\\.git$" 1 2)))))
  
;; git URLs are case sensitive. watch out
(defmethod release-purl-base :around ((r foundry-release))
  (if (slot-boundp r 'release-purl-base)
      (call-next-method)
      (destructuring-bind (owner project)
	  (git-project-info r)
	(let* ((raw-base (format nil "http://cdn.rawgit.com/~a/~a/master/" owner project))
	       (probe-test (merge-pathnames (project-root-relative-path r (truename (ontology-source-file r))) raw-base)))
	  (assert (probe-file probe-test) 
		  (raw-base probe-test) "Calculated Release-url-base incorrectly: ~a" raw-base)
	  (setf (release-purl-base r) raw-base)))))

(defmethod license-annotations :around ((r foundry-release))
  "File license in in the ontology directory is consulted. The first
   line is the URL to the license and is recorded in
   dc:license. Subsequent lines are a textual gloss and are put in an
   rdfs:comment"
  (if (slot-boundp r 'license-annotations)
      (call-next-method)
      (setf (license-annotations r)
	    (let ((license-path (make-pathname :directory (pathname-directory (ontology-source-file r)) :name "LICENSE" :type nil )))
	      (if (probe-file license-path)
		  (with-open-file (l license-path)
		    (list (list !dc:license (read-line l))
			  (let ((license-explanation
				  (with-output-to-string (s)
				    (loop for line = (read-line l nil :eof)
					  until (eq line :eof)
					  do (write-line line s)))))
			    (setq license-explanation (#"replaceAll" license-explanation "(^\\s*|\\s*$)" ""))
			    (list !rdfs:comment license-explanation))))
		  (warn "LICENSE file not found so can't add info to release files"))))))

(defmethod dispositions :around ((r foundry-release))
  (if (slot-boundp r 'dispositions )
      (call-next-method)
      (setf (dispositions r) (compute-imports-disposition r))))

(defmethod versioned-uri-map :around ((r foundry-release))
  (if (slot-boundp r 'versioned-uri-map)
      (call-next-method)
      (setf (versioned-uri-map r) 
	    (mapcar (lambda(d)
		      (list (getf d :ontologyiri)
			    (getf d :versioniri)))
		    (dispositions r)))))

(defmethod versioned-uri-for ((r foundry-release) uri)
  (second (assoc uri (versioned-uri-map r))))

(defun new-empty-kb (ontology-iri &key reasoner)
  "Make an empty KB into which we'll copy the merged file and the inferences"
  (let* ((manager (#"createOWLOntologyManager" 'org.semanticweb.owlapi.apibinding.OWLManager))
	 (ont (#"createOntology" manager (to-iri (uri-full ontology-iri)))))
    (make-v3kb :name ontology-iri :manager manager :ont ont :datafactory (#"getOWLDataFactory" manager) :default-reasoner reasoner)))

(defmethod log-progress ((r foundry-release) format-string &rest format-args)
  (fresh-line *debug-io*)
  (apply 'format *debug-io* format-string format-args)
  (force-output *debug-io*))

(defmethod ontology :around ((r foundry-release))
  (if (slot-boundp r 'ontology)
      (call-next-method)
      (setf (ontology r) (init-ontology r))))

(defmethod init-ontology ((r foundry-release))
  (log-progress r  "Loading ontology")
  (let ((ontology (load-ontology (ontology-source-file r))))
    (instantiate-reasoner ontology (reasoner r) nil
			  (new 'SimpleConfiguration (new 'NullReasonerProgressMonitor)))
    (log-progress r  "Checking consistency and classifying")
    (assert (check-ontology ontology :classify t) () "Ontology is inconsistent")
    (assert (not (unsatisfiable-classes ontology)) () "Ontology has unsatisfied classes")
    ontology))

(defmethod copy-ontology-annotations ((r foundry-release) source dest &optional filter)
  (loop for annotation in (jss::j2list (#"getAnnotations" (v3kb-ont source)))
	for prop = (make-uri (#"toString" (#"getIRI" (#"getProperty"  annotation))))
	unless (and filter (not (funcall filter prop)))
	  do (add-ontology-annotation  annotation dest)))

(defmethod note-ontologies-merged ((r foundry-release) to-ont)
  (loop with imported-from = !<http://purl.obolibrary.org/obo/IAO_0000412>
	for disp in (dispositions r)
	for versioniri = (getf disp :versioniri) 
	do (add-ontology-annotation (list imported-from versioniri) to-ont)))

(defmethod merged-ontology-pathname ((r foundry-release))
  (merge-pathnames (format nil "~a-merged.owl" (namespace r)) (ensure-release-dir r)))

(defmethod create-merged-ontology ((r foundry-release))
  (let* ((source (ontology r))
	 (destont (new-empty-kb (make-uri (format nil "http://purl.obolibrary.org/obo/~a.owl" (namespace r)))))
	 (dispositions (compute-imports-disposition r))
	 (license-annotations (license-annotations r)))
    (copy-ontology-annotations r source destont (lambda(prop) (not (eq prop !owl:versionIRI))))
    (note-ontologies-merged r destont)
    (add-ontology-annotation `(,!owl:versionIRI ,(make-versioniri (namespace r) (version-date-string r)))  destont)
    (add-ontology-annotation `(,!rdfs:comment "This version of the ontology is the merge of all its imports and has added axioms inferred by an OWL reasoner") destont)
    (log-progress r "Merging")
    (loop for disp in dispositions
	  for ont = (getf disp :ontology)
	  do (each-axiom ont (lambda(ax) (add-axiom ax destont)) nil))
    (log-progress r "Adding inferences")
    (add-inferred-axioms source :to-ont destont :types
			 (set-difference *all-inferred-axiom-types* '(:disjoint-classes :class-assertions)))
    (when license-annotations (log-progress r "Adding license"))
    (dolist (a license-annotations) (add-ontology-annotation a destont))
    (let ((dest (merged-ontology-pathname r)))
      (to-owl-syntax destont :rdfxml dest))))

(defun make-v3kb-facade (ontology-path)
  (let ((manager (#"createOWLOntologyManager" 'org.semanticweb.owlapi.apibinding.OWLManager)))
    (let* ((ontology (#"loadOntologyFromOntologyDocument" manager (new 'filedocumentsource (new 'java.io.file  (namestring ontology-path))))))
      (make-v3kb :manager (#"getOWLOntologyManager" ontology)
		 :datafactory (#"getOWLDataFactory" (#"getOWLOntologyManager" ontology))
		 :ont ontology
		 :changes (new 'arraylist)))))
  
(defmethod add-version-iris-license-and-rewrite-imports ((r foundry-release) ontology-path add-license)
  "Walk the loaded files. For our files copy to release directory and
  rewrite the imports and add versionIRIs. For other-than-our files
  that don't have versionIRIs we fetch their latest (? what about
  cached versions), save to release directory, and adjust their PURLs"
  (let ((kb (make-v3kb-facade ontology-path)))
    (loop for import-uri in (get-imports-declarations kb)
	  for replacement = (versioned-uri-for r (make-uri import-uri))
	  when replacement
	    do (remove-ontology-imports import-uri kb)
	       (add-ontology-imports replacement kb))
    (when (and add-license (license-annotations r))
      (log-progress r "Adding license to ~a" ontology-path)
      (dolist (a (license-annotations r)) (add-ontology-annotation  a kb)))
    (let ((newversioniri (versioned-uri-for r (get-ontology-iri kb))))
      (when newversioniri
	(set-version-iri kb newversioniri)
	(apply-changes kb)))
    (log-progress r "Rewriting imports for ~a~%" ontology-path)
    (to-owl-syntax kb :rdfxml ontology-path)))

(defmethod compute-imports-disposition ((r foundry-release))
  "For each of the imports decide if we are using a published
   versioned import or a version we serve. Return a data structure that
   will guide further work, including where to copy something from (or
   nil if we're not going to copy it) the ontologyiri the versioniri and
   where the import was loaded from"
  (loop with date = (version-date-string r)
	for (loaded-from uri ont) in (loaded-documents (ontology r))
	for id = (#"getOntologyID" ont)
	for ontologyiri = (#"toString" (#"get" (#"getOntologyIRI" id)))
	for versioniri = (ignore-errors (#"toString" (#"get" (#"getVersionIRI" id))))
	do
	   (assert (equal ontologyiri uri) (uri ontologyiri)
		   "What's up - uri and ontologyiri don't match ~a - ~a" uri ontologyiri)
	collect
	(list* :ontologyiri (make-uri ontologyiri) :ontology ont 
	       (cond ((equal (third (pathname-directory ontologyiri)) (namespace r))
		      ;; This is one of ours, so make date relative purl <namespace>/<file.owl> -> <namespace>/<date>/<file.owl>
		      (let ((versioned (namestring (merge-pathnames (make-pathname :directory `(:relative ,date)) ontologyiri))))
			(list :copy loaded-from :ontologyiri ontologyiri :versioniri (make-uri versioned) :add-license t )))
		     ((equal (pathname-name ontologyiri) (namespace r))
		      ;; This is the main file. <namespace.owl> -> <namespace>/<date><namespace.owl>
		      (let ((versioned (namestring (merge-pathnames (make-pathname :directory `(:relative ,(namespace r) ,date)) ontologyiri))))
			(list :copy loaded-from :versioniri (make-uri versioned) :add-license t)))
		     ;; This is an external import. Use its versionIRI
		     ;; Might neede to be careful - if locally cached it could be stale. Not the case for IAO
		     ((not versioniri)
					;(warn "Didn't get versionIRI for ~a so using copying and will use local version" ontologyiri)
		      (list :copy ontologyiri :versioniri (make-local-version-uri r ontologyiri) :add-license nil))
		     (t (list :copy nil :versioniri (make-uri versioniri) :add-license nil))))))

(defmethod make-local-version-uri ((r foundry-release) ontology-iri)
  "We have http://auth/path/file.owl - We make:
  http://purl.obolibrary.org/obo/namespace/date/auth/path/file.owl (if
  path starts with /obo/ we don't include that. Ditto if auth is
  purl.obolibrary.org)."
  (let* ((auth (getf (pathname-host ontology-iri) :authority))
	 (path (pathname-directory ontology-iri))
	 (file (pathname-name ontology-iri))
	 (type (pathname-type ontology-iri)))
    (let ((path (if (equal "obo" (second path))
		    (cons (car path) (cddr path))
		    path))
	  (auth (if (equal auth "purl.obolibrary.org")
		    nil
		    `(:relative ,auth))))
      (make-uri (namestring (merge-pathnames (make-pathname :directory (rplaca path :relative))
		       (merge-pathnames (make-pathname :directory auth)
					(make-pathname
					 :directory `(:absolute  "obo" ,(namespace r) ,(version-date-string r))
					 :name file
					 :type type
					 :host `(:scheme "http" :authority "purl.obolibrary.org"))
					)
		       ))))))
      
(defun make-versioniri (namespace &optional (date (version-date-string)))
  "The versioniri for the main artifact"
  (make-uri (format nil "http://purl.obolibrary.org/obo/~a/~a/~a.owl" namespace date namespace)))

(defmethod ensure-release-dir ((r foundry-release))
  "Make sure that the dated release directory is present and if not create it"
  (let ((basename (namestring (translate-logical-pathname (release-directory-base r)))))
    (when (not (#"matches" basename ".*/$"))
      (setq basename (concatenate 'string basename "/")))
    (ensure-directories-exist 
     (merge-pathnames (make-pathname :directory `(:relative ,(version-date-string r)))
		      basename))))

(defmethod write-catalog.xml ((r foundry-release)) 
  (with-open-file (c (merge-pathnames (make-pathname :directory `(:relative ,(version-date-string r))
						     :name "catalog-v001" :type "xml")
				      (release-directory-base r))
		     :if-exists :supersede :direction :output)
    (write-line "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"no\"?>" c)
    (write-line "<catalog prefer=\"public\" xmlns=\"urn:oasis:names:tc:entity:xmlns:xml:catalog\">" c)
    (loop for d in (dispositions r)
	  for versioniri = (uri-full (getf d :versioniri))
	  for ontologyiri = (uri-full (getf d :ontologyiri))
	  do
	     (format c "    <uri name=\"~a\" uri=\"~a.~a\"/>~%" versioniri (pathname-name versioniri) (pathname-type versioniri))
	     (format c "    <uri name=\"~a\" uri=\"~a.~a\"/>~%" ontologyiri (pathname-name ontologyiri) (pathname-type ontologyiri)))
    (write-line "</catalog>" c)))

(defmethod copy-files-to-release-directory ((r foundry-release))
  (loop for disp in (dispositions r)
	for copy = (getf disp :copy)
	when copy
	  do (let ((dest (merge-pathnames (make-pathname :name (pathname-name copy) :type "owl") (ensure-release-dir r))))
	       (log-progress r "Copying ~a.~a to ~a~%" (pathname-name copy) (pathname-type copy) dest)
	       ;; I would use copy-file but it doesn't know about redirects
	       ;; (uiop/stream:copy-file copy dest)
	       (sys::run-program "curl" (list "-L" (uri-full (make-uri (namestring copy))) "-o" (namestring dest)))
	       (add-version-iris-license-and-rewrite-imports r dest (getf disp :add-license))))
  (let ((to-be-deleted (directory (merge-pathnames (make-pathname :name :wild :type "bak") (ensure-release-dir r)))))
    (loop for file in to-be-deleted
	  do (log-progress r "Deleting ~a~%" file)
	     (delete-file file))))

(defmethod write-purl-yaml ((r foundry-release)) 
  (with-open-file (c (merge-pathnames (make-pathname
				       :directory `(:relative ,(version-date-string r))
				       :name "purl"
				       :type "yaml")
				      (release-directory-base r))
		     :if-exists :supersede :direction :output)
    ;; main product
    (format c "-exact: ~a.owl~%" (namespace r))
    (format c "  replacement: ~areleases/~a/~a-merged.owl~%~%" (release-purl-base r) (version-date-string r) (namespace r))
    ;; dated main product
    (format c "-exact: ~a/~a/~a.owl~%" (namespace r) (version-date-string r) (namespace r))
    (format c "  replacement: ~areleases/~a/~a-merged.owl~%~%" (release-purl-base r) (version-date-string r) (namespace r))
    ;; stated main product
    (format c "-exact: ~a/~a-stated.owl~%" (namespace r) (namespace r))
    (format c "  replacement: ~areleases/~a/~a.owl~%~%" (release-purl-base r) (version-date-string r) (namespace r))
    ;; additional products
    (loop for product in (additional-products r)
	  do (format c "-exact: ~a/~a~%" (namespace r) product)
	     (format c "  replacement: ~areleases/~a/~a~%~%" (release-purl-base r) (version-date-string r) product))
    ;; All the imports (the first entry is the top-level ontology which we've already handled)
    (loop for d in (cdr (dispositions r))
	  for iri = (uri-full (getf d :versioniri))
	  for copy = (getf d :copy)
	  when copy
	    do
	       (format c "-exact: ~a~%" (#"replaceAll" iri ".*?://.*?/.*?/" ""))
	       (format c "  replacement: ~areleases/~a/~a.~a~%" (release-purl-base r) (version-date-string r) (pathname-name iri) (pathname-type iri))
	       (terpri c))))

