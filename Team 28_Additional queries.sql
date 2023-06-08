--Additional Questions
/*1) Find the list of all the patients with fullname whose RPE start and RPE end 
shows Moderate intensity.*/

 SELECT P."Patient_ID",P."Firstname" || ' ' || P."Lastname" AS "Fullname",W."Gait_RPE_Start ",W."Gait_RPE_End "
 FROM public."Patients" P
 JOIN public."Walking_Test" W ON W."WalkTest_ID" = P."WalkTest_ID"
 WHERE W."Gait_RPE_Start " BETWEEN 4 AND 6
 AND W."Gait_RPE_End " BETWEEN 4 AND 6
 
--2) Show the percentage of MALE:FEMALE

SELECT
    ROUND(COUNT(CASE WHEN G."Gender" = 'Male' THEN 1 END)::decimal / COUNT(*) * 100, 2) AS "Male Percentage",
    ROUND(COUNT(CASE WHEN G."Gender" = 'Female' THEN 1 END)::decimal / COUNT(*) * 100, 2) AS "Female Percentage"
FROM public."Patients" P
JOIN public."Gender" G ON P."Gender_ID" = G."Gender_ID";

--3) Patient distribution across fasting_glucose
SELECT
    ROUND(COUNT(CASE WHEN LT."Fasting_Glucose" < 70 THEN 1 END) * 100.0 / COUNT(*), 2) AS "Hypoglycemia (%)",
    ROUND(COUNT(CASE WHEN LT."Fasting_Glucose" >= 70 AND LT."Fasting_Glucose" <= 100 THEN 1 END) * 100.0 / COUNT(*), 2) AS "Normal (%)",
    ROUND(COUNT(CASE WHEN LT."Fasting_Glucose" > 100 AND LT."Fasting_Glucose" <= 120 THEN 1 END) * 100.0 / COUNT(*), 2) AS "Prediabetic (%)",
    ROUND(COUNT(CASE WHEN LT."Fasting_Glucose" > 120 THEN 1 END) * 100.0 / COUNT(*), 2) AS "Diabetic (%)"
FROM public."Patients" P
JOIN public."Lab_Test" LT ON LT."Patient_ID" = P."Patient_ID"

--4) Percentage of male and female who have diabetics

SELECT
    ROUND(COUNT(CASE WHEN G."Gender" = 'Male' AND LT."Fasting_Glucose" > 120 THEN 1 END) * 100.0 / COUNT(CASE WHEN G."Gender" = 'Male' THEN 1 END), 2) AS "Male Diabetics (%)",
    ROUND(COUNT(CASE WHEN G."Gender" = 'Female' AND LT."Fasting_Glucose" > 120 THEN 1 END) * 100.0 / COUNT(CASE WHEN G."Gender" = 'Female' THEN 1 END), 2) AS "Female Diabetics (%)"
FROM public."Patients" P
JOIN public."Gender" G ON P."Gender_ID" = G."Gender_ID"
JOIN public."Lab_Test" LT ON LT."Patient_ID" = P."Patient_ID"

/* 5) A study to check how many patients who have abnormal lipid profile have been diagoned with diabetics*/

WITH Diabetic_Patients AS (
  SELECT LL."Patient_ID"
  FROM public."Lipid_Lab_Test" LL
  WHERE LL."Fasting_HDL" < 50 AND LL."Fasting_LDL" > 130 AND LL."Fasting_Triglyc" > 150
),
Sugar_Status AS (
  SELECT LL."Patient_ID",
         CASE
           WHEN LT."Insulin" < 2.6 THEN 'Low Sugar'
           WHEN LT."Insulin" > 24.9 THEN 'High Sugar'
           ELSE 'Normal'
         END AS "Sugar_Status"
  FROM public."Lab_Test" LT
  JOIN public."Lipid_Lab_Test" LL ON LT."Patient_ID" = LL."Patient_ID"
)
SELECT "Sugar_Status", COUNT(*) AS "Count",
       ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM public."Lipid_Lab_Test" ), 2) AS "Percentage"
FROM Sugar_Status
GROUP BY "Sugar_Status"
ORDER BY "Sugar_Status";

--6) check how many in men and woman are in risk for liver disorder by checking creatine albumin ratio

SELECT G."Gender",COUNT(*) AS "Patient_Count"
FROM public."Patients" P
JOIN public."Link_Reference" LR ON P."Link_Reference_ID" = LR."Link_Reference_ID"
JOIN public."Urine_Test" U ON LR."Urine_ID" = U."Urine_ID"
JOIN public."Gender" G ON P."Gender_ID" = G."Gender_ID"
WHERE (G."Gender" = 'Male' AND U."Creatinine" / U."Albumin" > 17)
   OR (G."Gender" = 'Female' AND U."Creatinine" / U."Albumin" > 25)
GROUP BY G."Gender";

--7) Relation between sugar and dementia

SELECT 
  COUNT(*) AS "Diabetic_Patients",
  COUNT(CASE WHEN VM."RCFT_IR" > 71 OR VM."TM" > 42 OR VM."Clock" <= 2 OR MC."GDS" >= 15 THEN 1 END) AS "Diabetic_Patients_With_Dementia",
  ROUND((COUNT(CASE WHEN VM."RCFT_IR" > 71 OR VM."TM" > 42 OR VM."Clock" <= 2 OR MC."GDS" >= 15 THEN 1 END) * 100.0) / COUNT(*), 2) AS "Percentage"
FROM public."Lab_Test" LT
JOIN public."Link_Reference" LR ON LT."Lab_ID" = LR."Lab_ID"
JOIN public."Visual/Motor_Cog" VM ON LR."VM_ID" = VM."VM_ID"
JOIN public."Memory_Cognitive" MC ON LR."MC_ID" = MC."MC_ID"
WHERE LT."Fasting_Glucose" > 120;

--8) Yearwise study of which age has diabetes.

SELECT
  EXTRACT(YEAR FROM P."Visit_Date") AS "Year",
  CONCAT((FLOOR(P."Age" / 10) * 10), '-', (FLOOR(P."Age" / 10) * 10 + 10)) AS "Age_Group",
  COUNT(*) AS "Diabetic_Count"
FROM public."Lab_Test" LT
JOIN public."Patients" P ON LT."Patient_ID" = P."Patient_ID"
WHERE LT."Fasting_Glucose"> 120
GROUP BY "Year", "Age_Group"
ORDER BY "Year", "Age_Group";

/*9)What is the distribution of diabetic patients based on their age groups and the corresponding years 
of their lab test visits, considering only those patients whose fasting glucose levels are above 120?*/

SELECT "Year", "Age_Group", "Diabetic_Count"
FROM (
  SELECT
    EXTRACT(YEAR FROM P."Visit_Date") AS "Year",
    CONCAT((FLOOR(P."Age" / 10) * 10), '-', (FLOOR(P."Age" / 10) * 10 + 10)) AS "Age_Group",
    COUNT(*) AS "Diabetic_Count",
    ROW_NUMBER() OVER (PARTITION BY EXTRACT(YEAR FROM P."Visit_Date") ORDER BY COUNT(*) DESC) AS rn
  FROM public."Lab_Test" LT
  JOIN public."Patients" P ON LT."Patient_ID" = P."Patient_ID"
  WHERE LT."Fasting_Glucose" > 120
  GROUP BY "Year", "Age_Group"
) AS subquery
WHERE rn = 1
ORDER BY "Year";


--10) Show the First_Visit_Date to Last_Visit_Date

SELECT
  MIN("Visit_Date") AS "First_Visit_Date",
  MAX("Visit_Date") AS "Last_Visit_Date"
FROM public."Patients";

--11)Show distribution of patients across fasting_glucose

SELECT 'Hypoglycemia' AS Condition,
    ROUND(COUNT(CASE WHEN LT."Fasting_Glucose" < 70 THEN 1 END) * 100.0 / COUNT(*), 2) AS Percentage
FROM public."Patients" P
JOIN public."Lab_Test" LT ON LT."Patient_ID" = P."Patient_ID"
UNION
SELECT 'Normal' AS Condition,
    ROUND(COUNT(CASE WHEN LT."Fasting_Glucose" >= 70 AND LT."Fasting_Glucose" <= 100 THEN 1 END) * 100.0 / COUNT(*), 2) AS Percentage
FROM public."Patients" P
JOIN public."Lab_Test" LT ON LT."Patient_ID" = P."Patient_ID"
UNION
SELECT 'Prediabetic' AS Condition,
    ROUND(COUNT(CASE WHEN LT."Fasting_Glucose" > 100 AND LT."Fasting_Glucose" <= 120 THEN 1 END) * 100.0 / COUNT(*), 2) AS Percentage
FROM public."Patients" P
JOIN public."Lab_Test" LT ON LT."Patient_ID" = P."Patient_ID"
UNION
SELECT 'Diabetic' AS Condition,
    ROUND(COUNT(CASE WHEN LT."Fasting_Glucose" > 120 THEN 1 END) * 100.0 / COUNT(*), 2) AS Percentage
FROM public."Patients" P
JOIN public."Lab_Test" LT ON LT."Patient_ID" = P."Patient_ID";

/*12) What are the dominant age groups among diabetic patients for each year, considering only those patients 
whose fasting glucose levels are above 120?*/

SELECT "Year", "Age_Group", "Diabetic_Count"
FROM (
  SELECT
    EXTRACT(YEAR FROM P."Visit_Date") AS "Year",
    CONCAT((FLOOR(P."Age" / 10) * 10), '-', (FLOOR(P."Age" / 10) * 10 + 10)) AS "Age_Group",
    COUNT(*) AS "Diabetic_Count",
    ROW_NUMBER() OVER (PARTITION BY EXTRACT(YEAR FROM P."Visit_Date") ORDER BY COUNT(*) DESC) AS rn
  FROM public."Lab_Test" LT
  JOIN public."Patients" P ON LT."Patient_ID" = P."Patient_ID"
  WHERE LT."Fasting_Glucose" > 120
  GROUP BY "Year", "Age_Group"
) AS subquery
WHERE rn = 1
ORDER BY "Year";

--13. Get the average blood pressure readings for male and female patients

SELECT g."Gender", AVG(bp."24Hr_Day_SBP") "Average Day SBP",AVG(bp."24Hr_Day_DBP") "Average Day DBP",
	  AVG("24Hr_Night_SBP") "Average Night SBP",AVG("24Hr_Night_DBP") "Average Night DBP"
FROM public."Patients" p, public."Gender" g, public."Blood_Pressure" bp
WHERE p."Patient_ID"=bp."Patient_ID"
AND p."Gender_ID"=g."Gender_ID"
GROUP BY g."Gender";

--14. Calculate the average cholesterol level for each age group

SELECT CASE
         WHEN p."Age" <= 55 THEN '50-55'
         WHEN p."Age" <= 60 THEN '56-60'
         WHEN p."Age" <= 65 THEN '61-65'
         WHEN p."Age" <= 70 THEN '66-70'
         ELSE '70+'
       END AS "Age_Group",
       ROUND(AVG(llt."Fasting_Cholestrol")::numeric,2) AS "Average_Cholesterol"
FROM public."Lipid_Lab_Test" llt,public."Patients" p
WHERE p."Patient_ID"=llt."Patient_ID"
GROUP BY "Age_Group"
ORDER BY "Age_Group";

--15. Get the latest lab test results for each patient:

SELECT p."Patient_ID",p."Firstname",p."Lastname",l."Lab_names",
       lt."WBC",lt."RBC",lt."Hgb",lt."Hct",lt."Platelets",lt."Hb_A1C",lt."Fasting_Glucose",lt."Insulin"
FROM public."Patients" p,public."Lab_Visit" l,public."Lab_Test" lt,public."Link_Reference" lr
WHERE p."Patient_ID"=lt."Patient_ID" AND lr."Lab_visit_ID"=l."Lab_visit_ID"
AND l."Lab_Visit_Date"=
(SELECT MAX("Lab_Visit_Date") FROM public."Lab_Visit");


--16. Get the average fasting glucose levels for diabetic patients by age group


SELECT CASE 
    WHEN p."Age" BETWEEN 51 AND 55 THEN '51-55'
    WHEN p."Age" BETWEEN 56 AND 60 THEN '56-60'
    WHEN p."Age" BETWEEN 61 AND 65 THEN '61-65'
	WHEN p."Age" BETWEEN 66 AND 70 THEN '61-65'
    ELSE 'Above 70'
 END AS "Age Group",ROUND(AVG(lt."Fasting_Glucose"),2)"Average Fasting Glucose"
FROM public."Patients" p,public."Lab_Test" lt
WHERE p."Patient_ID"=lt."Patient_ID"
AND p."Patient_ID" in
(SELECT "Patient_ID" FROM public."Patients" WHERE"Group_ID" in
(SELECT"Group_ID" FROM public."Group" WHERE "Group" = 'DM' ))
GROUP BY "Age Group" ORDER BY "Age Group" ;

--17. Get the count of male and female diabetic patients:

SELECT gr."Gender",count(*) As "Diabetic Patients" FROM public."Gender" gr,public."Group" gp, public."Patients" p
WHERE p."Group_ID"=gp."Group_ID" AND p."Gender_ID"=gr."Gender_ID"
AND gp."Group"='DM'
GROUP BY gr."Gender"

--18) Write a query to return the last 2 digits of the Fasting_Cholestrol
select right(cast("Fasting_Cholestrol" as text),2) 
from public."Lipid_Lab_Test";

--19)Write a query to find how many unique patients there are in public."Blood_Pressure".
select count(distinct "Patient_ID") as count_of_unique_patient 
from public."Blood_Pressure";

--20)Write a query to show the count of patients as per Race.
select "Race", count(distinct "Patient_ID") as Patients 
from public."Patients"as pa  
inner join public."Race" as r on pa."Race_ID" = r."Race_ID"
group by "Race";

--21)Write a query using ARRAY_AGG function to get a list of Patient names and Race.
SELECT ARRAY_AGG(CONCAT(P."Firstname",' ',P."Lastname") || ' ' || R. "Race") 
FROM  public."Patients" P, public."Race" R 
where P."Race_ID" =R."Race_ID" 
GROUP BY  P."Patient_ID" ORDER BY P."Patient_ID";

--22)Write a query to get the list of patient ids which are not there in Lab_Test.
SELECT DISTINCT P."Patient_ID" FROM "Patients" P 
WHERE P."Patient_ID" NOT IN(SELECT LT."Patient_ID" 
FROM public."Lab_Test" LT);

--23)Write a query to find the 7 characters of Firstname in lower cases.
SELECT LOWER(LEFT("Firstname",5)) as FIRST_5_character FROM public."Patients";

--24)List all the Patients whose Hgb is above the actual range.
select concat(pt."Firstname"||' '||pt."Lastname") Fullname, pt."Link_Reference_ID",lt."Hgb" 
from "Patients" pt 
join "Link_Reference" lr on pt."Link_Reference_ID"=lr."Link_Reference_ID" 
join "Lab_Test" lt on lt."Lab_ID"=lr."Lab_ID"
where lt."Hgb">15;

--25)Write a query using the Dense_Rank function for Patients table.
Select "Patient_ID","Group_ID","Opthal_ID",DENSE_RANK() 
OVER(PARTITION BY "Opthal_ID" ORDER BY "WalkTest_ID")Walk_Rank
FROM Public."Patients";

--26) heart rate across age groups
SELECT
  CONCAT((FLOOR(P."Age" / 5) * 5), '-', (FLOOR(P."Age" / 5) * 5 + 4)) AS "Age_Group",
  ROUND(AVG((BP."24Hr_Day_HR" + BP."24Hr_Night_HR") / 2)::numeric, 2) AS "Average_Heart_Rate"
FROM public."Blood_Pressure" BP
JOIN public."Patients" P ON P."BP_ID" = BP."BP_ID"
GROUP BY CONCAT((FLOOR(P."Age" / 5) * 5), '-', (FLOOR(P."Age" / 5) * 5 + 4))
ORDER BY "Age_Group";

--27)percentage distribution of race
SELECT R."Race",COUNT(*) AS "Count",
  ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM public."Patients"), 2) AS "Percentage"
FROM public."Patients" P
JOIN public."Race" R ON P."Race_ID" = R."Race_ID"
GROUP BY R."Race"
ORDER BY R."Race";

--28)Bar chart to show count of Patients of each race.
 Select COUNT("Patient_ID") as "Patient","Race" from "Patients"
inner join "Race" ON "Patients"."Race_ID" ="Race"."Race_ID"
group by "Race". "Race_ID";

--29. Create a bar chart for  average fasting glucose levels for diabetic patients by age group:

SELECT CASE 
    WHEN p."Age" BETWEEN 51 AND 55 THEN '51-55'
    WHEN p."Age" BETWEEN 56 AND 60 THEN '56-60'
    WHEN p."Age" BETWEEN 61 AND 65 THEN '61-65'
	WHEN p."Age" BETWEEN 66 AND 70 THEN '61-65'
    ELSE 'Above 70'
 END AS "Age Group",ROUND(AVG(lt."Fasting_Glucose"),2)"Average Fasting Glucose"
FROM public."Patients" p,public."Lab_Test" lt
WHERE p."Patient_ID"=lt."Patient_ID"
AND p."Patient_ID" in
(SELECT "Patient_ID" FROM public."Patients" WHERE"Group_ID" in
(SELECT"Group_ID" FROM public."Group" WHERE "Group" = 'DM' ))
GROUP BY "Age Group" ORDER BY "Age Group" ;

--30. Create a line chart to show how Day HR changes with Night HR
SELECT * from public."Blood_Pressure";
 -- In graphic visuallizer,choose Graph type as Line chart and Day HR and Night HR in X and Y axis respectively

--31. Show relationship between fasting glucose and Insulin visually
SELECT * from public."Lab_Test";
-- In graphic visualizer, choose Graph Type as Bar chart, Fasting Glucose in X axis and Insulin in Y axis

--32. Create a pie chart to show male and female diabetic patients
SELECT gr."Gender",count(*) As "Diabetic Patients" FROM public."Gender" gr,public."Group" gp, public."Patients" p
WHERE p."Group_ID"=gp."Group_ID" AND p."Gender_ID"=gr."Gender_ID"
AND gp."Group"='DM'
GROUP BY gr."Gender";

--33. Calculate the average Hemoglobin A1C level for diabetic patients and non diabetic patients
SELECT g."Group",ROUND(AVG(lt."Hb_A1C")::numeric,2) As "Avg Hemoglobin A1C level"  FROM public."Lab_Test" lt,public."Patients" p,public."Group" g
WHERE lt."Patient_ID" = p."Patient_ID"
AND p."Group_ID"=g."Group_ID"
GROUP BY g."Group";


--34.Find patients with high blood pressure
SELECT DISTINCT CONCAT(p."Firstname", ' ', p."Lastname") AS "Patients with high blood pressure"
FROM public."Patients" p
JOIN public."Blood_Pressure" bp ON p."Patient_ID" = bp."Patient_ID"
WHERE (bp."24Hr_Day_SBP" > 135 AND bp."24Hr_Day_DBP" > 85) 
   OR (bp."24Hr_Night_SBP" > 120 AND bp."24Hr_Night_DBP" > 70);


--35.Calculate the average Hemoglobin A1C level for diabetic patients:
SELECT ROUND(AVG(lt."Hb_A1C"),2) FROM public."Lab_Test" lt,public."Patients" p,public."Group" g
WHERE lt."Patient_ID" = p."Patient_ID"
AND p."Group_ID"=g."Group_ID"
GROUP BY g."Group";

-- 36. Calculate number of patients in each Diabetic Category
Calculate number of patients in each Diabetic Category
SELECT COUNT(*),CASE
WHEN "Fasting_Glucose" < 70 THEN 'HYPOGLYCEMIA'
WHEN "Fasting_Glucose" BETWEEN 70 AND 100 THEN 'NORMAL'
WHEN "Fasting_Glucose" BETWEEN 100 AND 120 THEN 'PREDIABETIC'
WHEN "Fasting_Glucose" > 120 THEN 'Diabetic' END AS "Diabetic Status"
FROM public."Lab_Test" 
WHERE "Fasting_Glucose" IS NOT NULL
GROUP BY "Diabetic Status"

--37. Create a bar chart for diabetic status of patients
SELECT * FROM public."Lab_Test"

--38. Write a query to find the WBC level of patients
SELECT COUNT("Patient_ID") AS "PATIENT COUNT",
CASE WHEN "WBC" <4.5 THEN 'LEUKOPENIA'
     WHEN "WBC" BETWEEN 4.5 AND 11 THEN 'NORMAL'
	 WHEN "WBC" >11 THEN 'LEUKOCYTOSIS' END AS "WBC Condition"
FROM public."Lab_Test" 
WHERE "WBC" IS NOT NULL
GROUP BY "WBC Condition"

--39. Create a bar chart to show abnormality in WBC count

-- In graphic Visualizer, select Graph type as Bar,X axis as WBC Cndition, Patient Count for Y Axis
--and Generate

--41. Create a visualization to find patients with normal and abnormal platelet range
SELECT 
CASE WHEN lt."Platelets" BETWEEN 150 AND 450 THEN 'Normal'
ELSE 'Abnormal'
END As "Platelets Range",count(*)
FROM public."Lab_Test" lt
JOIN public."Patients" p ON p."Patient_ID"=lt."Patient_ID"
GROUP BY "Platelets Range";

-- 41. Create a visualization to find patients with normal and abnormal platelet range
SELECT 
CASE WHEN lt."Platelets" BETWEEN 150 AND 450 THEN 'Normal'
ELSE 'Abnormal'
END As "Platelets Range",count(*)
FROM public."Lab_Test" lt
JOIN public."Patients" p ON p."Patient_ID"=lt."Patient_ID"
GROUP BY "Platelets Range";

--42. Write a query to find number of patients in BMI category

SELECT 
CASE WHEN "BMI" < 18.5 THEN 'Underweight'
WHEN "BMI" BETWEEN 18.5 AND 24.9 THEN 'Normal'
WHEN "BMI" BETWEEN 25 AND 29.9 THEN 'Overweight'
ELSE 'OBESE' END AS "BMI Category",COUNT(*)
FROM public."Patients"
GROUP BY "BMI Category";

--43. Find number of diabetic patients who are not in normal weight
SELECT COUNT(*)As "ABNORMAL WEIGHT DIABETIC PATIENTS" FROM public."Patients" p,public."Group" gp
WHERE p."Group_ID"=gp."Group_ID"
AND gp."Group"='DM'
AND p."BMI">24.9;

--44. Find male and female patients who are over weight
SELECT COUNT(*)As "Overweight Patients", g."Gender" FROM public."Patients" p, public."Gender" g
WHERE p."Gender_ID"=g."Gender_ID"
AND p."BMI">24.9
GROUP BY g."Gender"

--45. WRITE A QUERY TO FIND OUT  PATIENT NAME ,WHO HAS DEMENTIA/COGNITIVE IMPAIREMENT

SELECT CONCAT (PT."Firstname",' ',PT."Lastname")
FROM PUBLIC."Visual/Motor_Cog" VM
JOIN PUBLIC."Link_Reference" LR ON LR."VM_ID" = VM."VM_ID"
JOIN PUBLIC."Patients" PT ON PT."Link_Reference_ID" = LR."Link_Reference_ID"
WHERE VM."TM" >= 42;

--46. Create a pie chart to show overweight patients by race
SELECT COUNT(*) As "Overweight Patients",r."Race" 
FROM public."Race" r,public."Patients" p
WHERE p."Race_ID"=r."Race_ID" 
AND p."BMI"> 24.9
GROUP BY r."Race";

--47)Return the version
SELECT VERSION();

--48) Average heart rate on age bin
SELECT
  CONCAT((WIDTH_BUCKET(p."Age", 0, 100, 20) - 1) * 5, ' - ', WIDTH_BUCKET(p."Age", 0, 100, 20) * 5 - 1) AS age_range,
  CAST(AVG((bp."24Hr_Day_HR" + bp."24Hr_Night_HR") / 2.0) AS DECIMAL(10, 2)) AS avg_HR
FROM public."Patients" p
JOIN public."Blood_Pressure" bp ON p."BP_ID" = bp."BP_ID"
GROUP BY WIDTH_BUCKET(p."Age", 0, 100, 20)
ORDER BY WIDTH_BUCKET(p."Age", 0, 100, 20);

--49) Average heart rate on age bin pipe chart
SELECT 
CONCAT((WIDTH_BUCKET(p."Age", 0, 100, 20) - 1) * 5, ' - ', WIDTH_BUCKET(p."Age", 0, 100, 20) * 5 - 1) AS age_range,
COUNT (*) AS PATIENT_COUNT 
FROM PUBLIC."Patients" P
GROUP BY WIDTH_BUCKET(p."Age", 0, 100, 20)
ORDER BY age_range ASC;

-- 50) HCT Conditions mapped
SELECT P."Patient_ID",
  CASE
    WHEN G."Gender" = 'Male' AND LT."Hct" < 41 THEN 'ANEMIA'
    WHEN G."Gender" = 'Male' AND LT."Hct" >=41 AND LT."Hct" <= 50 THEN 'NORMAL'
    WHEN G."Gender" = 'Male' AND LT."Hct" > 50 THEN 'High Hematocrit'
    WHEN G."Gender" = 'Female' AND LT."Hct" <36 THEN 'ANEMIA'
    WHEN G."Gender" = 'Female' AND LT."Hct" >=36 AND LT."Hct" <= 48 THEN 'NORMAL'
    WHEN G."Gender" = 'Female' AND LT."Hct" > 48 THEN 'High Hematocrit'
  END AS "Hematocrit"
FROM public."Lab_Test" LT
JOIN public."Patients" P ON P."Patient_ID" = LT."Patient_ID"
JOIN public."Gender" G ON G."Gender_ID" = P."Gender_ID";

--51) HCT DIstribution pie chart
SELECT
  CASE
    WHEN G."Gender" = 'Male' AND LT."Hct" < 41 THEN 'ANEMIA'
    WHEN G."Gender" = 'Male' AND LT."Hct" >= 41 AND LT."Hct" <= 50 THEN 'NORMAL'
    WHEN G."Gender" = 'Male' AND LT."Hct" > 50 THEN 'High Hematocrit'
    WHEN G."Gender" = 'Female' AND LT."Hct" < 36 THEN 'ANEMIA'
    WHEN G."Gender" = 'Female' AND LT."Hct" >= 36 AND LT."Hct" <= 48 THEN 'NORMAL'
    WHEN G."Gender" = 'Female' AND LT."Hct" > 48 THEN 'High Hematocrit'
  END AS "Hematocrit",
  COUNT(P."Patient_ID") AS "Patient_Count"
FROM public."Lab_Test" LT
JOIN public."Patients" P ON P."Patient_ID" = LT."Patient_ID"
JOIN public."Gender" G ON G."Gender_ID" = P."Gender_ID"
GROUP BY "Hematocrit";

--52)GAIT_SPEED RANGE 
SELECT P."Patient_ID",
  CASE
    WHEN G."Gender" = 'Male' AND "Gait_DT_Speed" < 1.08 THEN 'LOW'
    WHEN G."Gender" = 'Female' AND "Gait_DT_Speed" < 0.92 THEN 'LOW'
    ELSE 'NORMAL'
  END AS "GAIT_SPEED"
FROM public."Walking_Test" WT
JOIN public."Patients" P ON P."WalkTest_ID" = WT."WalkTest_ID"
JOIN public."Gender" G ON G."Gender_ID" = P."Gender_ID";

--53) GAIT_SPEED DISTRIBUTION
SELECT
  CASE
    WHEN G."Gender" = 'Male' AND "Gait_DT_Speed" < 1.08 THEN 'LOW'
    WHEN G."Gender" = 'Female' AND "Gait_DT_Speed" < 0.92 THEN 'LOW'
    ELSE 'NORMAL'
  END AS "GAIT_SPEED",
  COUNT(P."Patient_ID") AS "PATIENT_COUNT"
FROM public."Walking_Test" WT
JOIN public."Patients" P ON P."WalkTest_ID" = WT."WalkTest_ID"
JOIN public."Gender" G ON G."Gender_ID" = P."Gender_ID"
GROUP BY "GAIT_SPEED";

--54) Average heart rate on age bin pipe chart
SELECT 
CONCAT((WIDTH_BUCKET(p."Age", 0, 100, 20) - 1) * 5, ' - ', WIDTH_BUCKET(p."Age", 0, 100, 20) * 5 - 1) AS age_range,
COUNT (*) AS PATIENT_COUNT 
FROM PUBLIC."Patients" P
GROUP BY WIDTH_BUCKET(p."Age", 0, 100, 20)
ORDER BY age_range ASC;


--55) distribution of patients with abnormal insulin
SELECT
  CASE
    WHEN LT."Insulin" < 2.6 THEN 'Low Insulin'
    WHEN LT."Insulin" >= 2.6 AND LT."Insulin" <= 24.9 THEN 'Normal Insulin'
    WHEN LT."Insulin" > 24.9 THEN 'High Insulin'
  END AS "Insulin_Level",
  COUNT(*) AS "Patient_Count"
FROM public."Lab_Test" LT
GROUP BY "Insulin_Level";

--56) check schema
SELECT current_schema();

--57) check for null values
SELECT table_name, column_name
FROM information_schema.columns
WHERE table_schema = 'public'
  AND column_name IN (
    SELECT column_name
    FROM public."Patients"
    WHERE column_name IS NULL
  );
  
--58)The name of the current user in PostgreSQL.
SELECT CURRENT_USER;

--59)Return the name of the current database in PostgreSQL
SELECT current_database();

--60)Return the process ID (PID) of the current PostgreSQL database connection.
SELECT pg_backend_pid();

--61) abnormal insulin to abnormal platelet study
SELECT
  CASE
    WHEN LT."Insulin" < 2.6 THEN 'Low Insulin'
    WHEN LT."Insulin" >= 2.6 AND LT."Insulin" <= 24.9 THEN 'Normal Insulin'
    WHEN LT."Insulin" > 24.9 THEN 'High Insulin'
  END AS "Insulin_Level",
  COUNT(*) AS "Patient_Count"
FROM public."Lab_Test" LT
WHERE LT."Platelets" < 150 OR LT."Platelets" > 450
GROUP BY "Insulin_Level";

--62) Comprehensive study
CREATE OR REPLACE VIEW patient_info AS
SELECT
    P."Patient_ID",
    CONCAT(P."Firstname", ' ', P."Lastname") AS "Full_Name",
    G."Gender",
    P."Age",
    R."Race",
	LV."Lab_names",
	 CASE
        WHEN GR."Group" = 'DM' THEN 'Diabetic'
        ELSE 'Control'
    END AS "Group",
    CASE
        WHEN (((BP."24Hr_Day_SBP" + 2 * BP."24Hr_Day_DBP") / 3) < 70) OR (((BP."24Hr_Night_SBP" + 2 * BP."24Hr_Night_DBP") / 3) < 70) THEN 'Low'
        WHEN (((BP."24Hr_Day_SBP" + 2 * BP."24Hr_Day_DBP") / 3) >= 70 AND ((BP."24Hr_Day_SBP" + 2 * BP."24Hr_Day_DBP") / 3) <= 100) OR (((BP."24Hr_Night_SBP" + 2 * BP."24Hr_Night_DBP") / 3) >= 70 AND ((BP."24Hr_Night_SBP" + 2 * BP."24Hr_Night_DBP") / 3) <= 100) THEN 'Normal'
        ELSE 'High'
    END AS "Map",
    CASE
        WHEN O."Macular_Edema" <> 0 THEN 'Macular_Edema'
        WHEN O."Diabetic_Retinopathy" <> 0 THEN 'Diabetic_Retinopathy'
        ELSE 'No'
    END AS "Eye_Damage",
    CASE
        WHEN L."Fasting_Cholestrol" < 150 THEN 'Normal'
        ELSE 'High'
    END AS "Cholesterol",
    CASE
        WHEN LT."Fasting_Glucose" <= 70 THEN 'Hypoglycemia'
        WHEN LT."Fasting_Glucose" > 70 AND LT."Fasting_Glucose" <= 100 THEN 'Normal'
        WHEN LT."Fasting_Glucose" > 100 AND LT."Fasting_Glucose" <= 120 THEN 'Pre_Diabetic'
        ELSE 'Diabetic'
    END AS "Insulin",
    CONCAT_WS(',',
        CASE WHEN MC."IADL" <= 14 THEN 'IADL' END,
        CASE WHEN MC."MMSE" <= 23 THEN 'MMSE' END,
        CASE WHEN MC."GDS" >= 15 THEN 'GDS' END,
        CASE WHEN VMC."RCFT_IR" <= 71 THEN 'RCFT_IR' END,
        CASE WHEN VMC."TM" >= 42 THEN 'TM' END,
        CASE WHEN VMC."Clock" <= 2 THEN 'Clock' END,
        CASE WHEN VC."DS" < 13 THEN 'DS' END,
        CASE WHEN VC."HVLT" < 19 THEN 'HVLT' END,
        CASE WHEN VC."VF" < 42 THEN 'VF' END,
        CASE WHEN VC."WTAR" <= 20 THEN 'WTAR' END
    ) AS "Dementia",
    CASE
        WHEN U."Creatinine" IS NOT NULL AND U."Albumin" IS NOT NULL THEN
        CASE
            WHEN G."Gender" = 'Male' AND U."Creatinine" BETWEEN 65.4 AND 119.3 AND U."Albumin" BETWEEN 3.4 AND 5.4 THEN 'Normal'
            WHEN G."Gender" = 'Female' AND U."Creatinine" BETWEEN 52.2 AND 91.9 AND U."Albumin" BETWEEN 3.4 AND 5.4 THEN 'Normal'
            WHEN G."Gender" = 'Male' AND (U."Creatinine" < 65.4 OR U."Creatinine" > 119.3) THEN 'A.Creat'
            WHEN G."Gender" = 'Female' AND (U."Creatinine" < 52.2 OR U."Creatinine" > 91.9) THEN 'A.Creat'
            WHEN U."Albumin" < 3.4 OR U."Albumin" > 5.4 THEN 'A.Alb'
            ELSE 'A.Creat, A.Alb'
        END
    END AS "Lipid"
FROM
    public."Patients" P
    JOIN public."Gender" G ON G."Gender_ID" = P."Gender_ID"
    JOIN public."Race" R ON R."Race_ID" = P."Race_ID"
    JOIN public."Blood_Pressure" BP ON BP."BP_ID" = P."BP_ID"
    JOIN public."Opthalmology" O ON O."Opthal_ID" = P."Opthal_ID"
    JOIN public."Walking_Test" WT ON WT."WalkTest_ID" = P."WalkTest_ID"
    JOIN public."Link_Reference" LR ON LR."Link_Reference_ID" = P."Link_Reference_ID"
    JOIN public."Urine_Test" U ON U."Urine_ID" = LR."Urine_ID"
    JOIN public."Lipid_Lab_Test" L ON L."Lipid_ID" = LR."Lipid_ID"
    JOIN public."Memory_Cognitive" MC ON MC."MC_ID" = LR."MC_ID"
    JOIN public."Visual/Motor_Cog" VMC ON VMC."VM_ID" = LR."VM_ID"
    JOIN public."Verbal_Cognitive" VC ON VC."VC_ID" = LR."VC_ID"
    JOIN public."Lab_Test" LT ON LT."Lab_ID" = LR."Lab_ID"
    JOIN public."Group" GR ON GR."Group_ID" = P."Group_ID"
	JOIN public."Lab_Visit" LV ON LV."Lab_visit_ID" = LR."Lab_visit_ID";


SELECT * FROM patient_info
Drop VIEW patient_info

--63) checking if all patients in diabetic group have diabetic duration
SELECT P."Patient_ID"
FROM public."Patients" P
WHERE P."Diabetes_Duration"=0
AND P."Group_ID" IN (SELECT "Group_ID" FROM public."Group" G WHERE "Group"= 'DM')

--64) seeing the info of the patient in Diabetic group without diabetic_duration
SELECT * FROM public.patient_info WHERE "Patient_ID"='S0308'

--65. Create a pie chart to show BADS assessment score categories
SELECT COUNT(*),
CASE WHEN mc."BADS" <11 THEN 'IMPAIRED'
WHEN mc."BADS" BETWEEN 12 AND 13 THEN 'BORDERLINE'
WHEN mc."BADS" BETWEEN 14 AND 15 THEN 'LOW AVERAGE'
WHEN mc."BADS" BETWEEN 16 AND 20 THEN 'AVERAGE'
WHEN mc."BADS" BETWEEN 21 AND 22 THEN 'HIGH AVERAGE'
WHEN mc."BADS" BETWEEN 23 AND 24 THEN 'SUPERIOR'
END AS "BADS CATEGORY"
FROM public."Memory_Cognitive" mc,public."Patients" p,public."Link_Reference" lr
WHERE lr."MC_ID"=mc."MC_ID" AND lr."Link_Reference_ID"=p."Link_Reference_ID"
GROUP BY "BADS CATEGORY"

--66.Write a query to find number of male and female patients who have less than average BADS score
SELECT g."Gender",COUNT(*) As "UNDER AVERAGE BADS SCORE" FROM public."Memory_Cognitive" mc,"Gender" g, public."Patients" p,public."Link_Reference" lr
WHERE p."Link_Reference_ID"=lr."Link_Reference_ID"
AND lr."MC_ID"=mc."MC_ID"
AND g."Gender_ID"=p."Gender_ID"
AND mc."BADS"<16 
GROUP BY g."Gender"

--67. Find number of patients who are Impaired Dementially/Cognitively based on GDS score
SELECT COUNT(*) As "Demential/Cognitive Impaired Patients" FROM 
public."Memory_Cognitive" mc,public."Patients" p,public."Link_Reference" lr
WHERE lr."MC_ID"=mc."MC_ID" AND lr."Link_Reference_ID"=p."Link_Reference_ID"
AND mc."GDS">=15

--68)write a query to get only the Patients visit time  without using Extract function?
SELECT SUBSTRING(TO_CHAR("Visit_Date",'YYYY-MM-DD HH24:MI:SS') from 12 for 8)  AS visit_time
FROM public."Patients";

--69. List patients whose age is odd
SELECT concat(pt."Firstname"||' '||pt."Lastname") Fullname,pt."Age" 
FROM "Patients" pt
WHERE mod("Age",2) <> 0;
 
--List patients whose age is even
SELECT concat(pt."Firstname"||' '||pt."Lastname") Fullname,pt."Age"
FROM "Patients" pt
WHERE mod("Age",2) = 0;

--70 Write a query to find patients who have abnormal Creatinine values
SELECT COUNT(*),
CASE WHEN ut."Creatinine" NOT BETWEEN 65.4 AND 119.3 AND g."Gender"='Male' THEN 'Abnormal Creatinine'
WHEN ut."Creatinine" NOT BETWEEN 52.2 AND 91.9 AND g."Gender"='Female' THEN 'Abnormal Creatinine'
ELSE 'Normal'
END As "Creatinine Level"
FROM public."Urine_Test" ut,public."Gender" g,public."Link_Reference" lr,public."Patients" p
WHERE p."Link_Reference_ID"=lr."Link_Reference_ID" AND lr."Urine_ID"=ut."Urine_ID"
AND p."Gender_ID"=g."Gender_ID" AND ut."Creatinine" IS NOT NULL
GROUP BY "Creatinine Level"

--71. Create a pie chart for patients with normal and abnormal Albumin levels

SELECT COUNT(*),
CASE WHEN ut."Albumin"<30 THEN 'Normal Albumin'
ELSE 'Abnormal Albumin'
END As "Albumin Level"
FROM public."Urine_Test" ut,public."Gender" g,public."Link_Reference" lr,public."Patients" p
WHERE p."Link_Reference_ID"=lr."Link_Reference_ID" AND lr."Urine_ID"=ut."Urine_ID"
AND p."Gender_ID"=g."Gender_ID" AND ut."Creatinine" IS NOT NULL
GROUP BY "Albumin Level"

--72 Write a explain query 

EXPLAIN SELECT * FROM "Patients" WHERE "Age" = '61';

--73. Find dementia patients based on HVLT() Score

SELECT COUNT(*)As "Patient Count",
CASE WHEN vc."HVLT" <14 THEN 'DEMENTIA'
WHEN vc."HVLT" BETWEEN 14 AND 19 THEN 'MILD DEMENTIA'
ELSE 'NORMAL' END AS "Dementia level"
FROM public."Verbal_Cognitive" vc,public."Link_Reference" lr,public."Patients" p
WHERE vc."VC_ID"=lr."VC_ID"
AND vc."Patient_ID"=p."Patient_ID"
GROUP BY "Dementia level"

--74)Display distribution of patients with abnormal insulin. line chart
SELECT
  CASE
    WHEN LT."Insulin" < 2.6 THEN 'Low Insulin'
    WHEN LT."Insulin" >= 2.6 AND LT."Insulin" <= 24.9 THEN 'Normal Insulin'
    WHEN LT."Insulin" > 24.9 THEN 'High Insulin'
  END AS "Insulin_Level",
  COUNT(*) AS "Patient_Count"
FROM public."Lab_Test" LT
GROUP BY "Insulin_Level";

--75) Calculate Weight
SELECT "Height", "BMI", ROUND(("BMI" * ("Height" * "Height"))::numeric, 2) AS "Weight"
FROM public."Patients";

--76) Conclusions on BMI and fasting cholesterol levels and categorize them into ranges
SELECT
  P."Patient_ID",
  P."BMI",
  LT."Fasting_Cholestrol",
  CASE
    WHEN P."BMI" < 18.5 THEN 'Underweight'
    WHEN P."BMI" >= 18.5 AND P."BMI" < 25 THEN 'Normal'
    WHEN P."BMI" >= 25 AND P."BMI" < 30 THEN 'Overweight'
    WHEN P."BMI" >= 30 THEN 'Obese'
  END AS "BMI_Category",
  CASE
    WHEN LT."Fasting_Cholestrol" < 200 THEN 'Desirable'
    WHEN LT."Fasting_Cholestrol" >= 200 AND LT."Fasting_Cholestrol" < 240 THEN 'Borderline'
    WHEN LT."Fasting_Cholestrol" >= 240 THEN 'High Risk'
  END AS "Cholesterol_Category"
FROM public."Patients" P
JOIN public."Lipid_Lab_Test" LT ON P."Patient_ID" = LT."Patient_ID"

--77) Conclusions on BMI and fasting cholesterol levels and categorize them into ranges.Stacked Line Chart
SELECT
  P."Patient_ID",
  P."BMI",
  LT."Fasting_Cholestrol",
  CASE
    WHEN P."BMI" < 18.5 THEN 'Underweight'
    WHEN P."BMI" >= 18.5 AND P."BMI" < 25 THEN 'Normal'
    WHEN P."BMI" >= 25 AND P."BMI" < 30 THEN 'Overweight'
    WHEN P."BMI" >= 30 THEN 'Obese'
  END AS "BMI_Category",
  CASE
    WHEN LT."Fasting_Cholestrol" < 200 THEN 'Desirable'
    WHEN LT."Fasting_Cholestrol" >= 200 AND LT."Fasting_Cholestrol" < 240 THEN 'Borderline'
    WHEN LT."Fasting_Cholestrol" >= 240 THEN 'High Risk'
  END AS "Cholesterol_Category"
FROM public."Patients" P
JOIN public."Lipid_Lab_Test" LT ON P."Patient_ID" = LT."Patient_ID"
ORDER BY "BMI_Category";

--78) Convert height into feet
SELECT
  "Patient_ID",
  "Height",
  CONCAT(
    FLOOR("Height" * 3.28084),
    '''',
    FLOOR((("Height" * 3.28084) - FLOOR("Height" * 3.28084)) * 12),
    '"'
  ) AS "Height_in_Feet"
FROM public."Patients";

--79) Count of Distinct Labs in Lab_Visit

SELECT COUNT(DISTINCT "Lab_names")
FROM public."Lab_Visit"

--80) COUNT DISTINCT RACE

SELECT COUNT (DISTINCT "Race")
FROM public."Race"

--81) COUNT DISTINCT PATIENTS FIRSTNAME

SELECT COUNT (DISTINCT "Firstname")
FROM public."Patients"

--82) REPEATED FIRST NAMES IN PATIENTS TABLE

SELECT "Patient_ID", "Firstname"
FROM public."Patients"
WHERE "Firstname" IN (
  SELECT "Firstname"
  FROM public."Patients"
  GROUP BY "Firstname"
  HAVING COUNT(*) > 1);

--83) Display number of occurrences of each distinct value in the "Clock" line chart
SELECT COUNT ("Patient_ID")
FROM public."Visual/Motor_Cog"
GROUP BY "Clock"

--84) REPEATED LAST NAMES IN PATIENTS TABLE

SELECT COUNT (DISTINCT "Lastname")
FROM public."Patients"

--85) concat first name , last name into full name and displayed in all upper

SELECT "Patient_ID", UPPER(CONCAT("Firstname", ' ', "Lastname")) AS "Full_Name"
FROM public."Patients";

--86)Capitalize each word in lab names

SELECT DISTINCT(INITCAP("Lab_names")) AS formatted_lab_name
FROM public."Lab_Visit"

--87) Calculate Gait Distance per min

SELECT "Patient_ID",ROUND(("Gait_DT_Distance"::numeric / 6), 2) AS "Gait_DT_Distance_Per_Minute"
FROM public."Walking_Test";

--88) number of occurrences of each distinct value in the "Clock"
SELECT COUNT ("Patient_ID")
FROM public."Visual/Motor_Cog"
GROUP BY "Clock"

--89. Find the count of Dementia patients using TM(Trail Making Test) values

SELECT * FROM public."Visual/Motor_Cog"

SELECT COUNT(*)As "Patients with Dementia/Cognitive Impairment" 
FROM public."Visual/Motor_Cog"
WHERE "TM">=42;

--90 List columns of patients tables columns with their ordinal position in the table

SELECT column_name,ordinal_position
FROM information_schema.columns
WHERE table_name = 'Patients'
ORDER BY ordinal_position;

--91) Get the top 5 patients with the highest fasting glucose levels

SELECT * FROM public."Lab_Test"

SELECT CONCAT(p."Firstname",' ',p."Lastname")As "Patient Name", lt."Hb_A1C" 
FROM public."Patients" p, public."Lab_Test" lt
WHERE p."Patient_ID"=lt."Patient_ID"
AND lt."Hb_A1C" IS NOT NULL
ORDER BY lt."Hb_A1C" DESC
LIMIT 5

-- 93. Calculate the average BMI (Body Mass Index) for diabetic and non-diabetic patients

SELECT gp."Group",ROUND(AVG(p."BMI")::numeric,2) As "Average BMI" FROM public."Patients" p,public."Group" gp
WHERE p."Group_ID"=gp."Group_ID"
GROUP BY gp."Group"

-- 94 Get the patients who have undergone an ophthalmology exam and have both diabetic retinopathy and macular edema:

SELECT CONCAT(p."Firstname",' ',p."Lastname")As "Patients Having Diabetic Retinopathy and Macular Edema" 
FROM public."Patients" p
JOIN public."Opthalmology" op ON op."Opthal_ID"=p."Opthal_ID"
WHERE "Diabetic_Retinopathy" >0 AND "Macular_Edema">0;

--95 Calculate the average LDL cholesterol level for male and female patients:

SELECT ROUND(AVG(llt."Fasting_LDL")::numeric,2),g."Gender"
FROM public."Lipid_Lab_Test" llt
JOIN public."Patients" p ON p."Patient_ID"=llt."Patient_ID" 
JOIN public."Gender" g ON g."Gender_ID"=p."Gender_ID"
GROUP BY g."Gender";

SELECT * FROM public."Lipid_Lab_Test"

-- 96. Categorize patients based on LDL levels

SELECT 
CASE WHEN "Fasting_LDL" < 100 THEN 'Optimal'
WHEN "Fasting_LDL" BETWEEN 101 AND 129 THEN 'Near Optimal'
WHEN "Fasting_LDL" BETWEEN 130 AND 159 THEN 'Borderline High'
WHEN "Fasting_LDL" BETWEEN 160 AND 189 THEN 'High'
ELSE 'Very High'
END AS "LDL Levels",COUNT(*) As "Patient Count"
FROM public."Lipid_Lab_Test" 
GROUP BY "LDL Levels";

--97. Visually show the patients in Fasting Triglyceride categories
SELECT 
CASE WHEN "Fasting_Triglyc"< 150 THEN 'Normal'
WHEN "Fasting_Triglyc" BETWEEN 150 AND 199 THEN 'Borderline'
WHEN  "Fasting_Triglyc" BETWEEN 200 AND 499 THEN 'High'
ELSE 'Very High'
END AS "Triglyc Levels",COUNT(*) As "Patient Count"
FROM public."Lipid_Lab_Test" 
GROUP BY "Triglyc Levels";

--98.Calculate number of male patients at risk of heart disease

SELECT COUNT(*) As "Male Patients at risk of heart disease" FROM  public."Gender" g
JOIN public."Patients" p ON p."Gender_ID" = g."Gender_ID"
JOIN public."Lipid_Lab_Test" llt ON llt."Patient_ID"=p."Patient_ID"
WHERE g."Gender"='Male' AND llt."Fasting_HDL" >40;

--99)Get the datatype of a specific field from the Patient table.
SELECT column_name, data_type FROM information_schema.columns WHERE 
table_name = 'Patients' AND column_name = 'Firstname';

-- 100.Find patients with Abnormal Hemoglobin level
SELECT COUNT(*),
CASE WHEN g."Gender"='Male' AND lt."Hgb" BETWEEN 13.2 AND 16.6 THEN 'Normal'
WHEN g."Gender"='Female' AND lt."Hgb" BETWEEN 11.5 AND 15 THEN 'Normal'
ELSE 'Abnormal' END As "Hemoglobin Level"
FROM public."Lab_Test" lt,public."Gender" g,public."Patients" p
WHERE p."Patient_ID"=lt."Patient_ID"
AND p."Gender_ID"=g."Gender_ID"
GROUP BY "Hemoglobin Level"

--101) Give me all the numbers in denormalized form by patients wise
SELECT 
    P."Patient_ID",
    CONCAT(P."Firstname", ' ', P."Lastname") AS "Full_Name",
    P."Age",
    P."BMI",
    G."Gender",
    R."Race",
    BP."24Hr_Day_SBP",
    BP."24Hr_Day_DBP",
    BP."24Hr_Day_HR",
    LT."Fasting_Glucose",
    LLT."Fasting_Cholestrol",
    O."Macular_Edema",
    MC."GDS",
    VMC."Clock",
    UT."Albumin",
    VC."DS",
    WT."Gait_DT_Distance"
FROM public."Patients" P
JOIN public."Gender" G ON G."Gender_ID" = P."Gender_ID"
JOIN public."Race" R ON R."Race_ID" = P."Race_ID"
JOIN public."Group" GR ON GR."Group_ID" = P."Group_ID"
JOIN public."Blood_Pressure" BP ON BP."BP_ID" = P."BP_ID"
JOIN public."Lab_Test" LT ON LT."Patient_ID" = P."Patient_ID"
JOIN public."Lipid_Lab_Test" LLT ON LLT."Patient_ID" = P."Patient_ID"
JOIN public."Opthalmology" O ON O."Opthal_ID" = P."Opthal_ID"
JOIN public."Link_Reference" LR ON LR."Link_Reference_ID" = P."Link_Reference_ID"
JOIN public."Memory_Cognitive" MC ON MC."MC_ID" = LR."MC_ID"
JOIN public."Visual/Motor_Cog" VMC ON VMC."Patient_ID" = P."Patient_ID"
JOIN public."Urine_Test" UT ON UT."Urine_ID" = LR."Urine_ID"
JOIN public."Verbal_Cognitive" VC ON VC."Patient_ID" = P."Patient_ID"
JOIN public."Walking_Test" WT ON WT."Patient_ID" = P."Patient_ID";

--102)how many tables is patients table linked to
SELECT COUNT(DISTINCT "table_name") AS "Linked_Tables_Count"
FROM information_schema.constraint_column_usage
WHERE constraint_name IN (
    SELECT constraint_name
    FROM information_schema.table_constraints
    WHERE table_name = 'Patients' AND table_schema = 'public'
)
AND table_schema = 'public' AND table_name <> 'Patients';

--103)Find number of Patients with Thrombocytopenia by race and Gender

SELECT COUNT(P."Patient_ID") AS "Thrombocytopenia_Count", G."Gender", R."Race"
FROM public."Patients" P
JOIN public."Gender" G ON G."Gender_ID" = P."Gender_ID"
JOIN public."Race" R ON R."Race_ID" = P."Race_ID"
JOIN public."Lab_Test" LT ON LT."Patient_ID" = P."Patient_ID"
WHERE LT."Platelets" < 150
GROUP BY G."Gender", R."Race";


--104) Find number of patients with High Diabetic levels by race and Gender

SELECT COUNT(P."Patient_ID") AS "Diabetic_Count", G."Gender", R."Race"
FROM public."Patients" P
JOIN public."Gender" G ON G."Gender_ID" = P."Gender_ID"
JOIN public."Race" R ON R."Race_ID" = P."Race_ID"
JOIN public."Lab_Test" LT ON LT."Patient_ID" = P."Patient_ID"
WHERE LT."Fasting_Glucose">120
GROUP BY G."Gender",R."Race"

--105)Show lab visit dates where there are more than one visit

SELECT TO_CHAR("Lab_Visit_Date", 'YYYY-MM-DD') AS "Date", COUNT("Lab_visit_ID") AS "Visit_Count"
FROM public."Lab_Visit"
GROUP BY TO_CHAR("Lab_Visit_Date", 'YYYY-MM-DD')
HAVING COUNT("Lab_visit_ID") > 1
ORDER BY "Date";

--106) Fetch the records of weekly visit reports where the visit is more than 1. line chart

SELECT TO_CHAR(DATE_TRUNC('week', "Lab_Visit_Date"), 'YYYY-"W"IW') AS "Week_Number",
       COUNT(DISTINCT "Lab_visit_ID") AS "Visit_Count"
FROM public."Lab_Visit"
GROUP BY TO_CHAR(DATE_TRUNC('week', "Lab_Visit_Date"), 'YYYY-"W"IW')
HAVING COUNT(DISTINCT "Lab_visit_ID") > 1
ORDER BY "Week_Number";

--107) Display patient count across labs
SELECT L."Lab_names",
       COUNT(DISTINCT P."Patient_ID") AS "Unique_Patient_Count"
FROM public."Patients" P
JOIN public."Link_Reference" LR ON LR."Link_Reference_ID" = P."Link_Reference_ID"
JOIN public."Lab_Visit" L ON L."Lab_visit_ID" = LR."Lab_visit_ID"
GROUP BY L."Lab_names"
ORDER BY L."Lab_names";

--108)Patients count for GDS range from 0-14.9 by race and Gender wise. 

SELECT COUNT(P."Patient_ID") AS "Patient_Count", R."Race", G."Gender"
FROM public."Patients" P
JOIN public."Race" R ON R."Race_ID" = P."Race_ID"
JOIN public."Gender" G ON G."Gender_ID" = P."Gender_ID"
JOIN public."Link_Reference" LR ON LR."Link_Reference_ID" = P."Link_Reference_ID"
JOIN public."Memory_Cognitive" MC ON MC."MC_ID" = LR."MC_ID"
WHERE MC."GDS" > 0 AND MC."GDS" < 14.9
GROUP BY R."Race", G."Gender";

--109) Dementia across age groups. line graph

SELECT
  FLOOR((P."Age" - 1) / 5) * 5 || '-' || FLOOR((P."Age" - 1) / 5) * 5 + 4 AS "Age_Range",
  COUNT(DISTINCT CASE
    WHEN MC."IADL" <= 14 THEN P."Patient_ID"
    WHEN MC."MMSE" <= 23 THEN P."Patient_ID"
    WHEN MC."GDS" >= 15 THEN P."Patient_ID"
    WHEN VMC."RCFT_IR" <= 71 THEN P."Patient_ID"
    WHEN VMC."TM" >= 42 THEN P."Patient_ID"
    WHEN VMC."Clock" <= 2 THEN P."Patient_ID"
    WHEN VC."DS" < 13 THEN P."Patient_ID"
    WHEN VC."HVLT" < 19 THEN P."Patient_ID"
    WHEN VC."VF" < 42 THEN P."Patient_ID"
    WHEN VC."WTAR" <= 20 THEN P."Patient_ID"
  END) AS "Dementia_Patient_Count"
FROM public."Patients" P
JOIN public."Link_Reference" LR ON LR."Link_Reference_ID" = P."Link_Reference_ID"
JOIN public."Memory_Cognitive" MC ON MC."MC_ID" = LR."MC_ID"
JOIN public."Visual/Motor_Cog" VMC ON VMC."Patient_ID" = P."Patient_ID"
JOIN public."Verbal_Cognitive" VC ON VC."Patient_ID" = P."Patient_ID"
GROUP BY FLOOR((P."Age" - 1) / 5) * 5
ORDER BY FLOOR((P."Age" - 1) / 5) * 5;

--110)Get the list of patients who's Id number has 2

SELECT "Patient_ID"
FROM public."Patients"
WHERE "Patient_ID" LIKE '%2%'

--111) STUDY OF PATIENTS WHOSE CHOLESTRAL IS HIGH. RACE WISE AND GENDER WISE

SELECT COUNT(P."Patient_ID") AS "Patient_Count",R."Race",G."Gender"
FROM public."Patients" P
JOIN public."Race" R ON R."Race_ID" = P."Race_ID"
JOIN public."Gender" G ON G."Gender_ID" = P."Gender_ID"
JOIN public."Lipid_Lab_Test" L ON L."Patient_ID" = P."Patient_ID"
WHERE L."Fasting_Cholestrol" > 240
GROUP BY R."Race", G."Gender";

--112)Measure the GAIT_DT_Speed age critria is(55)

SELECT P."Age", WT."Patient_ID", WT."Gait_DT_Speed"
FROM public."Walking_Test" WT
JOIN public."Patients" P ON P."WalkTest_ID" = WT."WalkTest_ID"
WHERE P."Age"=55
GROUP BY P."Age", WT."Patient_ID", WT."Gait_DT_Speed";

--113) AVERAGE SPEED OVER AGE USING RUNNING MOVING AVERAGE

SELECT
  (WIDTH_BUCKET(P."Age", 0, 100, 20) * 5 - 4) || ' - ' || (WIDTH_BUCKET(P."Age", 0, 100, 20) * 5) AS "Age_Range",
  ROUND(AVG(WT."Gait_DT_Speed"::numeric), 2) AS "Average_Speed"
FROM public."Walking_Test" WT
JOIN public."Patients" P ON P."WalkTest_ID" = WT."WalkTest_ID"
GROUP BY WIDTH_BUCKET(P."Age", 0, 100, 20)
ORDER BY "Age_Range";

--114)Sort patientsID ,height in patients table based on over BMI using Dense rank
SELECT "Patient_ID","Height","BMI",
  DENSE_RANK() OVER (ORDER BY "BMI" DESC) AS bmi_rank
FROM public."Patients";

--115) Show unique height value, and the ages column contains an array of ages for each height.
SELECT "Height",
  ARRAY_AGG("Age") AS ages
FROM public."Patients"
GROUP BY "Height"

--116)USING ARRAY AGGREGATION DISPLAY PATIENTS WHO VISITED LABS ACCORDINGLY
SELECT LV."Lab_names",
  ARRAY_AGG(P."Patient_ID") AS PATIENTS
FROM public."Lab_Visit" LV
JOIN public."Link_Reference" LR ON LR."Lab_visit_ID" = LV."Lab_visit_ID"
JOIN public."Patients" P ON P."Link_Reference_ID" = LR."Link_Reference_ID"
GROUP BY LV."Lab_names"

--117)WRITE A QUERY TO FIND GET PATIENTSCOUNT  OF EACH  RACE ,WHO HAVE BOTH  DIABETIC _RETINOPATHY  AND "Macular_Edema"

SELECT COUNT(R."Race"),R."Race"
FROM public."Patients"  P
JOIN public."Opthalmology"  OP ON OP."Opthal_ID" = P."Opthal_ID"
JOIN public."Race" R ON R."Race_ID" = P."Race_ID"
WHERE OP."Diabetic_Retinopathy"  != 0  AND  OP."Macular_Edema" != 0
GROUP  BY  R."Race" ;

--118)WRITE A QUERY TO FIND PATIENT WHO DO NOT HAVE OPTIMAL INSULIN LEVEL .
SELECT CONCAT (PT."Firstname",' ',PT."Lastname") patient_name FROM public."Lab_Test" LT
JOIN public."Patients" PT ON PT."Patient_ID" = LT."Patient_ID"
WHERE "Insulin" NOT BETWEEN 2.6 AND 24.6

--119)WRITE THE PERCENTAGE OF GENDER WHO ARE IN PREDIABETIC STATE.

SELECT GD."Gender",COUNT(*) * 100.0 / SUM(COUNT(*)) OVER () AS percentage
FROM public."Lab_Test" LT 
JOIN public."Link_Reference" LR ON LT."Lab_ID" = LR."Lab_ID"
JOIN public."Patients"  PT ON PT."Link_Reference_ID" = LR."Link_Reference_ID"
JOIN public."Gender" GD ON PT."Gender_ID" = GD."Gender_ID"
WHERE LT."Hb_A1C" BETWEEN 5.7 AND 6.4 OR LT."Fasting_Glucose" = 100
GROUP BY GD."Gender"

--120)WRITE A QUERY TO GET LEAST 3 RECORDS  ,WHOSE  GAIT_DT_DISTANCE IS MINIMUM  ALONG WITH THEIR AGE, GENDER AND RACE

SELECT PT."Age",G."Gender",R."Race"
FROM public."Walking_Test" WT
JOIN public."Patients" PT ON PT."WalkTest_ID" = WT."WalkTest_ID"
JOIN public."Gender" G  ON PT."Gender_ID" = G."Gender_ID"
JOIN public."Race" R  ON R."Race_ID" = PT."Race_ID"
ORDER BY "Gait_DT_Distance"  LIMIT 3;

--121)WRITE A QUERY TO FIND PATIENTS NAME  RACE AND AGE GREATER THAN 55, WHOSE IS HAVING  BOTH VERBAL_COGNITIVE AND ALSO HAVE KIDNEY RELATED ISSUES

SELECT CONCAT (PT."Firstname",' ',PT."Lastname") patient_name,R."Race",PT."Age"
FROM public."Verbal_Cognitive" VC 
JOIN public."Link_Reference" LR ON LR."VC_ID" = VC."VC_ID"
JOIN public."Urine_Test" UT ON UT."Urine_ID" = LR."Urine_ID"
JOIN public."Patients" PT ON PT."Link_Reference_ID" = LR."Link_Reference_ID"
JOIN public."Race" R ON R."Race_ID" = PT."Race_ID"
WHERE UT."Albumin" NOT  BETWEEN 3.4 AND 5.4
AND  ("DS" < 13  OR "VF" < 42  OR "WTAR" <= 20 )
AND PT."Age" > 55;

--122) Using sub-query show all records whose BMI is above 24.9.

SELECT P."Patient_ID", P."Age", P."BMI"
FROM (SELECT * FROM public."Patients" WHERE "BMI" > 24.9) AS P;

--123) Using Nested Queries in SQL find patients id whose "Hb_A1C">6.5

SELECT P."Patient_ID", LT."Hb_A1C"
FROM public."Patients" AS P
JOIN public."Lab_Test" AS LT ON P."Patient_ID" = LT."Patient_ID"
WHERE P."Patient_ID" IN (
  SELECT LT."Patient_ID"
  FROM public."Lab_Test" AS LT
  WHERE LT."Hb_A1C" > 6.5);

--124) Using Correlated Subqueries show patient whose "Insulin" < 2.6.
SELECT P."Patient_ID", LT."Insulin"
FROM public."Patients" AS P
JOIN public."Lab_Test" AS LT ON P."Patient_ID" = LT."Patient_ID"
WHERE LT."Insulin" < 2.6
  AND EXISTS (
    SELECT 1
    FROM public."Lab_Test" AS LT2
    WHERE LT2."Patient_ID" = P."Patient_ID" AND LT2."Insulin" < 2.6);
	
--125)USE FULL JOIN TO DISPLAY PATIENTS ID WITH AGE, WTAR, TM

SELECT V."Patient_ID",V."WTAR" , VM."TM", P."Age"
FROM public."Verbal_Cognitive" AS V
FULL JOIN public."Visual/Motor_Cog" AS VM ON VM."Patient_ID" = V."Patient_ID"
FULL JOIN public."Patients" AS P ON P."Patient_ID" = V."Patient_ID";

