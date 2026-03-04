SELECT 
    current_date as ServerDate,
    extract(week from current_date) as ServerWeek,
    (date_trunc('week', current_date) - interval '2 days')::date as CalculatedEndDate_Current,
    (date_trunc('week', current_date) - interval '52 weeks' - interval '2 days')::date as CalculatedEndDate_PrevYear
