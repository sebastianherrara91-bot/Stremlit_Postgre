SELECT 
    GETDATE() as ServerDate,
    DATEPART(week, GETDATE()) as ServerWeek,
    DATEADD(day, -1, DATEADD(week, DATEDIFF(week, -1, GETDATE()), -1)) as CalculatedEndDate_Current,
    DATEADD(week, -52, DATEADD(day, -1, DATEADD(week, DATEDIFF(week, -1, GETDATE()), -1))) as CalculatedEndDate_PrevYear
