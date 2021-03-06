(in-package :cl-user)

;; from https://www.nlm.nih.gov/research/umls/knowledge_sources/metathesaurus/release/updated_sources.html
;; Columns re-arranged
;; 1. as coded in UMLS API
;; 2. for display to me
;; 3. full name
;; 4. "RSAB", whatever that stands for

(defvar *umls-sources*
  '(("CCS_10" "Clinical Classifications Software" "Clinical Classifications Software, 2016" "CCS_10_2016") 
    ("LNC-DE-AT" "LOINC" "LOINC, German, Austria Edition, 254" "LNC-DE-AT_254") 
    ("NANDA-I" "NANDA-I Taxonomy II" "NANDA-I Taxonomy II, 2015-2017" "NANDA-I_2015-2017") 
    ("ATC" "Anatomical Chemical" "Anatomical Therapeutic Chemical Classification System, ATC_2016_16_03_07" "ATC_2016_16_03_07") 
    ("CPT" "CPT" "Current Procedural Terminology, 2016" "CPT2016") 
    ("CVX" "Vaccines" "Vaccines Administered, 2016_01_04" "CVX2016_01_04") 
    ("GS" "Gold Standard Drug Database" "Gold Standard Drug Database, 2016_02_01" "GS_2016_02_01") 
    ("HCDT" "CDT" "HCPCS Version of Current Dental Terminology (CDT), 2016" "HCDT2016") 
    ("HCPCS" "HCPCS" "Healthcare Common Procedure Coding System, 2016" "HCPCS2016") 
    ("HCPT" "CPT" "HCPCS Version of Current Procedural Terminology (CPT), 2016" "HCPT2016") 
    ("HL7V3.0" "HL7" "HL7 Vocabulary Version 3.0, 2015_07" "HL7V3.0_2015_07") 
    ("HPO" "HPO" "Human Phenotype Ontology, 2016_01_13" "HPO2016_01_13") 
    ("ICD10CM" "ICD-10" "International Classification of Diseases, 10th Edition, Clinical Modification, 2016" "ICD10CM_2016") 
    ("ICD10PCS" "ICD-10-PCS" "ICD-10-PCS, 2016" "ICD10PCS_2016") 
    ("LNC-DE-CH" "LOINC" "LOINC, German, Switzerland Edition, 254" "LNC-DE-CH_254") 
    ("LNC-DE-DE" "LOINC" "LOINC, German, Germany Edition, 254" "LNC-DE-DE_254") 
    ("LNC-EL-GR" "LOINC" "LOINC, Greek, Greece Edition, 254" "LNC-EL-GR_254") 
    ("LNC-ES-AR" "LOINC" "LOINC, Spanish, Argentina Edition, 254" "LNC-ES-AR_254") 
    ("LNC-ES-CH" "LOINC" "LOINC, Spanish, Switzerland Edition, 254" "LNC-ES-CH_254") 
    ("LNC-ES-ES" "LOINC" "LOINC, Spanish, Spain Edition, 254" "LNC-ES-ES_254") 
    ("LNC-ET-EE" "LOINC" "LOINC, Estonian, Estonia Edition, 254" "LNC-ET-EE_254") 
    ("LNC-FR-BE" "LOINC" "LOINC, French, Belgium Edition, 254" "LNC-FR-BE_254") 
    ("LNC-FR-CA" "LOINC" "LOINC, French, Canada Edition, 254" "LNC-FR-CA_254") 
    ("LNC-FR-CH" "LOINC" "LOINC, French, Switzerland Edition, 254" "LNC-FR-CH_254") 
    ("LNC-FR-FR" "LOINC" "LOINC, French, France Edition, 254" "LNC-FR-FR_254") 
    ("LNC-IT-CH" "LOINC" "LOINC, Italian, Switzerland Edition, 254" "LNC-IT-CH_254") 
    ("LNC-IT-IT" "LOINC" "LOINC, Italian, Italy Edition, 254" "LNC-IT-IT_254") 
    ("LNC-KO-KR" "LOINC" "LOINC, Korean, Korea Edition, 254" "LNC-KO-KR_254") 
    ("LNC-NL-NL" "LOINC" "LOINC, Dutch, Netherlands Edition, 254" "LNC-NL-NL_254") 
    ("LNC-PT-BR" "LOINC" "LOINC, Portuguese, Brazil Edition, 254" "LNC-PT-BR_254") 
    ("LNC-RU-RU" "LOINC" "LOINC, Russian, Russia Edition, 254" "LNC-RU-RU_254") 
    ("LNC-TR-TR" "LOINC" "LOINC, Turkish, Turkey Edition, 254" "LNC-TR-TR_254") 
    ("LNC-ZH-CN" "LOINC" "LOINC, Chinese, China Edition, 254" "LNC-ZH-CN_254") 
    ("LNC" "LOINC" "LOINC, 254" "LNC254") 
    ("MDDB" "Master Drug Data Base" "Master Drug Data Base, 2016_01_27" "MDDB_2016_01_27") 
    ("MDR" "MedDRA" "Medical Dictionary for Regulatory Activities Terminology (MedDRA), 18.1" "MDR18_1") 
    ("MDRCZE" "MedDRA" "Medical Dictionary for Regulatory Activities Terminology (MedDRA), Czech Edition, 18.1" "MDRCZE18_1") 
    ("MDRDUT" "MedDRA" "Medical Dictionary for Regulatory Activities Terminology (MedDRA), Dutch Edition, 18.1" "MDRDUT18_1") 
    ("MDRFRE" "MedDRA" "Medical Dictionary for Regulatory Activities Terminology (MedDRA), French Edition, 18.1" "MDRFRE18_1") 
    ("MDRGER" "MedDRA" "Medical Dictionary for Regulatory Activities Terminology (MedDRA), German Edition, 18.1" "MDRGER18_1") 
    ("MDRHUN" "MedDRA" "Medical Dictionary for Regulatory Activities Terminology (MedDRA), Hungarian Edition, 18.1" "MDRHUN18_1") 
    ("MDRITA" "MedDRA" "Medical Dictionary for Regulatory Activities Terminology (MedDRA), Italian Edition, 18.1" "MDRITA18_1") 
    ("MDRJPN" "MedDRA" "Medical Dictionary for Regulatory Activities Terminology (MedDRA), Japanese Edition, 18.1" "MDRJPN18_1") 
    ("MDRPOR" "MedDRA" "Medical Dictionary for Regulatory Activities Terminology (MedDRA), Portuguese Edition, 18.1" "MDRPOR18_1") 
    ("MDRSPA" "MedDRA" "Medical Dictionary for Regulatory Activities Terminology (MedDRA), Spanish Edition, 18.1" "MDRSPA18_1") 
    ("MEDCIN" "MEDCIN" "MEDCIN, 3_2015_12_21" "MEDCIN3_2015_12_21") 
    ("MEDLINEPLUS" "MedlinePlus" "MedlinePlus Health Topics, 20151021" "MEDLINEPLUS_20151021") 
    ("MMSL" "Multum MediSource Lexicon" "Multum MediSource Lexicon, 2016_02_01" "MMSL_2016_02_01") 
    ("MMX" "Micromedex RED BOOK" "Micromedex RED BOOK, 2016_02_01" "MMX_2016_02_01") 
    ("MSH" "MeSH" "Medical Subject Headings, 2016_2016_02_26" "MSH2016_2016_02_26") 
    ("MSHCZE" "MeSH" "Czech translation of the Medical Subject Headings, 2016" "MSHCZE2016") 
    ("MSHFRE" "MeSH" "Thesaurus Biomedical Francais/Anglais (French translation of the Medical Subject Headings), 2016" "MSHFRE2016") 
    ("MSHGER" "MeSH" "German translation of the Medical Subject Headings, 2016" "MSHGER2016") 
    ("MSHITA" "MeSH" "Italian translation of the Medical Subject Headings, 2016" "MSHITA2016") 
    ("MSHNOR" "MeSH" "Medical Subject Headings Norwegian, 2016" "MSHNOR2016") 
    ("MSHPOR" "MeSH" "Descritores em Ciencias da Saude (Portuguese translation of the Medical Subject Headings), 2016" "MSHPOR2016") 
    ("MSHRUS" "MeSH" "Russian translation of the Medical Subject Headings, 2016" "MSHRUS2016") 
    ("MSHSCR" "MeSH" "Croatian translation of the Medical Subject Headings, 2016" "MSHSCR2016") 
    ("MSHSPA" "MeSH" "Descritores en Ciencias de la Salud (Spanish translation of the Medical Subject Headings), 2016" "MSHSPA2016") 
    ("MTHHH" "HCPCS Hierarchical" "Metathesaurus HCPCS Hierarchical Terms, 2016" "MTHHH2016") 
    ("MTHSPL" "FDA Product Labels" "Metathesaurus FDA Structured Product Labels, 2016_02_26" "MTHSPL_2016_02_26") 
    ("MVX" "Manufacturers of Vaccines" "Manufacturers of Vaccines, 2015_07_27_16_02_24" "MVX2015_07_27_16_02_24") 
    ("NCI" "NCI Thesaurus" "NCI Thesaurus, 2015_09D" "NCI2015_09D") 
    ("NCI_BRIDG" "BRIDG" "Biomedical Research Integrated Domain Group Model, 1509D" "NCI2015_BRIDG_1509D") 
    ("NCI_BioC" "BioCarta" "BioCarta online maps of molecular pathways, adapted for NCI use, 1509D" "NCI2015_BioC_1509D") 
    ("NCI_CDC" "CDC" "U.S. Centers for Disease Control and Prevention, 1509D" "NCI2015_CDC_1509D") 
    ("NCI_CDISC" "CDISC" "Clinical Data Interchange Standards Consortium, 1509D" "NCI2015_CDISC_1509D") 
    ("NCI_CRCH" "Nutrition Terminology" "Cancer Research Center of Hawaii Nutrition Terminology, 1509D" "NCI2015_CRCH_1509D") 
    ("NCI_CTCAE" "Adverse Events" "Common Terminology Criteria for Adverse Events, 1509D" "NCI2015_CTCAE_1509D") 
    ("NCI_CTEP-SDC" "Simple Disease Classification," "Therapy Evaluation Program - Simple Disease Classification, 1509D" "NCI2015_CTEP-SDC_1509D") 
    ("NCI_CareLex" "CareLex" "Content Archive Resource Exchange Lexicon, 1509D" "NCI2015_CareLex_1509D") 
    ("NCI_DCP" "NCI" "NCI Division of Cancer Prevention Program, 1509D" "NCI2015_DCP_1509D") 
    ("NCI_DICOM" "DICOM" "Digital Imaging Communications in Medicine, 1509D" "NCI2015_DICOM_1509D") 
    ("NCI_DTP" "NCI" "NCI Developmental Therapeutics Program, 1509D" "NCI2015_DTP_1509D") 
    ("NCI_FDA" "FDA" "U.S. Food and Drug Administration, 1509D" "NCI2015_FDA_1509D") 
    ("NCI_ICH" "International Conference on Harmonization" "International Conference on Harmonization, 1509D" "NCI2015_ICH_1509D") 
    ("NCI_JAX" "JAX Mouse" "Jackson Laboratories Mouse Terminology, adapted for NCI use, 1509D" "NCI2015_JAX_1509D") 
    ("NCI_KEGG" "KEGG" "KEGG Pathway Database, 1509D" "NCI2015_KEGG_1509D") 
    ("NCI_NCI-GLOSS" "NCI Cancer Terms" "NCI Dictionary of Cancer Terms, 1509D" "NCI2015_NCI-GLOSS_1509D") 
    ("NCI_NCI-HL7" "NCI HL7" "NCI Health Level 7, 1509D" "NCI2015_NCI-HL7_1509D") 
    ("NCI_NCPDP" "Prescription Drug" "National Council for Prescription Drug Programs, 1509D" "NCI2015_NCPDP_1509D") 
    ("NCI_NICHD" "Child Health and Human Development" "National Institute of Child Health and Human Development, 1509D" "NCI2015_NICHD_1509D") 
    ("NCI_PID" "Pathway Interaction Database" "National Cancer Institute Nature Pathway Interaction Database, 1509D" "NCI2015_PID_1509D") 
    ("NCI_RENI" "Registry Nomenclature" "Registry Nomenclature Information System, 1509D" "NCI2015_RENI_1509D") 
    ("NCI_UCUM" "Units of Measure" "Unified Code for Units of Measure, 1509D" "NCI2015_UCUM_1509D") 
    ("NCI_ZFin" "Zebrafish" "Zebrafish Model Organism Database, 1509D" "NCI2015_ZFin_1509D") 
    ("NDDF" "FDB MedKnowledge" "FDB MedKnowledge (formerly NDDF Plus), 2016_02_03" "NDDF_2016_02_03") 
    ("NDFRT" "NDFRT" "National Drug File, 2016_03_07" "NDFRT_2016_03_07") 
    ("NDFRT_FDASPL" "NDFRT" "National Drug File - FDASPL, 2016_03_07" "NDFRT_FDASPL_2016_03_07") 
    ("NDFRT_FMTSME" "NDFRT" "National Drug File - FMTSME, 2016_03_07" "NDFRT_FMTSME_2016_03_07") 
    ("RXNORM" "RxNorm" "RxNorm Vocabulary, 15AB_160307F" "RXNORM_15AB_160307F") 
    ("SCTSPA" "SNOMED" "SNOMED Clinical Terms, Spanish Language Edition, 2015_10_31" "SCTSPA_2015_10_31") 
    ("SNOMEDCT_US" "SNOMED" "US Edition of SNOMED CT, 2016_03_01" "SNOMEDCT_US_2016_03_01") 
    ("SNOMEDCT_VET" "Veterinary SNOMED" "Veterinary Extension to SNOMED CT, 2015_10_01" "SNOMEDCT_VET_2015_10_01") 
    ("UMD" "UMDNS: product category" "UMDNS: product category thesaurus, 2016" "UMD2016") 
    ("VANDF" "VA Drug File" "Veterans Health Administration National Drug File, 2016_01_21" "VANDF_2016_01_21")
    ;; not in the doc, but used as a code
    ("SNMI" "SNMI" "SNMI")
    ("RCD" "Read Codes")
    ("MSHPOL" "MeSH" "Polish translation of MeSH")
    ("MSHSWE" "MeSH" "SWEDISH translation of MeSH")
    ("CSP" "Crisp" "Computer Retrieval of Information on Scientific Projects (CRISP) Thesaurus")
    ("OMS" "Omaha" "Omaha System")
    ("CHV" "Consumer" "Consumer Health Vocabulary Source Information")
    ("AOD" "Alcohol/Drug"  "Alcohol and Other Drug Thesaurus")
    ("PSY" "Psych" "Psychological Index Terms")
    ("SNM" "SNOMED" "SNOMED 1982")
    ("ICNP" "Nurse" "The International Classification for Nursing Practice")
    ("OMIM" "Online Mendelian Inheritance in Man")
    ("GO" "GO" "Gene Ontology")
    ("CDISC" "CDISC" "Clinical Data Interchange Standards Consortium")
    ("MSHFIN" "MeSH" "MeSH Finnish Translation")
    ("LCH" "Congress" "Library of Congress Subject Headings")
    ("LCH_NW" "Congress" "Library of Congress Subject Headings, Northwestern University subset")
    ("MSHJPN" "MeSH" "MeSH Japanese Translation")
    ("FMA" "FMA" "Foundational Model of Anatomy")
    ("MTH" "Meta" "Metathesaurus Names")
    ))

