----Total patients for each given postcode area. Patient counts should be reviewed by gender.
--SELECT postcode, count(patient_id) as total_patients--, gender
--FROM patient
--GROUP BY postcode--, gender
--ORDER BY total_patients DESC, postcode;--, gender;

WITH Asthma_Patients -- Current diagnosis of asthma, current observation in their medical record with relevant clinical codes from asthma refset (refsetid 999012891000230104), and not resolved --
AS
(
	SELECT C.refset_simple_id, C.code_id AS Asthma, C.snomed_concept_id, O.emis_original_term, O.registration_guid
	FROM clinical_codes C
	INNER JOIN observation O ON C.snomed_concept_id = O.snomed_concept_id -- Joins clinical code and observation tables to return matching data based on snomed_concept_id
	WHERE refset_simple_id = 999012891000230104 -- Filters by Asthma patients
	AND emis_original_term != 'Asthma resolved' -- Excludes asthma resolved and only returns not resolved
	GROUP BY refset_simple_id, code_id, C.snomed_concept_id, emis_original_term, registration_guid -- Grouping done to exclude dups
),

Prescribed_Medication -- Have been prescribed medication from Formoterol Fumarate, Salmeterol Xinafoate, Vilanterol, Indacaterol, Olodaterol or any medication containing these ingredients in the last 30 years:
AS
( 
	SELECT C.code_id, C.snomed_concept_id, C.emis_term, M.emis_original_term, M.registration_guid
	FROM clinical_codes C
	FULL JOIN medication M on C.snomed_concept_id = M.snomed_concept_id -- Joins clinical code and medication tables to return matching data based on snomed_concept_id
	WHERE (C.snomed_concept_id = 129490002 OR C.snomed_concept_id = 108606009 OR C.snomed_concept_id = 702408004 OR C.snomed_concept_id = 702801003 OR C.snomed_concept_id = 704459002) -- Filters by these 5 codes
	OR (M.emis_original_term like '%formoterol%' OR M.emis_original_term like '%salmeterol%' OR M.emis_original_term like '%Vilanterol%' OR M.emis_original_term like '%Indacaterol%' OR M.emis_original_term like '%Olodaterol%') -- And any medications including these ingredients
	--AND --Add date, 30 years
	GROUP BY C.code_id, C.snomed_concept_id, C.emis_term, M.emis_original_term, M.registration_guid -- Grouping done to exclude dups
),

Smoker -- CTE to exclude any current smokers
AS
(
	SELECT refset_simple_id, code_id AS Asthma, emis_original_term, registration_guid, O.snomed_concept_id
	FROM clinical_codes C
	INNER JOIN observation O ON C.snomed_concept_id = O.snomed_concept_id
	WHERE refset_simple_id != 999004211000230104 -- Filters by smokers i.e. exluding current smokers
	--AND emis_original_term != 'Current smoker' -- Filters by smokers 
	GROUP BY refset_simple_id, code_id, emis_original_term, registration_guid, O.snomed_concept_id
),

Weight_U40Kg -- CTE to exclude anyone currently less than 40kg
AS
(
	SELECT O.snomed_concept_id, O.emis_original_term, O.registration_guid
	FROM clinical_codes C
	INNER JOIN observation O on C.snomed_concept_id = O.snomed_concept_id 
	WHERE O.snomed_concept_id != 27113001 -- filters to exclude anyone under 40kg
	GROUP BY O.snomed_concept_id, O.emis_original_term, O.registration_guid
),

COPD_diagnosis -- CTE to exclude anyone that currently has COPD diagnosis
AS
(
	SELECT C.refset_simple_id, C.snomed_concept_id, O.emis_original_term, O.registration_guid
	FROM clinical_codes C
	INNER JOIN observation O ON C.snomed_concept_id = O.snomed_concept_id
	WHERE refset_simple_id != 999011571000230107 -- Filters out any patient that has COPD Diagnosis
	GROUP BY refset_simple_id, C.snomed_concept_id, emis_original_term, O.registration_guid
) 

-- Outer Query to join all the CTEs for final results
SELECT A.snomed_concept_id, P.Registration_guid AS Registration_Id, P.Patient_id, P.patient_givenname +' '+ patient_surname AS Fullname, P.postcode, P.age, P.gender, A.emis_original_term
FROM patient P
JOIN Asthma_Patients A ON P.Registration_guid = A.registration_guid
JOIN Prescribed_Medication PM ON A.registration_guid = PM.registration_guid
JOIN Smoker S ON PM.registration_guid = S.registration_guid
JOIN Weight_U40Kg W ON S.registration_guid = W.registration_guid
JOIN COPD_diagnosis CD ON W.registration_guid = CD.registration_guid
--WHERE P.postcode = 'LS99 9ZZ' OR postcode IS NULL
GROUP BY A.snomed_concept_id, P.Registration_guid, P.Patient_id, P.patient_givenname +' '+ patient_surname, P.postcode, P.age, P.gender, A.emis_original_term
ORDER BY p.postcode;