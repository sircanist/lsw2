(defun capitalize-by-hyphen (symbol)
  (apply 'concatenate 'string 
	 (mapcar 'string-capitalize 
		 (split-at-char (string symbol) "-"))))

(defparameter *owl2-vocabulary-forms*
  (let ((table (make-hash-table :test 'equalp)))
    (loop for (un worded &optional third) in
	 '((annotation annotation)
	   (annotationassertion annotation-assertion)
	   (annotationproperty annotation-property)
	   (annotationpropertydomain annotation-property-domain)
	   (annotationpropertyrange annotation-property-range)
	   (asymmetricobjectproperty asymmetric-object-property)
	   (class class)
	   (classassertion class-assertion)
	   (dataallvaluesfrom data-all-values-from)
	   (datacomplementof data-complement-of)
	   (dataexactcardinality data-exact-cardinality)
	   (datahasvalue data-has-value)
	   (dataintersectionof data-intersection-of)
	   (datamaxcardinality data-max-cardinality)
	   (datamincardinality data-min-cardinality)
	   (dataoneof data-one-of)
	   (dataproperty data-property)
	   (datapropertyassertion data-property-assertion)
	   (datapropertydomain data-property-domain)
	   (datapropertyrange data-property-range)
	   (datasomevaluesfrom data-some-values-from)
	   (datatype datatype)
	   (datatypedefinition datatype-definition)
	   (datatyperestriction datatype-restriction)
	   (dataunionof data-unionof)
	   (declaration declaration)
	   (differentindividuals different-individuals)
	   (disjointclasses disjoint-classes)
	   (disjointdataproperties disjoint-data-properties)
	   (disjointobjectproperties disjoint-object-properties)
	   (disjointunion disjoint-union)
	   (equivalentclasses equivalent-classes)
	   (equivalentdataproperties equivalent-data-properties)
	   (equivalentobjectproperties equivalent-object-properties)
	   (functionaldataproperty functional-data-property)
	   (functionalobjectproperty functional-object-property)
	   (haskey has-key)
	   (import import imports)
	   (inversefunctionalobjectproperty inverse-functional-object-property)
	   (inverseobjectproperties inverse-object-properties)
	   (irreflexiveobjectproperty irreflexive-object-property)
	   (namedindividual named-individual)
	   (negativedatapropertyassertion negative-data-property-assertion)
	   (negativeobjectpropertyassertion negative-object-property-assertion)
	   (objectallvaluesfrom object-all-values-from)
	   (objectcomplementof object-complement-of)
	   (objectexactcardinality object-exact-cardinality)
	   (objecthasself object-has-self)
	   (objecthasvalue object-has-value)
	   (objectintersectionof object-intersection-of)
	   (objectinverseof object-inverse-of)
	   (objectmaxcardinality object-max-cardinality)
	   (objectmincardinality object-min-cardinality)
	   (objectoneof object-one-of)
	   (objectproperty object-property)
	   (objectpropertyassertion object-property-assertion)
	   (objectpropertychain object-property-chain)
	   (objectpropertydomain object-property-domain)
	   (objectpropertyrange object-property-range)
	   (objectsomevaluesfrom object-some-values-from)
	   (objectunionof object-union-of)
	   (ontology ontology)
	   (reflexiveobjectproperty reflexive-object-property)
	   (sameindividual same-individual)
	   (subannotationpropertyof sub-annotation-property-of)
	   (subclassof sub-class-of sub-class-of subclass-of)
	   (subdatapropertyof sub-data-property-of)
	   (subobjectpropertyof sub-object-property-of)
	   (symmetricobjectproperty symmetric-object-property)
	   (transitiveobjectproperty transitive-object-property))
       for capitalized = (capitalize-by-hyphen worded)
       for entry = (list un worded capitalized third)
	 do
	 (setf (gethash un table) entry)
	 (setf (gethash worded table) entry)
	 (setf (gethash capitalized table) entry)
	 (and third (setf (gethash third table) entry))
	 )
    table))


(defparameter *owl2-manchesterish-function-syntax-terms*
 '((objectintersectionof and)
   (objectunionof or)
   (objectsomevaluesfrom some)
   (objectallvaluesfrom all)
   (objecthasvalue value)
   (equivalentclasses =)
   (subclassof <)
   (subobjectpropertyof p<)
   (object-property-chain o)
   (objectmincardinality min)
   (classassertion type)
   (objectmaxcardinality max)
   (objectexactcardinality exactly)
   (objectcomplementof not)
   (declaration is)))
   
(defun add-manchesterish-abbreviations ()
  "Write this:
 (with-ontology foo () 
   ((asq
     (= !probe (and !a (some !r !b)))
     (= !probe2 (and !a1 (some !r !b1)))
     (< !a1 !a)
     (< !b !b1)
     (type (and !probe2 (not !probe1)) !probeinstance))))

  Instead of this:

(with-ontology ont ()
  ((sub-class-of !a1 !a)
   (sub-class-of !b !b1)
   (equivalent-classes !probe (object-intersection-of !a (object-some-values-from !r !b)))
   (equivalent-classes !probe2 (object-intersection-of !a1 (object-some-values-from !r !b1)))
   (class-assertion (object-intersection-of !probe2 (object-complement-of !probe1)) !probeinstance)))
"
  (loop for (base abbrev) in *owl2-manchesterish-function-syntax-terms*
	do 
	   (setf (gethash abbrev *owl2-vocabulary-forms*) (list base))
	   (setf (gethash (intern (string abbrev) 'keyword) *owl2-vocabulary-forms*) (list base))))

(add-manchesterish-abbreviations)











