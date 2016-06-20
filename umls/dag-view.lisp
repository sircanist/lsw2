;; looks correct
(defun parents-tree (x &optional (ont snomed) (table (make-hash-table :test 'equalp)))
  (let ((child (list x (if (eq x !owl:Thing) "Thing" (entity-annotation-value x ont !rdfs:label))))
	(parents (mapcar
		  (lambda(c)
		    (if (eq c !owl:Thing)
			(list c "Thing")
			(list c (entity-annotation-value c ont !rdfs:label))))
		  (parents x ont))))
    (if parents
	(loop for parent in parents 
	   for pt = (or (gethash parent table) (setf (gethash parent table) (parents-tree (car parent) ont table)))
	   do  (setf (gethash pt table) (or (gethash pt table) pt))
	   collect (list* child  (gethash pt table))
	     )
	(list (list child ))
	)))
;; (parents-tree !<http://snomed.info/id/65172003> s)
       
(defstruct term-node
  uri
  label
  level
  index)

(defstruct (term-edge (:print-function print-edge))
  from
  to
  level
  )

(defun print-edge (edge stream x)
  (format stream "~a@~a -> ~a@~a" (term-node-label (term-edge-from edge)) (term-node-level (term-edge-from edge))
	  (term-node-label (term-edge-to edge)) (term-node-level (term-edge-to edge))))

(defun levelize (trees kb &optional (level 0) last (table (make-hash-table :test 'equal)) (nodes (make-array 100 :adjustable t :fill-pointer 0)) edges)
  (loop for tree in trees 
     do (let ((treetop
	       (or (gethash (caar tree) table)
		   (let* ((new (make-term-node
				:uri (caar tree)
				:label (if (eq (caar tree) !owl:Thing)
					   "Thing"
					   (entity-annotation-value (caar tree) kb !rdfs:label))
				:parents (rest tree))))
		     (setf (term-node-index new) (vector-push-extend new nodes))
		     new))))
	  (when last
	    (pushnew (make-term-edge :from last :to treetop) edges :test 'equalp))
	  (setf (gethash (caar tree) table) treetop)
	  (setf (term-node-level treetop) level)
	  (multiple-value-setq (nodes edges) (levelize (rest tree) kb (1+ level) treetop table nodes edges))))
  (values nodes edges))
	 
(defun emit-javascript (trees kb)
  (multiple-value-bind (nodes edges) (levelize trees kb)
    (with-output-to-string (s)
      (loop for node across nodes
	 for label = (#"replaceFirst" (term-node-label node) " \\(.*" "")
	 for level = (term-node-level node)
	 for id = (term-node-index node)
	 do 
	   (format s "nodes.push({id:~a, label: ~s, level: ~a});~%" id label level)
	   )
      (loop for edge in edges
	 for from = (term-node-index (term-edge-from edge))
	 for to = (term-node-index (term-edge-to edge))
	 do
	   (format s "edges.push({from: ~a, to: ~a});~%" from to)))))

(defun write-parent-hierarchy (term ont)
  (let ((trees (parents-tree term ont)))
    (let ((spec (emit-javascript trees ont)))
      (with-open-file (in "~/repos/lsw2git/umls/visualization/dag-view.template")
	(with-open-file (out "~/repos/lsw2git/umls/visualization/dag-view.html" :direction :output :if-exists :supersede)
	  (loop for line = (read-line in nil :eof)
	     until (eq line :eof)
	     if (search "__NODES_AND_EDGES_" line)
	     do (write-string spec out)
	     else do (write-string line out)
	       (terpri out)))))))

	       

#|
Generate this:

// randomly create some nodes and edges
            for (var i = 0; i < 15; i++) {
                nodes.push({id: i, label: String(i)});
            }
            edges.push({from: 0, to: 1});
            edges.push({from: 0, to: 6});
            edges.push({from: 0, to: 13});
            edges.push({from: 0, to: 11});
            edges.push({from: 1, to: 2});
            edges.push({from: 2, to: 3});
            edges.push({from: 2, to: 4});
            edges.push({from: 3, to: 5});
            edges.push({from: 1, to: 10});
            edges.push({from: 1, to: 7});
            edges.push({from: 2, to: 8});
            edges.push({from: 2, to: 9});
            edges.push({from: 3, to: 14});
            edges.push({from: 1, to: 12});
            nodes[0]["level"] = 0;
            nodes[1]["level"] = 1;
            nodes[2]["level"] = 3;
            nodes[3]["level"] = 4;
            nodes[4]["level"] = 4;
            nodes[5]["level"] = 5;
            nodes[6]["level"] = 1;
            nodes[7]["level"] = 2;
            nodes[8]["level"] = 4;
            nodes[9]["level"] = 4;
            nodes[10]["level"] = 2;
            nodes[11]["level"] = 1;
            nodes[12]["level"] = 2;
            nodes[13]["level"] = 1;
            nodes[14]["level"] = 5;

|#
