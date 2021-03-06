(in-package :cl-user)

(defvar *page-cache* (make-hash-table :test 'equal))

(defvar *cookies* nil)

(defun head-url (url)
  (get-url url :head t))

(defun post-url-xml (url message)
  (get-url url :post message))

(define-condition http-error-response (error) ((response-code :initarg :response-code) (message :initarg :message)) (:report format-http-error-response))

(defun format-http-error-response (condition stream)
  (format stream "Bad HTTP response ~A: ~A" (slot-value condition 'response-code) (slot-value condition 'message)))

(defvar *http-stream* nil)

(defvar *trace-geturl* nil)
(defvar *default-ignore-errors* nil)

(defun get-url (url &key post (force-refetch  post) (dont-cache post) (to-file nil) (persist (and (not post) (not to-file))) cookiestring nofetch verbose tunnel referer (follow-redirects t) when-done  
		      (ignore-errors *default-ignore-errors*)  head accept  extra-headers (appropriate-response (lambda(res) (and (numberp res) (>= res 200) (< res 400)))) (verb "GET")
		&aux it done)
    (declare (special *http-stream))
  (when *trace-geturl* (format t "Getting ~s~%" url))
    (unwind-protect
	 (progn 
	   (setq it (threads:make-thread 
		     (lambda()
		       (catch 'abort
			 (flet ((doit ()
				  (get-url-1 url :post post :force-refetch force-refetch :dont-cache dont-cache
						 :to-file to-file :persist persist :cookiestring cookiestring :nofetch nofetch
						 :verbose verbose :tunnel tunnel :referer referer :follow-redirects follow-redirects
						 :ignore-errors ignore-errors :head head :accept accept :extra-headers extra-headers
						 :appropriate-response appropriate-response :verb verb
						 )))
			   (prog1
			       (if when-done
				   (funcall when-done (multiple-value-list (doit)))
				   (multiple-value-list (doit)))
			     (setq done t)))))))
	   (unless when-done (values-list (threads:thread-join it))))
      (unless done
	(threads::destroy-thread it))
      (when *http-stream* (#"disconnect" *http-stream*) (setq *http-stream* nil))
      (unless done
	(abort))
      ))

(defun get-url-1 (url &key post (force-refetch  post) (dont-cache post) (to-file nil) (persist (and (not post) (not to-file))) cookiestring nofetch verbose tunnel referer (follow-redirects t) 
		(ignore-errors nil) head accept  extra-headers (appropriate-response (lambda(res) (and (numberp res) (>= res 200) (< res 400)))) (verb "GET")
		&aux headers doing-ftp)
  "Get the contents of a page, saving it for this session in *page-cache*, so when debugging we don't keep fetching"
  (sleep 0.0001)			; give time for control-c
  (if (not (equal verb "GET"))
      (setq force-refetch t))
  (and head
       (setq force-refetch t dont-cache t persist nil follow-redirects nil))
  (or (and (not force-refetch) (gethash url *page-cache*))
      (when (config :web-cache)
	(and (not force-refetch) (probe-file (url-cached-file-name url))
	     (get-url-from-cache url))
	(and nofetch
	     (error "Didn't find cached version of ~a" url)))
      (labels ((stream->string (stream)
		 (let ((buffer (jnew-array "byte" 4096)))
		   (apply 'concatenate 'string
			  (loop for count = (#"read" stream buffer)
				while (plusp count)
				do (sleep 0.0001)
				collect (#"toString" (new 'lang.string buffer 0 count))
				))))
	       (stream->file (stream file)
		 (let ((buffer (jnew-array "byte" 4096))
		       (ofile (new 'java.io.file (namestring (translate-logical-pathname file)))))
		   (when (not (#"exists" ofile))
		     (#"createNewFile" ofile))
		   (let ((ostream (new 'java.io.fileoutputstream ofile)))
		     (loop for count = (#"read" stream buffer)
		      while (plusp count)
		      do (sleep 0.0001)
		      (#"write" ostream buffer 0 count))
		     (#"close" ostream))))
	     (doit()
	       (when verbose (format t "~&;Fetching ~s~%" url))
	       (let ((connection (setq *http-stream* (#"openConnection" (new 'java.net.url (maybe-rewrite-for-tunnel url tunnel)))))
		     )
		 (unless doing-ftp 
		   (if follow-redirects 
		       (#"setInstanceFollowRedirects" connection t)
		       (#"setInstanceFollowRedirects" connection nil)))
		 (when (or *cookies* cookiestring)
		   (#"setRequestProperty" connection "Cookie" (join-with-char (append *cookies* cookiestring) #\;)))
		 (when referer
		   (#"setRequestProperty" connection "Referer" referer))
		 (#"setRequestProperty" connection "User-Agent" "Mozilla/4.0")
		 (when verb
		   (if (and doing-ftp (equal verb "HEAD"))
		       (return-from get-url-1 (values "" (ftp-fake-http-headers url)))
		       (if doing-ftp
			   (unless (equal verb "GET") (error "I only handle FTP HEAD and GET"))
			 (#"setRequestMethod" connection verb))))
		 (when accept
		   (#"setRequestProperty" connection "Accept" accept))
		 (loop for (key value) in extra-headers
		      do (#"setRequestProperty" connection key value))
		 (when post
		   (if (equal verb "PUT")
		       (#"setRequestMethod" connection "PUT")
		       (#"setRequestMethod" connection "POST"))
		   (#"setDoOutput" connection t)
		   (if (consp post)
		       (with-output-to-string (s)
			 (loop for (prop value) in post
			    do (format s "~a=~a&" prop (#"encode" 'java.net.URLEncoder (coerce value 'simple-string) "UTF-8")))
			 (setq post (get-output-stream-string s))
			 (setq post (subseq post 0 (- (length post) 1)))
			 (#"setRequestProperty" connection "Content-Type" "application/x-www-form-urlencoded"))
		       (#"setRequestProperty" connection "Content-Type" "text/xml"))
		   (let ((out (new 'PrintWriter (#"getOutputStream" connection))))
		     ;(print post)
		       (#"print" out post)
		       (#"close" out)))
		 (when head
		   ;(#"setRequestMethod" connection "HEAD")
		   (unwind-protect
			(let ((responsecode (if doing-ftp 200 (#"getResponseCode" connection))))
			  (if (not (funcall appropriate-response responsecode))
			      (let ((errstream (#"getErrorStream" connection)))
				(error (make-condition 'http-error-response :response-code responsecode :message (if errstream (stream->string errstream) "No error stream"))) )
			      (return-from get-url-1 (unpack-headers responsecode (#"getHeaderFields" connection)))))
		     (#"disconnect" connection)
		     (setq *http-stream* nil)))
		 (setq headers (#"getHeaderFields" connection))
		 (unwind-protect
		      (let ((responsecode  (if doing-ftp 200 (#"getResponseCode" connection))))
			(if (not (funcall appropriate-response responsecode))
			    (let ((errstream (#"getErrorStream" connection)))
			      (if ignore-errors
				  (when verbose (format t "~&;Failed to fetch ~a - got response code ~a~%" url responsecode))
				  (error (make-condition 'http-error-response :response-code responsecode :message (if errstream (stream->string errstream) "No error stream"))) ))
			    (let ((stream (ignore-errors (#"getInputStream" connection))))
			      (if (and (member responsecode '(301 302 303)) follow-redirects)
				  (progn (setq url (second (assoc "Location" (unpack-headers responsecode headers) :test 'equal)))
					 ;; BUG HERE: If the redirect is to an FTP location, then some of the methods don't work, including setRequestMethod, and so doit, which retries the get on the redirected-to site gets an error.
					 (when (equal (getf (pathname-host url) :scheme) "ftp") (setq doing-ftp t))
					 (doit))
				  (ignore-errors
				   (if to-file 
				       (stream->file stream to-file)
				       (stream->string stream)))))
			    ))
		   (if doing-ftp
		       (#"close" connection)
		       (#"disconnect" connection))
		   (setq *http-stream* nil)))))
	(if ignore-errors
	    (multiple-value-bind (value errorp) (ignore-errors (doit))
	      (if errorp
		  (progn
		    (when verbose (format t "~a" (java-exception-message errorp)))
		    (values (list :error errorp (java-exception-message errorp)) (unpack-headers nil headers)))
		  (progn
		    (if (and persist (not (and ignore-errors (null value)))) (save-url-contents-in-cache url value) value)
		    (if dont-cache
			(values value (unpack-headers nil headers))
			(values (setf (gethash url *page-cache*) value) (unpack-headers nil headers))))))
	    (progn
	      (let ((value (doit)))
		(if persist (save-url-contents-in-cache url value) value)
		(if dont-cache
		    (values value (unpack-headers nil headers))
		    (values (setf (gethash url *page-cache*) value) (unpack-headers nil headers)))))
	    ))))

(defun persist-page-cache ()
  (unless (config :web-cache)
    (maphash
     (lambda(k v)
       (unless (probe-file (url-cached-file-name v))
	 (save-url-contents-in-cache k v)))
     *page-cache*)))


(defun header-value (header headers)
  (cadr (assoc header headers :test 'equal)))

(defun maybe-rewrite-for-tunnel (url tunnel)
  (if tunnel
      (destructuring-bind (protocol  path)
	  (car (all-matches url "^([a-z]*)://[^/]*(.*)" 1 2))
	(concatenate 'string protocol "://" tunnel path))
      url))



 (defun unpack-headers (response headers)
  (append
   (if response
       (list (list "response-code" response))
       nil)
   (and headers

	(loop 
	   for key in (set-to-list (#"keySet" headers))
	   for value = (#"get" headers key)
	   when value
	   collect (cons key
			 (loop for i below (#"size" value)
			    collect (#"get" value i)))
	   ))))

;; FIXME - workaround for http://lists.common-lisp.net/pipermail/armedbear-devel/2012-July/002477.html
(defun unpack-headers (response headers)
  (append
   (if response
       (list (list "response-code" response))
       nil)
   (and headers
        (with-constant-signature ((size "size") (get "get"))
        (loop
           for key in (set-to-list (#"keySet" headers))
           for value = (#"get" headers key)
           when value
           collect (cons key
                         (loop for i below (size value)
                            collect (get value i)))
           )))))
	

(defun cache-url ())

(defun url-cached-file-name (url)
  (and (config :web-cache)
       (let ((it (new 'com.hp.hpl.jena.shared.uuid.MD5 url)))
	 (#"processString" it)
	 (let* ((digest (#"getStringDigest" it))
		(subdirs (coerce (subseq digest 0 4) 'list)))
	   (merge-pathnames (make-pathname :directory (cons :relative (mapcar 'string subdirs))
					   :name digest :type "urlcache") (config :web-cache))))))

(defun save-url-contents-in-cache (url content)
  (let ((fname (url-cached-file-name url)))
    (and fname 
	 (ensure-directories-exist fname)
	 (with-open-file (f fname :direction :output :if-does-not-exist :create :external-format :utf-8)
	   (format f "~s" url)
	   (write-string content f)))))

(defun get-url-from-cache (url)
  (let ((fname (url-cached-file-name url)))
    (and fname
	 (with-open-file (f fname :direction :input)
	   (let ((url-saved (read f)))
	     (assert (equalp url url-saved) () "md5 collision(!) ~s, ~s" url url-saved)
	     (let ((result (make-string (- (file-length f) (file-position f)))))
	       (read-sequence result f)
	       result))))))

(defun forget-cached-url (url)
  (when (and (config :web-cache)
	     (probe-file (url-cached-file-name url)))
    (delete-file (url-cached-file-name url))
    (remhash url *page-cache*)))

(defun java-exception-message (exception)
  (ignore-errors (caar (all-matches (#"toString" (slot-value exception 'system::cause)) "(?s)=+\\s*(.*?)\\n" 1))))

(defun wikipedia (term)
  "Lookup a wikipedia page by name and return it's url. If ambiguous, return :ambiguous. If missing return :missing"
  (let ((page (get-url (format nil "http://en.wikipedia.org/wiki/~a" (#"replaceAll" term " "  "_")))))
    (if (consp page)
	page
	(let ((pagename (caar (all-matches page "<title>\\s*(.*?)\\s*- Wikipedia, the free encyclopedia</title>" 1))))
	  (setq pagename (#"replaceAll" pagename " "  "_"))
	  (if (or (#"matches" pagename "(?i)disambiguation")
		  (search "Category:Disambiguation" page))
	      (values :ambiguous
		      (format nil "http://en.wikipedia.org/wiki/~a" pagename))
	      (if (search "Wikipedia does not have an article with this exact name" page)
		  (values :missing
			  (format nil "http://en.wikipedia.org/wiki/~a" pagename))
		  (format nil "http://en.wikipedia.org/wiki/~a" pagename)))))))

(defun get-url-from-google-cache (url &rest args)
  (ignore-errors
    (#"replaceFirst" 
     (get-url (format nil "http://www.google.com/search?hl=en&lr=&client=safari&rls=en&q=cache:~a&btnG=Search"   
		      (regex-replace-all "^http://"
					 (regex-replace-all "="
							    (regex-replace-all "\\?" (regex-replace-all "&" url "%26") "%3F")
							    "%3D")
					 "")))
     "(?s)(?i)<table.*?<hr>" "")))

(defun cached-url-safari (url)
  (and (config :web-cache)
       (probe-file (url-cached-file-name url))
       (run-shell-command (format nil "osascript -e 'tell application \"Safari\"' -e 'open \"~a\"' -e 'end tell'"
					 (substitute #\: #\/ (namestring (truename (url-cached-file-name url))))))))

(defparameter *uri-workaround-character-fixes* 
  (load-time-value
   (loop for fixme in '(#\& #\  #\( #\)  )
      collect (list (#"compile" '|java.util.regex.Pattern| (format nil "[~c]" fixme))
		    (format nil "%~2x" (char-code fixme)) fixme))))

(defun clean-uri (site path &optional (protocol "http" ) (fragment nil) (query nil) (nofix nil))
  (if (eq nofix t)
      (#"toString" (new 'java.net.uri protocol (or site +null+) path (or query null) (or fragment +null+)))
      (loop for (pattern replacement) in *uri-workaround-character-fixes*
	 with uri = (#0"toString" (new 'java.net.uri protocol (or site +null+) path (or query +null+) (or fragment +null+)))
	 for new = 
	 (#0"replaceAll" (#0"matcher" pattern uri) replacement)
	 then
	 (#0"replaceAll" (#0"matcher" pattern new) replacement)
	 finally (return  (#"toString" new)) )
      ))

(defmacro with-cookies-from (site &body body)
  (if (and (consp site) (eq (car site) 'get-url))
      `(with-cookies-from-f (lambda() ,site) (lambda() (progn ,@body)))
      `(with-cookies-from-f ,site (lambda() (progn ,@body)))))

(defun with-cookies-from-f (site continue)
  (if (functionp site)
      (multiple-value-bind (value headers) (funcall site)
	(with-cookies-from-f headers continue))
      (if (consp site)
	  (let ((*cookies* (append *cookies* (mapcar (lambda(e) (#"replaceAll" e ";.*" "")) (cdr (assoc "Set-Cookie" site :test 'equal))))))
	    (values (funcall continue) (cadr (assoc "Location" site :test 'equal))))
	  (let ((headers (head-url site)))
	    (let ((*cookies* (append *cookies* (mapcar (lambda(e) (#"replaceAll" e ";.*" "")) (cdr (assoc "Set-Cookie" headers :test 'equal))))))
	      (values (funcall continue) (cadr (assoc "Location" headers :test 'equal))))))))

(defmacro set-cookies-from (site)
  `(set-cookies-from-f ',site ))

(defun set-cookies-from-f (site)
  (let ((headers (get-url site :persist nil :dont-cache t :force-refetch t :follow-redirects nil)))
    (setq *cookies* (mapcar (lambda(e) (#"replaceAll" e ";.*" "")) (cdr (assoc "Set-Cookie" headers :test 'equal))))
    ))

(defun ftp-fake-http-headers (url)
  (list (list "Etag" (apply 'format nil "\"~a-~a'\"" (ftp-file-size-and-date url)))))
	      
(defun ftp-file-size-and-date (ftp-url)
  (let ((client (new 'commons.net.ftp.ftpclient))
	(host (getf (pathname-host ftp-url) :authority)))
    (#"connect" client host)
    (unwind-protect 
	 (progn
	   (#"enterLocalPassiveMode" client)
	   (#"login" client "anonymous" "lsw")
	   (let ((list 
		   (#"listFiles"  client (namestring (make-pathname :directory (pathname-directory ftp-url)
								    :name (pathname-name ftp-url)
								    :type (pathname-type ftp-url))))))
	     (when (> (length list) 0)
	       (let ((filedesc (elt list 0)))
		 (list (#"getSize" filedesc)
		       (+ (/ (#"getTimeInMillis" (#"getTimestamp" filedesc)) 1000) 2208988800))))))
    (#"disconnect" client))))
