IF OBJECT_ID(N'tempdb..#depressionTest') IS NOT NULL
    DROP TABLE #depressionTest
select 
    id,
    cesd_total as "Depression Score (Scale 0-60)",
    case when cesd_2 = '3' and cesd_4 = '3' and cesd_6 = '3' and cesd_8 = '3' and cesd_10 = '3' then 1 else 0 end as "Anhedonia/dysphoria Flag",
    -- appetite 
    case when cesd_1 = '3' and cesd_18 = '3' then 1 else 0 end as "DSM 1",
    -- sleep
    case when cesd_5 = '3' and cesd_11 = '3' and cesd_19 = '3' then 1 else 0 end as "DSM 2",
    -- thinking/concentration 
    case when cesd_3 = '3' and cesd_20 = '3' then 1 else 0 end as "DSM 3",
    -- guilt 
    case when cesd_9 = '3' and cesd_17 = '3' then 1 else 0 end as "DSM 4",
    -- tired 
    case when cesd_7 = '3' and cesd_16 = '3' then 1 else 0 end as "DSM 5",
    -- movement
    case when cesd_12 = '3' and cesd_13 = '3' then 1 else 0 end as "DSM 6",
    -- suicidal ideation
    case when cesd_14 = '3' and cesd_15 = '3' then 1 else 0 end as "DSM 7"
into #depressionTest
from [master].[dbo].[Sleep_Answers]

--------- MENTAL HEALTH SCORES ---------
IF OBJECT_ID(N'tempdb..#MentalHealthScores') IS NOT NULL
    DROP TABLE #MentalHealthScores

-- Get mental health scores for participants
select 
    cast(a.id as int) as "Participant ID",

    -- Depression --
    cesd_total as "Depression Score (Scale 0-60)",
    case 
        when cesd_total < 16 then 'No clinical significance'
        when dt.[Anhedonia/dysphoria Flag] = 1 and (dt.[DSM 1] + dt.[DSM 2] + dt.[DSM 3] + dt.[DSM 4] + dt.[DSM 5]) = 2 then 'Possible major depressive episode'
        when dt.[Anhedonia/dysphoria Flag] = 1 and (dt.[DSM 1] + dt.[DSM 2] + dt.[DSM 3] + dt.[DSM 4] + dt.[DSM 5]) = 3 then 'Probable major depressive episode'
        when dt.[Anhedonia/dysphoria Flag] = 1 and (dt.[DSM 1] + dt.[DSM 2] + dt.[DSM 3] + dt.[DSM 4] + dt.[DSM 5]) = 4 then 'Meets criteria for Major depressive episode'
        else 'Subthreshhold depression symptoms'
    end as "Current Depressive Symptoms",

    -- Anxiety --
    gad_total as "GAD-7 Anxiety Score (Scale 1-7)",
    case 
        when gad_total > 15 then 'Severe'
        when gad_total > 9 then 'Moderate'
        when gad_total > 4 then 'Mild'
        else 'Minimal'
    end as "GAD-7 Level of Anxiety",

    -- UPPS-P Measure of Impulsivity --
    a.upps_total as "Impulsivity Score",
    cast((a.upps_total / 80.0)*100.0 as float) as "Impulsivity Percentile",

    -- Suicide Severity --
    case when cssrs_3mo_8 = 'Yes' then 1 else 0 end as "Suicide attempt in past 3 mos",
    case when cssrs_3mo_1 = '1' or cssrs_3mo_2 = '1' then 1 else 0 end as "Suicidal ideation severity in last 3 months",
    
    case when cssrs_lf_8 = 'Yes' then 1 else 0 end as "Suicide attempt in lifetime",
    cast(cssrs_lf_1 as int) + cast(cssrs_lf_2 as int) + cast(cssrs_lf_3 as int) + cast(cssrs_lf_4 as int) + cast(cssrs_lf_5 as int) as "Suicidal ideation severity in lifetime (Scale 1-5)",

    -- Mental Health Diagnosis Details --
    mh_anx as "Anxiety Disorder?",
    mh_bpd as "Bipolar Disorder?",
    case when mh_meds_1 = 1 then 'Yes' else 'No' end as "Take Medication(s)?",
    mh_ptsd as "PTSD?",
    mh_pzd as "Psychotic Disorder?",
    mh_szd as "Seizure Disorder"
into #MentalHealthScores
from [master].[dbo].[Sleep_Answers] a
left join #depressionTest dt on dt.id = a.id
order by a.id asc

--------- SUICIDE RISK ---------
--- Calculate risk of suicide (yes/no) based on numeric suicide variables
IF OBJECT_ID(N'tempdb..#SuicideRisk') IS NOT NULL
    DROP TABLE #SuicideRisk
Select 
    [Participant ID],
    case 
        when [Suicide attempt in lifetime] = 1 then 1
        when [Suicide attempt in past 3 mos] = 1 then 1
        when [Suicidal ideation severity in lifetime (Scale 1-5)] > 3 then 1
        when [Suicidal ideation severity in last 3 months] > 3 then 1
        else 0
    end as "Risk of Suicide"
into #SuicideRisk
from #MentalHealthScores
order by [Participant ID] asc
 

--------- SLEEP STUDY ---------
-- Pull input variables for data science project.
 IF OBJECT_ID(N'tempdb..#SleepStudy') IS NOT NULL
    DROP TABLE #SleepStudy

 select 
    -- Participant Demographic Info --
    cast(a.id as int) as "Participant ID",
    cast(a.age as int) as "Age",
    a.sex as "Sex",
    case when a.race = 'tive' then 'Native American' else a.race end as "Race",

    -- Sleep Scores --
    brisc_total as "Sleep Control Score", -- Brief Index of Sleep Control (BRISC)
    ddnsi_total as "Nightmare Severity Score", -- Disturbing Dreams and Nightmares Severity Index
    psqi_total as "Global Sleep Quality Score", -- Pittsburgh Sleep Quality Index, range: 0-21
    psqi_c1 as "Subjective Sleep Quality Score", -- range: 0-3
    psqi_c2 as "Sleep Latency", -- range: 0-9
    psqi_c3 as "Sleep Duration", -- range: 0-3
    psqi_c4 as "Sleep Efficiency", -- range: 0-3
    psqi_c5 as "Sleep Disturbance", -- range: 0-3
    psqi_c6 as "Use of Sleep Meds", -- range: 0-3
    psqi_c7 as "Daytime Dysfunction", -- range: 0-9

    -- Sleep Disorder Symptoms --
    sds_9 as "Excessive Daytime Sleepiness", -- range: 0-4
    sds_6 as "Fatigue", -- range: 0-4
    sds_23 as "REM Sleep Behavior Disorder", -- range: 0-4
    sds_24 as "Sleep-related TMJ",
    brisc_3 as "Average Sleep Duration",
    wd_nwak as "# of Mid-night Awakenings",

    -- Consumption --
    subs_can_3 as "How often do you use cannabis/marijuana to help you sleep?",
    subs_tob_3 as "How often do you use tobacco to help you sleep?",
    subs_alc_3 as "How often do you use alcohol to help you sleep?"
into #SleepStudy
from [master].[dbo].[Sleep_Answers] a

--------- FEATURE IMPUTATION ---------
-- Get average age of population to later use to fill in NULL values for age.
IF OBJECT_ID(N'tempdb..#AvgAge') IS NOT NULL
    DROP TABLE #AvgAge

select
    AVG(Age) as "Average Age" -- AVERAGE AGE = 20
into #AvgAge
from #SleepStudy
WHERE  
    Age is not NULL

--------- FINAL DATASET ---------
IF OBJECT_ID(N'tempdb..#pop') IS NOT NULL
    DROP TABLE #pop

select 
    ROW_NUMBER() over(order by (select 1)) as "Participant ID", 
    --case when ss.Age is null then 20 else cast(ss.Age as int) end as "Age",
    Sex,
    --Race,
    [Sleep Control Score],
    [Nightmare Severity Score],
    [Global Sleep Quality Score],
    [Subjective Sleep Quality Score],
    [Sleep Latency],
    --[Sleep Efficiency],
    [Daytime Dysfunction],
    --[Use of Sleep Meds],
    Fatigue,
    --[Sleep-related TMJ],
    [Average Sleep Duration],
    --[# of Mid-night Awakenings],
    [How often do you use cannabis/marijuana to help you sleep?] as "Cannabis Use",
    [How often do you use tobacco to help you sleep?] as "Tobacco Use",
    --[How often do you use alcohol to help you sleep?] as "Alcohol Use",
    sr.[Risk of Suicide] 
into #pop
from #SleepStudy ss
left join #SuicideRisk sr on sr.[Participant ID] = ss.[Participant ID]

--------- Partition final dataset for ML Model ---------
-- Training set = 75% of population = 728 --> Participant IDs 1 through 728
-- Test set = 20% of population = 194 --> Participant IDs 729 through 922
-- Validation set = 5% of population = 49 --> Participant IDs 923 through 971

IF OBJECT_ID(N'tempdb..#trainingData') IS NOT NULL
    DROP TABLE #trainingData

select 
    [Participant ID], 
    Sex,
    [Sleep Control Score],
    [Nightmare Severity Score],
    [Global Sleep Quality Score],
    [Subjective Sleep Quality Score],
    [Sleep Latency],
    [Daytime Dysfunction],
    Fatigue,
    [Average Sleep Duration],
    [Cannabis Use],
    [Tobacco Use]
into #trainingData
from #pop ss
where 
    [Participant ID] between 1 and 728
order by 
    [Participant ID] asc

IF OBJECT_ID(N'tempdb..#testData') IS NOT NULL
    DROP TABLE #testData

select 
    *
into #testData
from #pop 
where 
    [Participant ID] between 729 and 922
order by 
    [Participant ID] asc

IF OBJECT_ID(N'tempdb..#validationSet') IS NOT NULL
    DROP TABLE #validationSet

select 
    *
into #validationSet
from #pop 
where 
    [Participant ID] between 923 and 971
order by 
    [Participant ID] asc



