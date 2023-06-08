--1. Display any 10 random DM patients.

select * from "Patients" 
where "Group_ID" in(select "Group_ID" from "Group" where "Group"='DM')
order by random() limit 10;

--2.please go through the below screenshot and creat the exact output

select CONCAT("Firstname", ' ', "Lastname") AS "full_name" from "Patients" 
where "Lastname" like 'Ma%';
	
--3.Write a query to get a list of patients whose RPE start is at moderate intensity.

Select p."Patient_ID",p."Firstname",p."Lastname"
from "Patients" p
join "Walking_Test" wt on p."WalkTest_ID"=wt."WalkTest_ID"
where wt."Gait_RPE_Start " Between 4 and 6;

--4 Write a query by using common table expressions and case statements to display birthyear ranges.

with cts as
(
   select
      "Patient_ID",
      "Firstname",
      "Lastname",
      "Age",
      EXTRACT(YEAR FROM CURRENT_DATE) - "Age" AS "birth_year" 
   from
      "Patients"
)
select
   "Patient_ID",
   "Firstname",
   "Lastname",
   CASE
      When
         birth_year IS NOT NULL 
      THEN
         CONCAT(FLOOR(birth_year / 10)*10, '-', FLOOR(birth_year / 10)*10 + 9) 
      ELSE
         'unknown'
   END
   AS "Birth_Year_Range"
From
   cts;

--5) Display DM patient names with highest day MAP and night MAP (without using limit).

CREATE INDEX idx_patients ON public."Patients" ("Patient_ID", "Group_ID");
CREATE INDEX idx_blood_pressure ON public."Blood_Pressure" ("Patient_ID");
CREATE INDEX idx_group ON public."Group" ("Group");
WITH dm_patients AS (
  SELECT
    P."Firstname",
    P."Lastname",
    ((2 * BP."24Hr_Day_DBP") + BP."24Hr_Day_SBP") / 3 AS day_map,
    ((2 * BP."24Hr_Night_DBP") + BP."24Hr_Night_SBP") / 3 AS night_map,
    ROW_NUMBER() OVER (ORDER BY ((2 * BP."24Hr_Day_DBP") + BP."24Hr_Day_SBP") / 3 DESC) AS rn
  FROM public."Patients" P
  JOIN public."Blood_Pressure" BP ON BP."Patient_ID" = P."Patient_ID"
  JOIN public."Group" G ON G."Group_ID" = P."Group_ID"
  WHERE G."Group" LIKE '%DM%'
)
SELECT "Firstname", "Lastname", day_map, night_map
FROM dm_patients
WHERE rn = 1;

--6.Create view on table Lab Test by selecting some columns and filter data using Where condition.

create or replace view bc_test_result as
select "Lab_ID","Patient_ID","WBC","Platelets" from "Lab_Test" 
where "WBC" between 3 and 6;

select * from bc_test_result;

--7.Display a list of Patient IDs and their Group whose diabetes duration is greater than 10 years.

select "Patient_ID","Group" from "Patients" join "Group" on "Patients"."Group_ID"= "Group"."Group_ID"
where "Diabetes_Duration" > 10;


--8. Write a query to list male patient ids 
--and their names 
--who are above 40 years of age and less than 60 years 
--and have Day BloodPressureSystolic above 120 and Day BloodPressureDiastolic above 80.

select p."Patient_ID","Firstname","Lastname","Age",g."Gender",bp."24Hr_Day_SBP",bp."24Hr_Day_DBP" from "Patients" as p
     			 join "Gender" as g on p."Gender_ID"=g."Gender_ID" 
				 join "Blood_Pressure" as bp on bp."BP_ID"=p."BP_ID"
				 where g."Gender"='Male'
				 and p."Age" between 40 and 60
				 and bp."24Hr_Day_SBP" > 120 and bp."24Hr_Day_DBP" >80;
	
	
	
--9 Use a function to calculate the percentage of patients according to the lab visited per month

CREATE OR REPLACE FUNCTION calculate_lab_visit_percentage()
RETURNS TABLE (month_name text, year integer, percentage numeric)
AS $$
DECLARE
  total_visits bigint;
BEGIN
  SELECT EXTRACT(YEAR FROM current_date) AS year, COUNT(DISTINCT "Patient_ID") AS total_visits
  INTO year, total_visits
  FROM public."Patients"
  GROUP BY year;
  FOR month_num IN 1..12
  LOOP
    SELECT TO_CHAR(DATE_TRUNC('MONTH', current_date) + (month_num - 1) * INTERVAL '1 MONTH', 'Month') AS month_name, year,
           (COUNT(DISTINCT "Patient_ID") * 100) / total_visits
    INTO month_name, year, percentage
    FROM public."Patients"
    WHERE EXTRACT(MONTH FROM "Visit_Date") = month_num
    GROUP BY month_name, year
    ORDER BY EXTRACT(MONTH FROM DATE_TRUNC('MONTH', current_date) + (month_num - 1) * INTERVAL '1 MONTH');
    RETURN NEXT;
  END LOOP;
END;
$$ LANGUAGE plpgsql;

select * from calculate_lab_visit_percentage();

--10.Count of patients by first letter of firstname.

select left("Firstname",1) as firstletter, count(1) from "Patients" 
group by firstletter;

/*11.write a query to get the list of patients whose lipid test value is null.*/
SELECT * FROM "Lipid_Lab_Test" where "Fasting_Cholestrol" IS NULL
								OR "Fasting_Triglyc" IS NULL 
								OR "Fasting_HDL" IS NULL
								OR "Fasting_LDL" IS NULL;
								

/*12.	 Create a stored procedure to make user ids for the given patient id.*/
--Generate userId based on patient_id

create or replace procedure GenerateUserID(patient_id int)
language plpgsql
as $$
Declare
userID varchar(20);
usernumber Integer;
Begin
--usernumber is calculated by multiplying by 1000
usernumber:=patient_id*1000;
--concatenate 'UID' with the converted userNumber to VARCHAR and assigns it to userId.
userId:='UID' || usernumber::VARCHAR;
--raise a notice message with generated userID
RAISE NOTICE 'Generated User ID: %' , userID;
End;
$$;

--Call procedure by passing PatientID as argument
call GenerateUserID(12345);

/*13.Display Patients With LastName contains 'Po' and replace it with  'Be'*/

SELECT "Patient_ID","Firstname","Lastname",REPLACE("Lastname",'Po','Be') As "New LASTNAME" 
FROM public."Patients"
WHERE "Lastname" LIKE 'Po%';

/* 14. Calculate the patient's birth year in descending order.*/
SELECT CONCAT("Firstname",' ',"Lastname") As "Patient Name", 
       (Extract(year from "Visit_Date"))-"Age" as "Birth Year"
FROM public."Patients"
ORDER BY "Birth Year" DESC;

/*15.Find the patients that have eye damage due to diabetes.*/

SELECT CONCAT(p."Firstname", ' ', p."Lastname") AS "Patients With Eye Damage"
FROM public."Patients" p
JOIN public."Opthalmology" o ON p."Opthal_ID" = o."Opthal_ID"
-- Filter the rows where either "Diabetic_Retinopathy" or "Macular_Edema" > 0
WHERE (o."Diabetic_Retinopathy" > 0 OR o."Macular_Edema" > 0)
GROUP BY "Patients With Eye Damage";

/* 16.Query to classify Gait RPE End into 5 categories as per the intensity. (Hint: Use of CASE statement)*/

SELECT "Patient_ID",
CASE WHEN "Gait_RPE_End "= 0 THEN 'Rest'
     WHEN "Gait_RPE_End " BETWEEN 1 AND 3 THEN 'EASY INTENSITY'
	 WHEN "Gait_RPE_End " BETWEEN 4 AND 6 THEN 'MODERATE INTENSITY'
	 WHEN "Gait_RPE_End " BETWEEN 7 AND 9 THEN 'HARD INTENSITY'
	 WHEN "Gait_RPE_End " = 10  THEN 'MAX EFFORT INTENSITY'
END
FROM public."Walking_Test";

/*17.Create view on patient table with check constraint condition.*/
CREATE VIEW Vw_Patient_Senior as
SELECT "Patient_ID","Firstname", "Lastname","Age" FROM public."Patients"
WHERE "Age">70;

DROP VIEW Vw_Patient_Senior;

SELECT * FROM Vw_Patient_Senior;

/*18.	Calculate the patient's current age.*/

-- Subtracting Visit_Date from current year and adding Age at Visit time gives patients' Current Age
SELECT (Extract(year from now()))-(Extract(year from "Visit_Date"))+"Age" as "Patients Current Age"
FROM public."Patients";


/*19.Write a query to display Mr. or Ms. as prefix to patients’ names with respect to gender.*/

SELECT CASE WHEN G."Gender"='Male' THEN CONCAT('Mr. ', P."Firstname",' ',P."Lastname")
            WHEN G."Gender"='Female' THEN CONCAT('Ms. ', P."Firstname",' ', P."Lastname") END
			As " Prefixed Full Name"
FROM public."Patients" P, public."Gender" G 
WHERE G."Gender_ID" = P."Gender_ID";

/* 20.Write a query to get DM patient names whose distance is greater than 400 and speed is greater than 1.*/

SELECT CONCAT(p."Firstname", ' ', p."Lastname") AS "Patient", wt."Gait_DT_Distance", wt."Gait_DT_Speed"
FROM public."Patients" p 
JOIN public."Walking_Test" wt ON p."Patient_ID"=wt."Patient_ID"
WHERE "Gait_DT_Distance">400 AND "Gait_DT_Speed" > 1;

--21)Create a trigger to raise notice and prevent the deletion of a record from a view.

-- Create a view of patients details joining tables
CREATE VIEW PatientsView
AS 
SELECT pnt."Patient_ID",pnt."Firstname", pnt."Lastname", pnt."Visit_Date",pnt."Age", pnt."Height", pnt."BMI",
grp."Group",gnr."Gender",race."Race",bp."24Hr_Day_SBP",bp."24Hr_Day_DBP",bp."24Hr_Day_HR",
opt."Diabetic_Retinopathy", opt."Macular_Edema", lr."Lipid_ID", lr."Lab_ID"
FROM public."Patients" AS pnt 
INNER JOIN public."Group" AS grp ON pnt."Group_ID" = grp."Group_ID"
INNER JOIN public."Gender" AS gnr ON pnt."Gender_ID" = gnr."Gender_ID"
INNER JOIN public."Race" AS race ON pnt."Race_ID" = race."Race_ID"
INNER JOIN public."Blood_Pressure" AS bp ON pnt."BP_ID" = bp."BP_ID"
INNER JOIN public."Opthalmology" AS opt ON pnt."Opthal_ID" = opt."Opthal_ID"
INNER JOIN public."Link_Reference" AS lr ON pnt."Link_Reference_ID" = lr."Link_Reference_ID"

-- create a function to raise exception to delete records from view
CREATE FUNCTION patient_prevent_delete()
RETURNS TRIGGER
AS $$
BEGIN
RAISE EXCEPTION 'You cannot delete records from View';
END;
$$
-- create a trigget to call above function while trying to delete from view
CREATE TRIGGER TG_PATIENT_PREVENT_DELETE
INSTEAD OF DELETE
ON PatientsView
FOR EACH ROW
EXECUTE PROCEDURE patient_prevent_delete();

-- check deleting a record 	
DELETE FROM  patientsview WHERE  "Patient_ID"='S0030';



--22)Select the patient's full name with a name starting with 's'
--followed by any character, followed by 'r', followed by any character, followed by b.

SELECT CONCAT("Firstname",
	   "Lastname") as "fullname"
FROM   "Patients"
WHERE  CONCAT("Firstname",
	   "Lastname") iLIKE 's%r%b%';

--comments :TO MATCH CASE INSENSITIVE CASES WE USE "ILIKE" IN POSTGRES NOT STANDARD TO SQL BUT AS POSTGRES EXTENSION"

--23.write a query to get which race has the maximum number of Diabetic patients.
SELECT "Race"
FROM "Race"
WHERE "Race_ID" =
		(SELECT "Race_ID"
			FROM "Patients"
			WHERE "Diabetes_Duration" != 0
			GROUP BY "Race_ID"
			ORDER BY COUNT("Race_ID") DESC
			LIMIT 1);
			
--24.Find the list of Patients who has leukopenia.

SELECT LT."Patient_ID",P."Firstname",P."Lastname"
FROM public."Lab_Test" LT
JOIN public."Patients" P ON P."Patient_ID" = LT."Patient_ID"
WHERE "WBC"<3;

--25.Get the number of patients in the year 2005 in each of the Genesis and Cultivate labs.
SELECT "Lab_names",COUNT ("Lab_visit_ID")NUMOFPATIENTS FROM public."Lab_Visit"
WHERE "Lab_names" in ('Cultivate Lab' , 'Genesis Lab')
AND (EXTRACT(YEAR FROM "Lab_Visit_Date")) = 2005
GROUP BY "Lab_names";


--26.Write a query to get a list of patient IDs' and their Fasting Cholesterol in February 2006.
SELECT LLT."Patient_ID",
	   LLT."Fasting_Cholestrol",
	   TO_CHAR(LV."Lab_Visit_Date",'MONTH')AS MONTH,
	   TO_CHAR(LV."Lab_Visit_Date",'YYYY')AS YEAR
FROM PUBLIC."Lipid_Lab_Test" LLT
LEFT JOIN PUBLIC."Link_Reference" LR ON LR."Lipid_ID" = LLT."Lipid_ID"
JOIN PUBLIC."Lab_Visit" LV ON LV."Lab_visit_ID" = LR."Lab_visit_ID"
WHERE EXTRACT (YEAR FROM LV."Lab_Visit_Date") = 2006
	AND EXTRACT(MONTH FROM LV."Lab_Visit_Date") = 2;



--27.Write a query to get a list of patients whose first names is starting with the letter T
SELECT "Firstname","Lastname"
FROM PUBLIC."Patients"
WHERE "Firstname" ILIKE 'T%';

--28.Find a list of Male patients whose age is more than 60 whose, BMI is more than 18.5, and whose height is more than e 1.5 M.
SELECT P."Firstname",
	P."Lastname"
FROM PUBLIC."Patients" P
LEFT JOIN PUBLIC."Gender" G ON G."Gender_ID" = P."Gender_ID"
WHERE G."Gender" = 'Male'
	AND P."Age" > 60
	AND P."BMI" > 18.5
	AND P."Height" > 1.5;

--"Normal levels vary according to your body size and muscle mass.
--Normal range for Men 65.4 to 119.3 micromoles/L and Normal range for women 52.2 to 91.9 micromoles/L."
--29 )Write a query to get ceiled creatinine levels for male who age is greater than 35 and levels are abnormal.
SELECT CEILING(UT."Creatinine") creatininelevel
FROM PUBLIC."Urine_Test" UT
JOIN PUBLIC."Link_Reference" LR ON LR."Urine_ID" = UT."Urine_ID"
JOIN PUBLIC."Patients" PT ON PT."Link_Reference_ID" = LR."Link_Reference_ID"
JOIN public."Gender" G ON PT."Gender_ID" = G."Gender_ID" 
 WHERE "Age" > 35 AND  "Creatinine" NOT BETWEEN 65.4 AND 119.3 AND "Gender" = 'Male'
 
--30.Write a query to get the number of patients who visited the Lab between 9 am to 12 am.
SELECT COUNT("Lab_visit_ID")
FROM PUBLIC."Lab_Visit"
WHERE EXTRACT (HOUR FROM "Lab_Visit_Date") BETWEEN 9 AND 12;

/*31) Write a trigger that calls a function, for checking space and case for two columns 
or more before you add new data to a table.*/

-- Function to check for space and case in column1 and column2
CREATE FUNCTION check_space_and_case() RETURNS TRIGGER AS $$
DECLARE
    column1_value text;
    column2_value text;
BEGIN
    -- Assign the values of column1 and column2 from the new row being inserted or updated
    column1_value := NEW.column1;
    column2_value := NEW.column2;
    -- Check if column1 or column2 contains a space
    IF column1_value ~ '\s' OR column2_value ~ '\s' THEN
        -- Raise an exception if a space is found in column1 or column2
        RAISE EXCEPTION 'Space is not allowed in column1 or column2';
    END IF;
    -- Check if column1 or column2 is not in lowercase
    IF column1_value <> lower(column1_value) OR column2_value <> lower(column2_value) THEN
        -- Raise an exception if column1 or column2 is not in lowercase
        RAISE EXCEPTION 'Column1 or column2 must be in lowercase';
    END IF; 
    -- If the checks pass, return the new row
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
-- Trigger to enforce the space and case check before inserting or updating rows in the "Patients" table
CREATE TRIGGER space_case_check_trigger
BEFORE INSERT OR UPDATE ON public."Patients"
FOR EACH ROW
EXECUTE FUNCTION check_space_and_case();


/*32) Write a query to calculate the running moving averages of diabetes_duration for Group 2
using the moving windows/sliding dynamic average windows.*/

SELECT
  "Patient_ID",
  "Firstname",
  "Lastname",
  "Diabetes_Duration",
  ROUND(AVG("Diabetes_Duration") OVER (
    PARTITION BY "Group_ID" ORDER BY "Patient_ID" ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
  ), 4) AS moving_average
FROM "Patients"
WHERE "Group_ID" = 'GRP_02';

/*33) Write a query to create a table to get patients demographic details whose birth year is 1939.
Name the table as Patient_Detail*/

CREATE TABLE public."Patient_Detail" AS
SELECT a."Patient_ID", a."Firstname", a."Lastname", g."Gender", c."Race", a."Age", a."Height", a."BMI",
(extract(year from a."Visit_Date")) - a."Age" as Birth_year
FROM public."Patients" a
JOIN public."Gender" g ON a."Gender_ID"=g."Gender_ID"
JOIN public."Race" c ON a."Race_ID"=c."Race_ID"
WHERE ((extract(year from a."Visit_Date")) - a."Age")='1939';

SELECT * FROM public."Patient_Detail"
	
--34) Convert and display Timestamp and date into visit time from Patient table on visit dates

SELECT
    "Patient_ID",
    "Firstname",
    "Lastname",
    TO_CHAR("Visit_Date", 'HH:MI:SS AM') AS "Visit_Time",
    TO_CHAR("Visit_Date", 'YYYY-MM-DD') AS "Visit_Date"
FROM
    "Patients";

--35) Write a query to find the number of patients visited each month. (Display with month Name)

SELECT TO_CHAR("Visit_Date", 'Month') AS "Month_Name",COUNT(*) AS "Number_of_Patients"
FROM "Patients"
GROUP BY TO_CHAR("Visit_Date", 'Month')
ORDER BY MIN("Visit_Date");
	
/*36) Write a query to get a number of visual/motor dementia patients who have any 2 abnormal conditions.
(Display with condition name). (dementia/cognitive impairment: any patient who has any two abnormal 
test results).*/

SELECT COUNT(*) AS "Patient_Count",
       CONCAT_WS(', ',
           CASE WHEN VC."RCFT_IR" <= 71 THEN 'RCFT' END,
           CASE WHEN VC."TM" >= 42 THEN 'TM' END,
           CASE WHEN VC."Clock" <= 2 THEN 'Clock' END,
           CASE WHEN MC."GDS" >= 15 THEN 'GDS' END
       ) AS "Abnormal_Conditions"
FROM public."Visual/Motor_Cog" VC
JOIN public."Link_Reference" LR ON LR."VM_ID" = VC."VM_ID"
JOIN public."Memory_Cognitive" MC ON LR."MC_ID" = MC."MC_ID"
WHERE (
    CASE WHEN VC."RCFT_IR" <= 71 THEN 1 ELSE 0 END +
    CASE WHEN VC."TM" >= 42 THEN 1 ELSE 0 END +
    CASE WHEN VC."Clock" <= 2 THEN 1 ELSE 0 END +
    CASE WHEN MC."GDS" >= 15 THEN 1 ELSE 0 END
) >= 2
GROUP BY "Abnormal_Conditions";
	
--37) Write a query to get a list of patient IDs whose fasting glucose is 80, 85, and 89.

SELECT "Patient_ID"
FROM public."Lab_Test"
WHERE "Fasting_Glucose" IN (80, 85, 89);

--38) calculate the difference between Day and night HR. (Display 2 decimal only)

SELECT "Patient_ID",
   ROUND(("24Hr_Day_HR" - "24Hr_Night_HR")::numeric, 2) AS "HR_Difference"
FROM "Blood_Pressure";

/*39) Find out the tables where column Patient_ID is present.(Display column position number 
with respective table also)*/

SELECT TABLE_NAME,ordinal_position
FROM information_schema.columns
WHERE COLUMN_NAME = 'Patient_ID';

--40) Write a query to calculate Creatinine ALbumin Ratio (uCAR) For DM Patients

SELECT P."Patient_ID",P."Firstname",P."Lastname",G."Group",(UT."Creatinine" / UT."Albumin") AS "Creat:Alb"
FROM public."Patients" P
JOIN "Link_Reference" LR ON P."Link_Reference_ID" = LR."Link_Reference_ID"
JOIN "Urine_Test" UT ON LR."Urine_ID" = UT."Urine_ID"
JOIN "Group" G ON P."Group_ID" = G."Group_ID"
JOIN public."Patients" DM ON P."Patient_ID" = DM."Patient_ID"
WHERE DM."Group_ID" IN (
    SELECT "Group_ID"
    FROM "Group"
    WHERE "Group" = 'DM');
	
--41 write a query to get the number of patients whose urine creatinine is in a normal range (Gender wise).

SELECT G."Gender", COUNT(P."Patient_ID") AS "Number of Patients"
FROM public."Patients" P
JOIN public."Gender" G ON G."Gender_ID" = P."Gender_ID"
JOIN public."Link_Reference" LR ON LR."Link_Reference_ID" = P."Link_Reference_ID"
JOIN public."Urine_Test" U ON U."Urine_ID" = LR."Urine_ID"
WHERE
  (G."Gender" = 'Male' AND U."Creatinine" BETWEEN 65.4 AND 119.3) OR
  (G."Gender" = 'Female' AND U."Creatinine" BETWEEN 52.2 AND 91.9)
GROUP BY G."Gender";


--42.Write a query to update id LB002 with the lab name Cultivate Lab

select * from "Lab_Visit"
where "Lab_visit_ID"='LB002'
update "lab_visit"
set "Lab_visit_ID"='LB002'
where "Lab_names"='Cultivate Lab';

select "Lab_names" from "Lab_Visit"
where "Lab_names"='Cultivate Lab'; 

--43.Create an index on any table and use explain analyze to show differences if any.

select "Patient_ID","Firstname","Lastname","Age" from "Patients"
create index "index_firstname" on "Patients"
(
"Firstname"
);

Explain select * from public."Patients"
where "Firstname"= 'Gabriel';

drop index "index_firstname";

--44.Write a query to split the lab visit date into two different columns lab_visit_date  and lab_visit_time.

select CAST ("Lab_Visit_Date" AS DATE) as lab_visit_date, 
       CAST ("Lab_Visit_Date" AS TIME) as lab_visit_time from "Lab_Visit";

--45 Please go through the below screenshot and create the exact output. 

SELECT SUBSTRING("Patient_ID" FROM 2)::INTEGER AS "pat_id",
       CASE WHEN SUBSTRING("Patient_ID" FROM 2)::INTEGER % 2 = 0 THEN 'true' ELSE 'false' END AS "even",
       CASE WHEN SUBSTRING("Patient_ID" FROM 2)::INTEGER % 2 = 0 THEN 'false' ELSE 'true' END AS "odd"
FROM "Patients";

--46 Calculate the Number of Diabetic Male and Female patients who are Anemic

SELECT G."Gender", COUNT(DISTINCT CASE
    WHEN (G."Gender" = 'Male' AND LT."Hgb" < 13.2)
        OR (G."Gender" = 'Female' AND LT."Hgb" < 11.6)
        THEN P."Patient_ID"
    END) AS anemic_count
FROM public."Patients" P
JOIN public."Gender" G ON G."Gender_ID" = P."Gender_ID"
JOIN public."Lab_Test" LT ON LT."Patient_ID" = P."Patient_ID"
WHERE P."Patient_ID" IN (
    SELECT "Patient_ID"
    FROM public."Patients"
    WHERE "Diabetes_Duration" > 0)
GROUP BY G."Gender";

--47. Write a query to display the Patient_ID, last name, and the position of the substring 'an' in the last name column for those patients who have a substring 'an'.

SELECT "Patient_ID", "Lastname",
POSITION ('an' IN "Lastname") AS "Position of 'an' in Last Name" FROM "Patients"
WHERE "Lastname" LIKE '%an%';
	
--48. List of patients from rows 30-40 without using the where condition.

select "Firstname","Lastname" from "Patients" 
limit 10 offset 37;

--49. Write a query to find Average age for patients with high blood pressure
select avg("Age") from "Blood_Pressure"
		 join "Patients" as p on p."Patient_ID"="Blood_Pressure"."Patient_ID"
		 where "Blood_Pressure"."24Hr_Day_SBP" > 129 and "Blood_Pressure"."24Hr_Night_SBP" >129
		 and "Blood_Pressure"."24Hr_Day_DBP" >79 and "Blood_Pressure"."24Hr_Night_DBP" >79;

--50.Create materialized view with no data, to display no of male and female patients.

CREATE MATERIALIZED VIEW Number_Of_Gender 
AS
select G."Gender",count(G."Gender") "No_Of_Gender" from
"Patients" P 
inner join "Gender" G on G."Gender_ID"=P."Gender_ID" 
group by  G."Gender"
WITH NO DATA;

/*51.Get a list of unique lab names whose names is starting with G and end with b.*/

SELECT DISTINCT("Lab_names") FROM public."Lab_Visit"
WHERE "Lab_names" LIKE 'G%b';

/*52.Write the query to create an Index on table Verbal_Cognitive by selecting 
 a column and also write the query drop the same index. */

CREATE INDEX idx_verbal_cognitive_vc_id ON public."Verbal_Cognitive"("VC_ID");

DROP INDEX idx_verbal_cognitive_vc_id;

/*53.Get the number of patients born in a leap year.*/

SELECT COUNT(*)As "Patients born in Leap Year" FROM public."Patients"
WHERE MOD(((Extract(year from "Visit_Date"))-"Age"),4)=0;

/*54.Write a query to get a list of patient IDs from the DM group and above age 60 in sequence. */

SELECT p."Patient_ID",p."Age" FROM public."Patients" p
JOIN public."Group" g ON p."Group_ID"=g."Group_ID"
WHERE g."Group"='DM' AND p."Age">60
ORDER BY p."Age";

/*55.Find the patient who has the most damage in the eyes with the use of a max function.*/

WITH max_damage AS
(SELECT "Opthal_ID", MAX("Diabetic_Retinopathy") AS most_damage FROM public."Opthalmology"
  GROUP BY "Opthal_ID"
)
SELECT CONCAT(p."Firstname",' ', p."Lastname") As "Patient", o."Opthal_ID", o.most_damage FROM max_damage o
JOIN "Patients" p ON p."Opthal_ID" = o."Opthal_ID"
WHERE o.most_damage = (SELECT MAX(most_damage) FROM max_damage)
ORDER BY o.most_damage DESC;

/* 56.	Create a procedure for checking if Race exists using an if else statement. */

CREATE OR REPLACE PROCEDURE chk_if_race_exists(IN race_name VARCHAR)
LANGUAGE plpgsql 
AS $$
BEGIN
--Check if the race exists in ‘Race’ Table
 IF EXISTS(SELECT 1 FROM public."Race" WHERE "Race"=race_name)
  --Raise a notice message indicating race exists
 THEN RAISE NOTICE 'Race % Exists',race_name;
 ELSE
 --Raise a notice message indicating race does not exist
 RAISE NOTICE 'Race % Does Not Exist',race_name;
 END IF;
END;
$$;

-- Check procedure with existing race
CALL chk_if_race_exists('White');
-- Check procedure with non existing race
CALL chk_if_race_exists('Asian');


/*57.Write a query to display the DM patients and their high fasting triglycerides based upon their age ,gender and race.*/ 

SELECT p."Patient_ID",p."Firstname",p."Lastname",p."Age",gn."Gender",r."Race",gr."Group",llt."Fasting_Triglyc"
FROM public."Patients" p
JOIN public."Gender" gn ON p."Gender_ID"=gn."Gender_ID"
JOIN public."Race" r ON p."Race_ID"=r."Race_ID"
JOIN public."Lipid_Lab_Test"llt  ON p."Patient_ID"=llt."Patient_ID"
JOIN public."Group" gr ON gr."Group_ID"=p."Group_ID"
WHERE gr."Group"='DM' AND llt."Fasting_Triglyc">150;

/*58.Create a pie chart based on race vs age.*/

SELECT R."Race", COUNT(*) AS Age_Count
FROM public."Patients" P
JOIN public."Race" R ON R."Race_ID" = P."Race_ID"
GROUP BY R."Race"
ORDER BY R."Race";


/* 59)Write a query to create a master Patient table and its child table. 
Make sure that the child table inherits all the fields from the parent Patient table.*/

CREATE TABLE "Patient" (
  "patient_id" INT PRIMARY KEY,
  "Firstname" VARCHAR(50),
  "last_name" VARCHAR(50),
  "Visit_Date" DATE,
  "Gender_ID" VARCHAR(10));
  
--  DROP TABLE "Patient";
  
CREATE TABLE "ChildPatient" (
) INHERITS ("Patient");

--DROP TABLE "ChildPatient";

/* 60.Write a query using the trigger after insert on the lab test table
      if the patient has abnormal HbA1C and fasting glucose values.*/
	  
CREATE OR REPLACE FUNCTION fn_chk_abn_values() RETURNS TRIGGER AS $$
BEGIN
-- Check if the inserted row has abnormal HbA1C and fasting glucose values
IF NEW."Hb_A1C">5.7 AND NEW."Fasting_Glucose">100 THEN
-- Raise a notice message indicating abnormal values
RAISE NOTICE 'Abnormal HbA1C and fasting glucose values detected for patient %', NEW."Patient_ID";
END IF;
 -- Return the new row to complete the trigger
RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER chk_abn_values_trigger
-- For each insert operation, trigger function to check abnormal values
AFTER INSERT ON public."Lab_Test"
FOR EACH ROW EXECUTE FUNCTION fn_chk_abn_values();
--Try to insert abnormal values in Lab test table to check trigger
INSERT INTO public."Lab_Test"("Lab_ID","Hb_A1C","Fasting_Glucose") VALUES ('LB079',6.0,120);

--61.write a query to get the number of patients for each age bin without using the CASE statement.(Bin size - 5)SELECT FLOOR("Age"/5)*5 AS AgeBIN ,COUNT(*) AS PATIENTCOUNT

SELECT 
CONCAT((WIDTH_BUCKET(p."Age", 0, 100, 20) - 1) * 5, ' - ', WIDTH_BUCKET(p."Age", 0, 100, 20) * 5 - 1) AS age_range,
COUNT (*) AS PATIENT_COUNT 
FROM PUBLIC."Patients" P
GROUP BY WIDTH_BUCKET(p."Age", 0, 100, 20)
ORDER BY age_range ASC;


--62 Write a query to get the number of patients who have normal platelets for each group.
-- /*normal platelet count in adults ranges from 150,000 to 450,000 platelets per microliter of blood. 

select GP."Group_ID", count(P."Patient_ID") "patients_Count"
from "Patients" P
inner join "Gender" G on G."Gender_ID"=P."Gender_ID"
inner join "Lab_Test" LT on LT."Patient_ID"=P."Patient_ID"
inner join "Link_Reference" LR on LT."Lab_ID"=LR."Lab_ID"
inner join "Group" GP on GP."Group_ID"=P."Group_ID"
where   LT."Platelets" between 150 and 450
group by GP."Group_ID"

--63. Create a trigger on a view of the Blood Pressure table.

-- Create a view on Blood_Pressure table
CREATE OR REPLACE VIEW vw_blood_pressure
AS
(SELECT "BP_ID","Patient_ID","24Hr_Day_HR","24Hr_Night_HR" 
 FROM public."Blood_Pressure");
 
--create a function to check abnormal heart rate
CREATE OR REPLACE FUNCTION check_hr_input() RETURNS TRIGGER AS $$
BEGIN
    -- Check if HR columns are inserted abnormal values
    IF NEW."24Hr_Day_HR">120 OR NEW."24Hr_Night_HR" >100 THEN
        RAISE NOTICE 'Abnormal Heart Rate';
    END IF;
    -- Return the result of the trigger function
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create a trigger on view 
CREATE TRIGGER check_hr_input_trigger
INSTEAD OF INSERT ON "vw_blood_pressure"
FOR EACH ROW
EXECUTE FUNCTION check_hr_input();

-- Try inserting a record in View with abnormal HR value
INSERT INTO vw_blood_pressure("BP_ID","Patient_ID","24Hr_Day_HR","24Hr_Night_HR")
VALUES('BP079','S0612',125,105);


--64 Write a query to find the number of Patients whose Gait RPE start is greater than the end and vice versa
SELECT 'RPE_END>START' AS type,COUNT ("Patient_ID") FROM public."Walking_Test"
WHERE ("Gait_RPE_Start " < "Gait_RPE_End " )
UNION
SELECT 'RPE_START>END'AS type,COUNT ("Patient_ID") FROM public."Walking_Test"
WHERE ("Gait_RPE_Start " > "Gait_RPE_End " ); 

--65)Create a view without using any schema or table and check the created view using a select statement.

CREATE TABLE Customer
CREATE TABLE Customers
(customer_id   int NOT NULL,
customer_name  char(50) NOT NULL,
address    	char(80),
place     	char(25));

INSERT INTO Customers(customer_id,customer_name,address,place )
VALUES(1,'NICK','ADDRESS2','USA');

CREATE VIEW CustomerViews AS
SELECT customer_id, customer_name, address, place
FROM Customers;

--66)Display patients names who have the same last name.
select "Firstname","Lastname"
from "Patients" P
where exists (select "Firstname","Lastname"
              from "Patients" P2
              where P2."Lastname" = P."Lastname"
                and P2."Patient_ID" <> P."Patient_ID")
				order by "Lastname";

--67)Write a query to get the Sum of Diabetes Duration for Group id 'GRP_02'.
SELECT SUM("Diabetes_Duration") FROM public."Patients"
WHERE "Group_ID"= 'GRP_02';

--68Write a query to get a patient name who has a chance to have kidney disease with Albumin.
SELECT CONCAT (A."Firstname" || ' ' || A."Lastname") AS "Patients_Albumin"
FROM "Patients" A
INNER JOIN "Link_Reference" B ON A."Link_Reference_ID" = B."Link_Reference_ID"
INNER JOIN "Urine_Test"C ON B."Urine_ID" = C."Urine_ID"
WHERE "Albumin" >= '30';

--69 Get the patient's name who has a max speed.
SELECT  PT."Firstname",PT."Lastname","Gait_DT_Speed" FROM public."Walking_Test" W
JOIN public."Patients" PT
ON PT."WalkTest_ID" = W."WalkTest_ID"
ORDER BY  "Gait_DT_Speed" DESC LIMIT 1;

--70.Write a query to find out the percentage of Lab visits by Lab names.

SELECT "Lab_names", (count(*)/ SUM(count(*)) OVER ()) * 100 AS percentage
FROM public."Lab_Visit"
GROUP  by "Lab_names";

/*71) Write a query to get Patient IDs for verbally cognitively impaired who satisfy any 2 conditions.
(HINT: dementia/cognitive impaired: any patient who has any two abnormal test results)*/ 

SELECT VC."Patient_ID"
FROM public."Verbal_Cognitive" VC
JOIN public."Link_Reference" LR ON VC."VC_ID" = LR."VC_ID"
JOIN public."Memory_Cognitive" MC ON LR."MC_ID" = MC."MC_ID"
WHERE (
    (CASE WHEN VC."DS" <= 13 THEN 1 ELSE 0 END) +
    (CASE WHEN VC."HVLT" <= 14 THEN 1 ELSE 0 END) +
    (CASE WHEN VC."VF" <= 42 THEN 1 ELSE 0 END) +
    (CASE WHEN VC."WTAR" <= 20 THEN 1 ELSE 0 END) +
    (CASE WHEN MC."GDS" >= 15 THEN 1 ELSE 0 END)
) >= 2;

/* 72) Display a list of patients who are memory cognitively impaired with the GDS test and whose 
diabetes duration is between 5 to 30.*/

SELECT P."Patient_ID",P."Firstname",P."Lastname"
FROM public."Patients" P
JOIN public."Link_Reference" LR ON LR."Link_Reference_ID" = P."Link_Reference_ID"
JOIN public."Memory_Cognitive" MC ON MC."MC_ID" = LR."MC_ID"
WHERE P."Diabetes_Duration" BETWEEN 5 AND 30
AND MC."GDS" >= 15;

--73) Write a query to the get number of Patient_IDs who visited between March 2005 and March 2006

SELECT COUNT(DISTINCT "Patient_ID") AS num_visits
FROM public."Patients"
WHERE "Visit_Date" >= '2005-03-01' AND "Visit_Date" < '2006-04-01';

--74) Get the number of patients who visited each lab using the windows function.

SELECT LV."Lab_names",
  SUM(COUNT(DISTINCT P."Patient_ID")) OVER (PARTITION BY LV."Lab_names") AS Patient_Count
FROM public."Lab_Visit" LV
JOIN public."Link_Reference" LR ON LV."Lab_visit_ID" = LR."Lab_visit_ID"
JOIN public."Patients" P ON LR."Link_Reference_ID" = P."Link_Reference_ID"
GROUP BY LV."Lab_names";

--75) Find the number of control and DM patients who visited each lab. 

SELECT G."Group",LV."Lab_names",COUNT(DISTINCT P."Patient_ID") AS Patient_Count
FROM public."Group" G
JOIN public."Patients" P ON G."Group_ID" = P."Group_ID"
JOIN public."Link_Reference" LR ON P."Link_Reference_ID" = LR."Link_Reference_ID"
JOIN public."Lab_Visit" LV ON LR."Lab_visit_ID" = LV."Lab_visit_ID"
GROUP BY LV."Lab_names",G."Group_ID";

--76) Please go through the below screenshot and create the exact output.

SELECT CONCAT("Firstname", ' ',"Lastname") AS Fullname,
LENGTH(CONCAT("Firstname", ' ',"Lastname"))+1 as unkown
FROM public."Patients";

/*77) Write a query to get comma-separated values of patient details .
(Use a maximum of 6 columns from different tables)*/

SELECT CONCAT(
		P."Patient_ID", ',',
		G."Group", ',',
		R."Race", ',',
		GD."Gender", ',',
		O."Diabetic_Retinopathy", ',',
        LT."Fasting_Glucose"
    ) AS PatientID_Group_Race_Gender_Diabetic_Retinopathy_Fasting_Glucose
FROM public."Patients" P
    JOIN public."Group" G ON P."Group_ID" = G."Group_ID"
    JOIN public."Race" R ON P."Race_ID" = R."Race_ID"
    JOIN public."Gender" GD ON P."Gender_ID" = GD."Gender_ID"
    JOIN public."Link_Reference" LR ON P."Link_Reference_ID" = LR."Link_Reference_ID"
    JOIN public."Opthalmology" O ON O."Opthal_ID" = P."Opthal_ID"
    JOIN public."Lab_Test" LT ON LT."Lab_ID" = LR."Lab_ID";
	
/* 78) Write a query to determine get the Patient IDs ,in DM and Control groups ,
that are in prediabetic stage and label them accordingly.*/

SELECT P."Patient_ID",G."Group",'Prediabetic' AS Label
FROM public."Patients" P
JOIN public."Group" G ON G."Group_ID" = P."Group_ID"
JOIN public."Link_Reference" LR ON LR."Link_Reference_ID" = P."Link_Reference_ID"
JOIN public."Lab_Test" LT ON LT."Lab_ID" = LR."Lab_ID"
WHERE
  (G."Group" = 'DM' OR G."Group" = 'Control') -- Filter for DM and Control groups
  AND LT."Fasting_Glucose" BETWEEN 100 AND 125; -- Filter for prediabetic stage
  
--79) Calculate the Patient's Daytime MAP and Nighttime MAP.

SELECT P."Patient_ID",
CAST((BP."24Hr_Day_DBP" + ((BP."24Hr_Day_SBP" - BP."24Hr_Day_DBP") / 3.0)) AS numeric(10, 2)) AS daytime_map,
CAST((BP."24Hr_Night_DBP" + ((BP."24Hr_Night_SBP" - BP."24Hr_Night_DBP") / 3.0)) AS numeric(10, 2)) AS nighttime_map
FROM public."Patients" P
JOIN public."Blood_Pressure" BP ON BP."BP_ID" = P."BP_ID";

--80) Write a query using recursive view.


WITH RECURSIVE GP_01 AS (
SELECT "Patient_ID", "Group_ID", "Firstname"
FROM public."Patients" 
WHERE "Group_ID" = 'GRP_01'
UNION
SELECT p."Patient_ID", p."Gender_ID", p."Firstname"
FROM  public."Patients" p
INNER JOIN GP_01 s ON s."Patient_ID" = p."Group_ID")
SELECT "Patient_ID","Firstname","Group_ID"
FROM GP_01;





